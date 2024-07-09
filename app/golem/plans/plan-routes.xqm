xquery version "3.0";
module namespace re = "http://enahar.org/exist/apps/restxq/golem";

(: 
import module namespace mem="http://enahar.org/lib/mem";

import module namespace r-user    = "http://enahar.org/exist/restxq/metis/users"        at "/db/apps/metis/FHIR/user/user-routes.xqm";
import module namespace r-careplan= "http://enahar.org/exist/restxq/nabu/careplans"     at "/db/apps/nabu/FHIR/CarePlan/careplan-routes.xqm";
:)
import module namespace cpt       = "http://enahar.org/exist/apps/nabu/careplan-template" at "/db/apps/nabu/FHIR/CarePlan/careplan-template.xqm";
import module namespace r-cp      = "http://enahar.org/exist/restxq/nabu/careplans"     at "/db/apps/nabu/FHIR/CarePlan/careplan-routes.xqm";
import module namespace r-order   = "http://enahar.org/exist/restxq/nabu/orders"        at "/db/apps/nabu/FHIR/Order/order-routes.xqm";

import module namespace rec       = "http://enahar.org/exist/apps/golem/context"        at "/db/apps/golem/context/context.xqm";
import module namespace rea       = "http://enahar.org/exist/apps/golem/actions"        at "/db/apps/golem/plans/actions.xqm";
import module namespace rer       = "http://enahar.org/exist/apps/golem/requests"       at "/db/apps/golem/plans/requests.xqm";


declare namespace   rest = "http://exquery.org/ns/restxq";
declare namespace   http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";


declare namespace golem = "http://enahar.org/ns/1.0/golem";
declare namespace  fhir = "http://hl7.org/fhir";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";


declare variable $re:pdcoll := collection('/db/apps/nabuWorkflow/data/PlanDefinitions');

declare function local:addNamespaceToXML($noNamespaceXML as element(*),$namespaceURI as xs:string) as element(*)
{
    element {fn:QName($namespaceURI,fn:local-name($noNamespaceXML))}
    {
         $noNamespaceXML/@*
        ,for $node in $noNamespaceXML/node()
            return
                if (exists($node/node()))
                then local:addNamespaceToXML($node,$namespaceURI)
                else if ($node instance of element()) 
                then element {fn:QName($namespaceURI,fn:local-name($node))}{$node/@*}
                else $node
    }
};
declare %private function re:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : GET: nabu/evaluate
 : execute plan with id within context.
 : requests are parametrized but not stored into db
 : 
 : @param @plan    PlanDefinitionId
 : @param $context PatientId
 : @return  </results>
 :)
declare
    %rest:GET
    %rest:path("golem/evaluate")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("plan",   "{$pid}")
    %rest:query-param("context","{$cid}")
    %rest:query-param("priority", "{$priority}", "")
    %rest:query-param("description","{$description}", "")
    %rest:produces("application/xml")
function re:evaluatePlan(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $pid as xs:string*
        , $cid as xs:string*
        , $priority as xs:string*
        , $description as xs:string*
        ) as item()
{
    let $lll   := util:log-app('TRACE','apps.nabu',concat($pid,' - ', $cid))
    let $pd := $re:pdcoll/fhir:PlanDefinition[fhir:id[@value=$pid]]
    let $pcntxt := rec:getPatientContext($realm,$loguid,$lognam,$cid)
    let $patid := $pcntxt/fhir:Patient/fhir:id/@value/string()
    let $other := rec:getAdditionalPatientContext($realm,$loguid,$lognam,$patid,$pd/fhir:id/@value)

    let $uc := rec:evalWithPatient(
                  $pd
                , $pcntxt
                , $other
                , <source xmlns="http://hl7.org/fhir">
                    <reference value="{concat('metis/practitioners/',$loguid)}"/>
                    <display value="{$lognam}"/>
                  </source>
                , ()
                )
    let $actions  := if ($uc/golem:ok)
        then rea:actions($pd/fhir:action)
        else ()
    let $requests := if ($actions)
        then rer:requests($actions, $uc, $priority, $description)
        else ()
    return
        <result xmlns="http://enahar.org/ns/1.0/golem">
            {$uc}
            {$actions}
            {$requests}
        </result>
};

(:~
 : PUT: nabu/evaluate
 : execute plan with id.
 : request are parametrized and stored into db 
 : 
 : @param $content  CarePlan
 : @param $context  PatientId
 : @return  <CarePlan/>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("golem/evaluate")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("context","{$cid}")
    %rest:query-param("priority", "{$priority}", "")
    %rest:query-param("description","{$description}", "")
    %rest:produces("application/xml")
function re:evaluatePlanFromCarePlan(
          $content as document-node()*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $cid as xs:string*
        , $priority as xs:string*
        , $description as xs:string*
        ) as item()*
{
    (:~
     :  steps:
     : 1. get context aka CarePlan, default is Patient 
     : 2. check useContexts
     : 3. evaluate actions recursively
     : 4. generate result, default request
     :)
    let $content := if ($content/fhir:CarePlan)
        then $content
        else document { local:addNamespaceToXML($content/*:CarePlan,"http://hl7.org/fhir") }
    let $pdid := substring-after($content/fhir:CarePlan/fhir:definition/fhir:reference/@value,'nabu/plandefinitions/')
    let $pd := $re:pdcoll/fhir:PlanDefinition[fhir:id[@value=$pdid]]
    let $pcntxt := rec:getPatientContext($realm,$loguid,$lognam,$cid)
    let $pid := $pcntxt/fhir:Patient/fhir:id/@value/string()
    let $other := rec:getAdditionalPatientContext($realm,$loguid,$lognam,$pid,$pd/fhir:id/@value)

    let $uc := rec:evalWithPatient(
                  $pd
                , $pcntxt
                , $other
                , <source xmlns="http://hl7.org/fhir">
                    <reference value="{concat('metis/practitioners/',$loguid)}"/>
                    <display value="{$lognam}"/>
                  </source>
                , <basedOn xmlns="http://hl7.org/fhir">
                    <reference value="{concat('nabu/careplans/',$content/fhir:CarePlan/fhir:id/@value)}"/>
                    <display value="{$content/fhir:CarePlan/fhir:title/@value}"/>
                  </basedOn>
                )
    let $actions  := if ($uc/golem:ok)
        then rea:actions($pd/fhir:action)
        else ()
    let $requests := if ($actions/golem:request/golem:error)
        then ()
        else rer:requests($actions, $uc, $priority, $description)
    let $props := if ($uc/golem:ok and $requests)
          then  (
                  if ($description="")
                  then $uc/fhir:params/fhir:title
                  else <title  xmlns="http://hl7.org/fhir" value="{$description}"/>
                , $uc/fhir:params/fhir:description
                , <status xmlns="http://hl7.org/fhir" value="active"/>
                )
          else  if ($uc/golem:ok)
                then 
                (
                  <title  xmlns="http://hl7.org/fhir" value="{$actions/golem:error/@value/string()}"/>
                )
                else
                (
                  <title  xmlns="http://hl7.org/fhir" value="{$uc/golem:error/fhir:title/@value/string()}"/>
                , <description xmlns="http://hl7.org/fhir" value="{$uc/golem:error/fhir:description/@value/string()}"/>
                )
    let $activities := for $o in $requests
        (: store requests :)
        let $store := r-order:putOrderXML(
                  document {$o}
                , $realm
                , $loguid
                , $lognam
                )[2]
        (: link requests into careplan :)
        return
            <activity xmlns="http://hl7.org/fhir">
                <reference>
                    <reference value="{concat('nabu/orders/',$store/fhir:id/@value)}"/>
                    <display value="{$store/fhir:description/@value/string()}"/>
                </reference>
                <progress>
                    <authorReference>
                        <reference value="metis/practitioners/u-golem"/>
                        <display value="Golem"/>
                    </authorReference>
                    <time value="{adjust-dateTime-to-timezone(current-dateTime())}"/>
                    <text value="angelegt"/>           
                </progress>
            </activity>
    return
        if ($activities)
        then
            let $newcp := cpt:fillCarePlan($content/fhir:CarePlan,$props,$activities)
            let $store := r-cp:putCarePlanXML(
                          document {$newcp}
                        , $realm
                        , $loguid
                        , $lognam)
            let $lll   := util:log-app('TRACE','apps.nabu',$newcp)
            return
                (
                  re:rest-response(200, 'golem acted on careplan with plandefinition.')
                , $newcp
                )
        else
            re:rest-response(404, 'golem acted but error occured.')
};
