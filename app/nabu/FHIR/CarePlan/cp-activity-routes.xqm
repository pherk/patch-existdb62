xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-cpa = "http://enahar.org/exist/restxq/nabu/cp-activities";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";

import module namespace r-order = "http://enahar.org/exist/restxq/nabu/orders" at "../../FHIR/Order/order-routes.xqm";
import module namespace r-task  = "http://enahar.org/exist/restxq/nabu/tasks" at "../../FHIR/Task/task-routes.xqm";

declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-cpa:nabu-careplans := "/db/apps/nabuCom/data/CarePlans";
declare variable $r-cpa:coll          := collection($r-cpa:nabu-careplans);
declare variable $r-cpa:history       := concat($config:history-data,'/CarePlans');
declare variable $r-cpa:data-perms    := "rwxrw-r--";
declare variable $r-cpa:data-group    := "spz";
declare variable $r-cpa:valid-cp-status  := ('draft','active','suspended','completed','cancelled','entered-in-error','unknown');
declare variable $r-cpa:valid-detail-status  := ('not-started','scheduled','in-progress','completed','cancelled','on-hold','unknown');


declare %private function r-cpa:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};


(:~
 : GET: nabu/careplans/{cid}/actions
 : List careplans for subject
 : 
 : @param   $author        ref
 : @param   $rangeStart    dateTime
 : @param   $rangeEnd      dateTime
 : @param   $subject       ref
 : @param   $status        ('in-progress', 'enroll', 'ready', 'printed', 'cancelled')
 : @param   $format        ('full', 'wrapper', 'payload', 'count')
 : 
 : @return  bundle <careplans/>
 : 
 : @since v0.8
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/careplans/{$cid}/actions")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam",   "{$lognam}",  "")      
    %rest:query-param("author",  "{$author}", "")
    %rest:query-param("status",  "{$status}", "active")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-cpa:actionsXML(
            $cid   as xs:string*
        ,   $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $author as xs:string*
        ,   $status as xs:string*
        ,   $format as xs:string*
        ) as item()
{
    try{
    let $cps := $r-cpa:coll/fhir:CarePlan[fhir:id[@value = $cid]]
    let $actions := for $a in $cps/fhir:activity
        return
            if ($a/fhir:reference)
            then
                let $aref := $a/fhir:reference
                let $areftoks := tokenize($aref/fhir:reference/@value,'/')
                return
                    switch ($areftoks[2])
                    case 'orders' return
                            r-order:orderByID($areftoks[3],$realm,$loguid,$lognam)
                    case 'tasks' return
                            r-task:taskByID($areftoks[3],$realm,$loguid,$lognam)
                    default return ()
            else $a/fhir:detail
    return
        switch ($format)
        case 'count' return <actions><count>{count($cps/fhir:activity/fhir:reference)}</count></actions> 
        default return 
            (: actions must be ordered by activity sequence! :)
            <actions xmlns="">
                {$actions} 
            </actions>
    } catch * {
        r-cpa:rest-response(404, concat('CarePlan: Invalid activities? : ', $cid))
    }
};

declare %private function r-cpa:split-reference(
      $ref as xs:string
    ) as xs:string
{
    let $pq := tokenize($ref,'\?')
    let $path := tokenize($pq[1],'/')
    return
        ($path,$pq[1])
};
(:~
 : POST: nabu/careplans/{$cid}/actions/{$aid}?...
 : Update an existing careplan.
 :
 : 
 : @return <response>
 :)
declare
    %rest:POST
    %rest:path("nabu/careplans/{$cid}/actions/{$aid}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("progress", "{$progress}")
    %rest:query-param("outcome",  "{$outcome}")
    %rest:query-param("eid",      "{$eid}")
    %rest:query-param("edisp",    "{$edisp}")
    %rest:produces("application/xml", "text/xml")
function r-cpa:updateActionOutcome(
      $cid as xs:string*
    , $aid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $progress as xs:string*
    , $outcome as xs:string*
    , $eid as xs:string*
    , $edisp as xs:string*
    ) as item()
{
    let $cp := $r-cpa:coll/fhir:CarePlan[fhir:id[@value = $cid]]
    let $lll := util:log-app('TRACE','apps.nabu',concat('action ',$aid, ' status: ',$cp/fhir:activity[fhir:reference/fhir:reference[matches(@value,$aid)]]/fhir:outcomeCodeableStatus/fhir:text/@value, ' ++ ', ':', $outcome, ' : ', $progress))
    return
    try {
        if (count($cp)=1)
        then
            let $cparef :=  $cp/fhir:activity[fhir:reference/fhir:reference[matches(@value,$aid)]]
            let $upd1 := 
                if (string-length($progress)>0)
                then
                    let $now := adjust-dateTime-to-timezone(current-dateTime(),())
                    let $up := system:as-user('vdba', 'kikl823!',
                    (
                      update insert 
                            <progress xmlns="http://hl7.org/fhir">
                                <authorReference>
                                    <reference value="metis/practitioners/{$loguid}"/>
                                    <display value="{$lognam}"/>
                                </authorReference>
                                <time value="{$now}"/>
                                <text value="{$progress}"/>
                            </progress>
                        into
                            $cparef
                    ))
                    return "progress added"
                else 'progress not relevant'
            let $upd2 := 
                if (string-length($outcome)>0)
                then
                    system:as-user('vdba', 'kikl823!',
                    (
                        if ($cparef/fhir:outcomeCodeableConcept)
                        then
                            update value $cparef/fhir:outcomeCodeableConcept/fhir:text/@value 
                                with concat($outcome, ' ++ ', $cparef/fhir:outcomeCodeableConcept/fhir:text/@value)
                        else
                            update insert
                                        <outcomeCodeableConcept xmlns="http://hl7.org/fhir">
                                            <coding>
                                                <system value="http://snomed.info/sct"/> 
                                                <code value=""/> 
                                                <display value=""/>
                                            </coding>
                                            <text value="{$outcome}"/>
                                        </outcomeCodeableConcept>
                                    into $cparef
                    ))
                else ()
            let $upd3 :=
                if ($eid)
                then
                    let $cpaocref := $cp/fhir:activity[fhir:reference/fhir:reference[matches(@value,$aid)]]/fhir:outcomeReference[fhir:reference/@value='']
                    let $ocrdisp  := ($edisp,"")[1]
                    return
                        if ($cpaocref)
                        then
                            system:as-user('vdba', 'kikl823!',
                            (
                                update value $cpaocref/fhir:reference/@value with concat('nabu/encounters/', $eid)
                            ,   if ($cpaocref/fhir:display)
                                then
                                    update value $cp/fhir:activity[fhir:reference/fhir:reference[matches(@value,$aid)]]/fhir:outcomeReference/fhir:display/@value 
                                        with $ocrdisp
                                else
                                    update insert <display xmlns="http://hl7.org/fhir" value="{$ocrdisp}"/>
                                        following $cpaocref/fhir:reference
                            ))
                        else 
                            system:as-user('vdba', 'kikl823!',
                            (
                                if ($cpaocref)
                                then
                                    update insert 
                                        <outcomeReference xmlns="http://hl7.org/fhir">
                                            <reference value="{concat('nabu/encounters/', $eid)}"/>
                                            <display value="{$ocrdisp}"/>
                                        </outcomeReference>
                                        following $cpaocref
                                else
                                    update insert 
                                        <outcomeReference xmlns="http://hl7.org/fhir">
                                            <reference value="{concat('nabu/encounters/', $eid)}"/>
                                            <display value="{$ocrdisp}"/>
                                        </outcomeReference>
                                        into $cparef
                            ))
                else ()

           return  r-cpa:rest-response(200, string-join(('careplan', 'outcome updated'),' : '))
        else
                r-cpa:rest-response(404, 'careplan outcome not updated.') 
 
    } catch * {
        r-cpa:rest-response(401, 'permission denied. Ask the admin.') 
    }
};



(:~
 : GET: nabu/careplans/{$cid}/actions/{$aid}?status=
 : Update an existing careplan.
 :
 : 
 : @return <response>
 
declare
    %rest:POST
    %rest:path("nabu/careplans/{$cid}/actions/{$aid}/status")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("status", "{$status}","")
    %rest:query-param("outcome", "{$outcome}","")
    %rest:produces("application/xml", "text/xml")
function r-cpa:updateActionStatus(
      $cid as xs:string*
    , $aid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $status as xs:string*
    , $outcome as xs:string*
    ) as item()
{
    let $cp := $r-cpa:coll/fhir:CarePlan[fhir:id[@value = $cid]]
    let $lll := util:log-app('TRACE','apps.nabu',concat('action ',$aid, ' status: ',$cp/fhir:activity[fhir:reference/fhir:reference[matches(@value,$aid)]]/fhir:status/@value, '->', $status, ':', $outcome))
    return
    try {
        if (count($cp)=1)
        then if (r-cpa:isValidActionStatus($status))
            then    
                let $up := system:as-user('vdba', 'kikl823!',
                (
                  update value $cp/fhir:activity[fhir:reference/fhir:reference[matches(@value,$aid)]]/fhir:status/@value with $status
                , if ($outcome!='')
                    then update value $cp/fhir:activity[fhir:reference/fhir:reference[matches(@value,$aid)]]/fhir:outcomeCodeableStatus/fhir:text/@value 
                            with concat($cp/fhir:activity[fhir:reference/fhir:reference[matches(@value,$aid)]]/fhir:outcomeCodeableStatus/fhir:text/@value, ' - ', $outcome)
                    else ()
                ))
                return
                r-cpa:rest-response(200, 'careplan status updated.')
            else
                r-cpa:rest-response(200, 'careplan status not valid/relevant.')
        else
            r-cpa:rest-response(404, 'careplan status not updated.') 
    } catch * {
        r-cpa:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-cpa:isValidActionStatus($status as xs:string) as xs:boolean
{
    $status = $r-cpa:valid-status
};
:)

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
