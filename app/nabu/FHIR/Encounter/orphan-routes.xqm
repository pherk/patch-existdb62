xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-orphan = "http://enahar.org/exist/restxq/nabu/orphans";

import module namespace xqtime = "http://enahar.org/lib/xqtime";

import module namespace r-encounter = "http://enahar.org/exist/restxq/nabu/encounters" at "../../FHIR/Encounter/encounter-routes.xqm";
import module namespace r-leave   = "http://enahar.org/exist/restxq/metis/leaves"      at "/db/apps/metis/FHIR/Leave/leave-routes.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"
                 at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";


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

declare %private function r-orphan:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <orphans xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </orphans>
};



declare %private function r-orphan:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : GET: nabu/orphans/encounters?start=1&length=*&status=...
 : List encounters for participant $uid if on leave
 : 
 : @param   $uid     ids of participants
 : @param   $group   group
 : @param   $sched   schedule
 : @param   $timeMin start of period
 : @param   $timeMax end of period
 : @param   $start   start of sublist
 : @param   $length  len of sublist
 : @param   $status  FHIR status
 : @param   $sort   
 : @return  bundle <appointments/>
 :)
declare
    %rest:GET
    %rest:path("nabu/orphans/encounters")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",    "{$start}",   "1")      
    %rest:query-param("length",   "{$length}",  "*")
    %rest:query-param("uid",      "{$uid}", "")
    %rest:query-param("group",    "{$group}", "")  
    %rest:query-param("sched",    "{$sched}",  "")
    %rest:query-param("patient",  "{$patient}", "")
    %rest:query-param("rangeStart", "{$rangeStart}", "")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2021-04-01T23:59:59")
    %rest:query-param("status",   "{$status}",  "planned")
    %rest:query-param("_sort",   "{$sort}", "date:asc")
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-orphan:encountersXML(
      $realm as xs:string*, $loguid as xs:string*, $lognam as xs:string*
    , $start as xs:string*, $length as xs:string*
    , $uid as xs:string*, $group as xs:string*, $sched as xs:string*
    , $patient as xs:string*
    , $rangeStart as xs:string*, $rangeEnd as xs:string*
    , $status as xs:string*
    , $sort as xs:string*
    ) as item()*
{
    try {
    let $tmin := if ($rangeStart="")
        then adjust-dateTime-to-timezone(current-dateTime(),())
        else $rangeStart
    let $tmax := $rangeEnd
let $lll := util:log-app('TRACE','apps.nabu',$tmin)
let $lll := util:log-app('TRACE','apps.nabu',$tmax)
    let $apps := r-encounter:encountersXML(
                  $realm, $loguid, $lognam
                , "1", "*"
                , $uid, $group, $sched
                , ""
                , $tmin, $tmax
                , $status
                , $sort)
    let $uids := distinct-values($apps/fhir:Encounter/fhir:participant/fhir:individual/fhir:reference/@value)
    let $leaves := r-leave:leavesXML(
                  $realm, $loguid,$lognam
                , "1", "*"
                , $uid, $group
                , $tmin, $tmax
                , ('tentative','confirmed')
                , '')

    let $orphans := for $u in $uids
    
(: let $lll := util:log-app('TRACE','apps.nabu',$u) :)
        let $aas := $apps/fhir:Encounter[fhir:participant/fhir:individual[fhir:reference/@value=$u]]
        let $userExists := r-orphan:exists($u,$realm,$loguid,$lognam)
        return
            (: actor in team? :) 
            if ($userExists) 
            then r-orphan:filterOrphans($aas,$leaves/*:leave[*:actor/*:reference/@value=$u])
            else $aas
                
let $lll := util:log-app('TRACE','apps.nabu',count($orphans))

    return
        r-orphan:prepareResult($orphans, $start, $length)
    } catch * {
        r-orphan:rest-response(404, concat('orphans not found : ', $uid))
    }
};

declare %private function r-orphan:exists(
      $url as xs:string
    , $realm as xs:string
    , $loguid as xs:string
    , $lognam as xs:string*
    ) as xs:boolean
{
    let $uid := substring-after($url,'metis/practitioners/')
    let $prid := r-practrole:userByID($uid,'full')/fhir:id/@value/string()
    let $rs  := r-practrole:rolesByID($prid,$realm,$loguid,$lognam)
    return
        boolean($rs//fhir:role)
};

declare %private function r-orphan:filterOrphans($apps,$leaves)
{
let $lll := util:log-app('TRACE','apps.nabu',count($apps))
    let $ltps := for $lp in $leaves
        return
            if ($lp/*:allDay/@value = 'true')
            then
                let $start := substring($lp/*:period/*:start/@value,1,10) || 'T08:00:00'
                let $end   := substring($lp/*:period/*:end/@value,1,10) || 'T20:00:00'
                return
                    xqtime:new($start,$end,"l")
            else
                xqtime:new($lp/*:period/*:start/@value,$lp/*:period/*:end/@value,"l")
let $lll := util:log-app('TRACE','apps.nabu',count($ltps))
    for $a in $apps
    let $po := xqtime:new($a/fhir:period/fhir:start/@value, $a/fhir:period/fhir:end/@value, "po")
(: 
  let $lll := util:log-app('TRACE','apps.nabu',$po) 
:)
    order by $a/fhir:period/fhir:start/@value/string()
    return
        if ($ltps[xqtime:overlap(., $po )])
        then $a
        else ()
};
