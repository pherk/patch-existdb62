xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-po = "http://enahar.org/exist/restxq/nabu/patient-operations";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
import module namespace xqtime = "http://enahar.org/lib/xqtime";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
(:  FHIR Resources :)
(: 
import module namespace r-appointment   = "http://enahar.org/exist/restxq/nabu/appointments"   at "../../FHIR/Appointment/appointment-routes.xqm";
:)
import module namespace r-careplan      = "http://enahar.org/exist/restxq/nabu/careplans"      at "../../FHIR/CarePlan/careplan-routes.xqm";
import module namespace r-careteam      = "http://enahar.org/exist/restxq/nabu/careteams"      at "../../FHIR/CareTeam/careteam-routes.xqm";
import module namespace r-climpr        = "http://enahar.org/exist/restxq/nabu/clinimpressions"      at "../../FHIR/ClinicalImpression/clinimpression-routes.xqm";
import module namespace r-communication = "http://enahar.org/exist/restxq/nabu/communications" at "../../FHIR/Communication/communication-routes.xqm";
import module namespace r-composition   = "http://enahar.org/exist/restxq/nabu/compositions"   at "../../FHIR/Composition/composition-routes.xqm";
import module namespace r-condition     = "http://enahar.org/exist/restxq/nabu/conditions"     at "../../FHIR/Condition/condition-routes.xqm";
import module namespace r-encounter     = "http://enahar.org/exist/restxq/nabu/encounters"     at "../../FHIR/Encounter/encounter-routes.xqm";
import module namespace r-eoc           = "http://enahar.org/exist/restxq/nabu/eocs"           at "../../FHIR/EpisodeOfCare/episodeofcare-routes.xqm";
import module namespace r-goal          = "http://enahar.org/exist/restxq/nabu/goals"          at "../../FHIR/Goal/goal-routes.xqm";
(: import module namespace r-observation   = "http://enahar.org/exist/restxq/nabu/observations"    at "../../FHIR/Observation/observation-routes.xqm"; :)
import module namespace r-order         = "http://enahar.org/exist/restxq/nabu/orders"         at "../../FHIR/Order/order-routes.xqm";

import module namespace r-patient       = "http://enahar.org/exist/restxq/nabu/patients"       at "../../FHIR/Patient/patient-routes.xqm";
import module namespace r-protocol      = "http://enahar.org/exist/restxq/nabu/protocols"      at "../../FHIR/Protocol/protocol-routes.xqm";
import module namespace r-qr            = "http://enahar.org/exist/restxq/nabu/questionnaireresponses" at "../../FHIR/QuestionnaireResponse/questresponse-routes.xqm";
import module namespace r-task          = "http://enahar.org/exist/restxq/nabu/tasks"          at "../../FHIR/Task/task-routes.xqm";
(: 
import module namespace r-leave   = "http://enahar.org/exist/restxq/metis/leaves"   at "/db/apps/metis/FHIR/Leave/leave-routes.xqm";
import module namespace r-practrole    = "http://enahar.org/exist/restxq/metis/practrole"  
                         at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
:)
import module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize" at "../../FHIR/meta/serialize-fhir-resources.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-po:server  := "http://spz.uk-koeln.de";
declare variable $r-po:context := "apps/restxq";

(:~
 : 
 : HTTP RESPONSE CODES USED
 : 
 : 200 - Operation Success
 : 420 - Operation Failed
 : 400 - Bad Request Syntax
 : 410 - Resource Not Available
 : 405 - restXQ operation call error
 : 500 - Internal Server Error
 : 
 : Response header contains a 'mf-message' field where the value has meaning in context.
 : 
 :)




declare %private function r-po:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : GET: nabu/patients/{$uid}/resources
 : List resources for patient with $uid
 :  
 : @param   $uid        
 : @param   $realm
 : @param   $loguid
 : @param   $rangeStart start of period
 : @param   $rangeEnd   end of period
 : @return  bundle <resources/>
 :)
declare
    %rest:GET
    %rest:path("nabu/patients/{$uid}/everything")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("rangeStart", "{$rangeStart}", "")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2026-04-01T23:59:59")
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-po:everythingBundleXML(
      $uid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    ) as item()*
{
    try {
        let $resources := r-po:everything($uid,$realm,$loguid,$lognam,$rangeStart,$rangeEnd)
        let $total := count($resources)
                 
    let $lll := util:log-app('TRACE','apps.nabu',$total)

    return
        r-po:resources2Bundle($resources,$total,$uid,$realm,$loguid,$lognam,$rangeStart,$rangeEnd)
    } catch * {
        let $lll := util:log-app('ERROR','apps.nabu',concat($err:code,':',$err:description))
        return
        r-po:rest-response(404, concat('error: resources not retrieved: ', $uid))
    }
};


(:~
 : GET: nabu/patients/{$uid}/everymeta
 : List resources for patient with $uid
 :  
 : @param   $uid        
 : @param   $realm
 : @param   $loguid
 : @param   $rangeStart start of period
 : @param   $rangeEnd   end of period
 : @return  bundle <resources/>
 :)
declare
    %rest:GET
    %rest:path("nabu/patients/{$uid}/everymeta")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("rangeStart", "{$rangeStart}", "")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2026-04-01T23:59:59")
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-po:everythingMetaXML(
      $uid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    ) as item()*
{
    try {
        let $resources := r-po:everything($uid,$realm,$loguid,$lognam,$rangeStart,$rangeEnd)
        let $total := count($resources)
           
    let $lll := util:log-app('TRACE','apps.nabu',$total)

    return
        r-po:resources2Meta($resources)
    } catch * {
        let $lll := util:log-app('ERROR','apps.nabu',concat($err:code,':',$err:description))
        return
            r-po:rest-response(404, concat('error: resources not retrieved: ', $uid))
    }
};

declare %private function r-po:everything(
      $uid as xs:string
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    )
{
        let $pat   := r-patient:patientByIDXML(
                  $uid
                , $realm, $loguid, $lognam
                )
        let $cares := r-careplan:careplansXML(
                  $realm, $loguid, $lognam
                , ""
                , $uid
                , ("planned","active","finished")
                , "full")
        let $cts := r-careteam:careteamsXML(
                  $realm, $loguid, $lognam
                , $uid
                , ("active","inactive")
                , "full")
        let $clImp := ()
        let $comms  := r-communication:communicationsXML(
                  $realm, $loguid, $lognam
                , "1", "*"
                , ""
                , "", ""
                , $uid
                , ('in-progress','completed','printed')
                , "full")/fhir:Communication
        let $comps := r-composition:compositionsXML(
                  $realm, $loguid, $lognam
                , "1", "*"
                , "" 
                , "", ""
                , $uid
                , "final"    (: TODO more values :)
                , "full")
        let $conds := r-condition:conditionsXML(
                  $realm, $loguid, $lognam
                , "1", "*", "", ""
                , $uid
                , ""
                , "active"
                , ("finding","diagnosis")
                , ""
                , "full", "cat")
        let $encs := r-encounter:encountersBySubject(
                  $uid
                , $realm, $loguid, $lognam
                , "1", "*"
                , "", "", "finished")
        let $eocs := r-eoc:eocsXML(
                  $realm, $loguid, $lognam
                , "", ""
                , $uid
                , ""
                ,"full"
                )
        let $goals := r-goal:goalsXML(
                  $realm, $loguid, $lognam
                , '1', '*'
                , ''
                , $rangeStart, $rangeEnd
                , $uid
                , "", "","",""
                , "startDate"
                , "full"
                ) 
        let $obsrv := ()
        let $orders := r-order:orderBySubject(
                  $uid
                , $realm, $loguid
                , "")
        let $procs  := () (: r-procedures:proceduresXML() :)
        let $qrs := r-qr:questionnaireResponsesXML(
                  $realm, $loguid, $lognam
                , ''
                , $uid
                , 'completed'
                , 'full'
                )
        let $tasks  := r-task:tasksXML(
                  $realm, $loguid, $lognam
                , "1", "*"
                , ('task','team')
                , "", "", ""
                , "", ""
                , $uid
                , ""
                , ""
                )        
    let $resources := 
            (
                (: nabuData :)
              $pat
            , $encs/fhir:Encounter
            , $orders/fhir:Order
                (: nabuCom :)
            , $cares/fhir:Careplan
            , $cts/fhir:CareTeam
            , $clImp/fhir:ClinicalImpression
            , $comms/fhir:Communication
            , $comps/fhir:Composition
            , $conds/fhir:Condition
            , $eocs/fhir:EpisodeOfCare
            , $goals/fhir:Goal
            , $obsrv/fhir:Observation
            , $procs/fhir:Procedure
            , $qrs/fhir:QuestionnaireResponse
            , $tasks/fhir:Task
            )
    return
        $resources
};


declare %private function r-po:resources2Bundle(
      $resources as item()+
    , $total as xs:integer
    , $uid as xs:string
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    )
{
    let $uuid := concat('b-',util:uuid())
    return
    <Bundle xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
        <id value="{$uuid}"/>
        <meta>
            <versionId value="0"/>
        </meta>
        <type value="searchset"/>
        <total value="{$total}"/>
    {
        for $r in $resources
        let $url := r-po:fullUrl($r)
        return
            <entry xmlns="http://hl7.org/fhir">
                <fullUrl value="{$url}"/>
                <resource>{ $r }</resource>
            </entry>
    }
    </Bundle>
};

declare %private function r-po:fullUrl($resource as item()) as xs:string
{
    string-join(('http://spz.uk-koeln.de','exist/restxq','nabu',concat(lower-case(local-name($resource)),'s'),$resource/fhir:id/@value),'/')    
};


declare %private function r-po:resources2Meta($resources)
{
    <resources xmlns="">
    {
        for $r in $resources
        order by $r/fhir:lastModified/@value/string() descending
        return
            switch(local-name($r))
            case "Appointment"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("start: ",$r/fhir:start/@value)}</info>
                        </meta>
            case "CarePlan"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("desc: ", $r/fhir:description/@value)}</info>
                        </meta>
            case "CareTeam"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("start: ", $r/fhir:period/fhir:start/@value)}</info>
                        </meta>
            case "Communication"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("sent: ",$r/fhir:sent/@value)}</info>
                        </meta>
            case "Condition"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("code: ", $r/fhir:code/fhir:text/@value)}</info>
                        </meta>
            case "Encounter"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("start: ", $r/fhir:period/fhir:start/@value)}</info>
                        </meta>
            case "EpisodeOfCare"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("start: ", $r/fhir:period/fhir:start/@value)}</info>
                        </meta>
            case "Goal"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("startDate: ",$r/fhir:startDate/@value)}</info>
                        </meta>
            case "Observation"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("date: ",$r/fhir:effectiveDateTime/@value)}</info>
                        </meta>
            case "Procedure"return
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("performed: ",$r/fhir:performedDate/@value)}</info>
                        </meta>
            default return (: ClinicalImpression, Composition, Order, QuestionaireResponse :)
                        <meta type="{local-name($r)}" tdt="false">
                            {
                              $r/fhir:id
                            , $r/fhir:lastModified
                            }
                            <info>{concat("date: ",$r/fhir:date/@value)}</info>
                        </meta>
        }
        </resources>
};
(:~
 : PUT: nabu/patients/{$uid}/updateSubject
 : update subject in resources 
 :  
 : @param   $uid        
 : @param   $realm
 : @param   $loguid

 : @return  bundle ()
 :)
declare
    %rest:PUT("{$resources}")
    %rest:path("nabu/patients/{$uid}/updateSubject")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-po:compartmentUpdateSubjectXML(
      $resources
    , $uid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()*
{
(: 
    let $lll := util:log-app('TRACE,'apps.nabu',$resources)
:)
    let $pat  := r-patient:patientByIDXML($uid,$realm,$loguid,$lognam)
    let $pid  := $pat/fhir:id/@value/string()
    let $pnam := r-patient:formatFHIRName($pat)
(: 
    let $lll := util:log-app('TRACE,'apps.nabu',$pnam)
:)
    for $m in $resources//*:meta[@tdt='true']
    return
        switch ($m/@type)
    (:
        case 'Appointment' return r-appointment:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
    :)
        case 'CarePlan' return r-careplan:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
    (:
        case 'CareTeam' return r-careteam:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
    :)
        case 'ClinicalImpression' return r-climpr:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
        case 'Communication' return r-communication:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
        case 'Composition' return r-composition:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
        case 'Condition' return r-condition:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
        case 'Encounter' return r-encounter:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
    (:
        case 'EpisodeOfCare' return r-eoc:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
    :)
        case 'Goal' return r-goal:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
    (:  case 'Observation' return r-obsrv:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam) :)
        case 'Order' return r-order:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
        case 'Protocol' return r-protocol:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
        case 'QuestionaireResponse' return r-qr:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
        case 'Task' return r-task:updateSubject($m/fhir:id/@value, $realm, $loguid, $lognam, $pid, $pnam)
        default return ()
};