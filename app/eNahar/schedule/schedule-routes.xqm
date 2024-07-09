xquery version "3.0";

(:~ 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-sched = "http://enahar.org/exist/restxq/enahar/schedules";

import module namespace functx =  "http://www.functx.com" at "../modules/functx.xqm";

import module namespace config = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";

import module namespace cal2event = "http://enahar.org/exist/apps/enahar/cal2event"     at "../schedule/cal2event.xqm";
import module namespace icalv     = "http://enahar.org/exist/apps/enahar/ical-validate" at "../schedule/cal-validate.xqm";

import module namespace r-cal = "http://enahar.org/exist/restxq/enahar/icals"    at "../cal/cal-routes.xqm";
import module namespace r-hd  = "http://enahar.org/exist/restxq/enahar/holidays" at "../holidays/holiday-routes.xqm";

import module namespace r-leave = "http://enahar.org/exist/restxq/metis/leaves"  at "../../metis/FHIR/Leave/leave-routes.xqm";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $r-sched:data-perms := "rwxrwxr-x";
declare variable $r-sched:perms      := "rwxr-xr-x";
declare variable $r-sched:data-group := "spz";
declare variable $r-sched:schedule-base := "/db/apps/eNaharData/data/schedules";
declare variable $r-sched:history       := "/db/apps/eNaharHistory/data/Schedules";

declare %private function r-sched:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/>
        </http:response>
    </rest:response>
};

declare %private function r-sched:prepareResult(
          $hits as element(schedule)*
        , $start as xs:int
        , $length as xs:string
        ) as item()
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:int($length)
    let $len1  := if ($count > $len0)
        then $len0
        else $count
    return
        <schedules>
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </schedules>
};

(:~
 : moveToHistory
 : Move to history
 : 
 : @param $objects
 : @return ()
 :)
declare %private function r-sched:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-sched:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-sched:history, $nameHistory)
                    )
        )
};


(:~
 : GET: enahar/schedules/{uuid}
 : get cals by id
 : 
 : @param $id  uuid
 :)
declare
    %rest:GET
    %rest:path("enahar/schedules/{$uuid}")
    %rest:query-param("realm", "{$realm}",  "") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-sched:schedulesByID(
          $uuid as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()*
{
    let $scheds := collection($r-sched:schedule-base)/schedule[id[@value=$uuid]]
    return
        if (count($scheds)=1) 
        then $scheds
        else  r-sched:rest-response(404, 'schedules: uuid not valid.')
};

(:~
 : GET: enahar/schedules
 : get global schedules
 : 
 : @param $type
 : @param $name
 : 
 : @return bundle of <cal/>
 :)
declare
    %rest:GET
    %rest:path("enahar/schedules")
    %rest:query-param("realm", "{$realm}",  "") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("type",  "{$type}",   "*")
    %rest:query-param("name",  "{$name}",   "*")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-sched:schedulesXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $type as xs:string*
        , $name as xs:string*
        ) as item()
{
    let $hits0 := if ($type='*')
        then collection($r-sched:schedule-base)/schedule[active[@value="true"]]
        else collection($r-sched:schedule-base)/schedule[type[@value=$type]][active[@value="true"]]
    let $valid := if ($name='*')
        then $hits0
        else $hits0/schedule[matches(name/@value,$name)]

    let $sorted-hits :=
        for $c in $valid
        order by lower-case($c/name/@value/string())
        return
            $c
    return
        r-sched:prepareResult($sorted-hits, 1, '*')
};

(:~
 : GET: enahar/schedules
 : get owner events
 : 
 : @param $owner   owner ref aka user id
 : @param $group   group
 : @param $sched   schedule
 : @param $active
 : 
 : @return json:array
 :)
declare
    %rest:GET
    %rest:path("enahar/schedules")
    %rest:query-param("realm", "{$realm}",  "") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("type",  "{$type}",   "service")
    %rest:query-param("name",  "{$name}")
    %rest:query-param("actor", "{$actor}")
    %rest:query-param("group",  "{$group}")
    %rest:query-param("active", "{$active}","true")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-sched:schedulesJSON(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $type as xs:string*
        , $name as xs:string*
        , $actor as xs:string*
        , $group as xs:string*
        , $active as xs:string*
        )
{
    let $hits0 := if ($type='*')
        then collection($r-sched:schedule-base)/schedule[active[@value="true"]]
        else collection($r-sched:schedule-base)/schedule[type[@value=$type]][active[@value="true"]]
    let $valid := if ($name)
        then $hits0/../schedule[matches(name/@value,$name)]
        else $hits0

    let $sorted-hits :=
        for $c in $valid
        order by lower-case($c/name/@value/string())
        return
            $c
    return
    <json:array xmlns:json="http://www.json.org">
    {
        for $service in $sorted-hits
        return
        <json:value xmlns:json="http://www.json.org" json:array="true">
            <id>{$service/id/@value/string()}</id>
            <text>{$service/name/@value/string()}</text>
        </json:value>
    }
    </json:array>
};

(:~
 : GET: enahar/schedules/events
 : get owner events
 : 
 : @param $owner   actor ref aka user id
 : @param $group   group
 : @param $sched   schedule
 : @param $rangeStart timeMin
 : @param $rangeEnd   timeMax
 : 
 : @return bundle
 :)
declare
    %rest:GET
    %rest:path("enahar/schedules/events")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}") 
    %rest:query-param("actor",  "{$actor}", "")
    %rest:query-param("group",  "{$group}",  "")
    %rest:query-param("sched",  "{$sched}",  "")
    %rest:query-param("rangeStart", "{$rangeStart}",  "1970-01-01T00:00:00")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}",    "1970-01-01T23:59:59")
    %rest:query-param("fillSpecial", "{$fillSpecial}", "")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-sched:scheduledEventsXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $actor as xs:string*
        , $group as xs:string*
        , $sched
        , $rangeStart as xs:string*
        , $rangeEnd as xs:string*
        , $fillSpecial as xs:string*
        ) as item()
{
    let $s := adjust-dateTime-to-timezone(xs:dateTime($rangeStart),())
    let $e := adjust-dateTime-to-timezone(xs:dateTime($rangeEnd),())
    (: get all user cals with selected schedules :)
    let $services:= r-cal:servicesXML($realm, $loguid, $lognam, '1', '*', $actor, $group, $sched, $fillSpecial)
 
    let $lll := util:log-app('TRACE', 'apps.eNahar', $services)

    let $hds       := r-hd:holidaysXML($rangeStart,$rangeEnd)
    let $leaves    := r-leave:leavesXML(
                  $realm, $loguid,$lognam
                , '1', '*'
                , $actor, ''
                , $rangeStart, $rangeEnd
                , ('confirmed','tentative'), '*')
(: 
    let $lll := util:log-app('TRACE', 'apps.eNahar', $leaves)
:)
    (: get all relevant schedules :)
    let $refdss    := distinct-values($services/cal/schedule/global/reference/@value)
    let $schedules := collection($r-sched:schedule-base)/schedule[identifier/value[@value=$refdss]][active[@value="true"]]
 
    let $lll := util:log-app('TRACE', 'apps.eNahar', $schedules/name)

    return
    <schedules>
        {  cal2event:cal2xml($services, $s, $e, $hds, $leaves, $schedules,$fillSpecial='true') }
    </schedules>
};

(:~
 : GET: enahar/schedules/events
 : get owner events
 : 
 : @param $owner   owner ref aka user id
 : @param $group   group
 : @param $sched   schedule
 : @param $start   start
 : @param $end  end
 : 
 : @return json:array
 :)
declare
    %rest:GET
    %rest:path("enahar/schedules/events")
    %rest:query-param("realm", "{$realm}","") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("actor", "{$actor}", "")
    %rest:query-param("group",  "{$group}",  "")
    %rest:query-param("sched",  "{$sched}",  "")
    %rest:query-param("rangeStart",  "{$rangeStart}",  "1970-01-01T00:00:00")      
    %rest:query-param("rangeEnd",    "{$rangeEnd}",    "1970-01-01T23:59:59")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-sched:scheduledEventsJSON(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $actor as xs:string*
        , $group as xs:string*
        , $sched
        , $rangeStart as xs:string*, $rangeEnd as xs:string*
        ) as item()
{
    let $s := if (contains($rangeStart,'T'))
        then xs:dateTime($rangeStart)
        else dateTime(xs:date($rangeStart), xs:time('00:00:00'))
    let $e := if (contains($rangeEnd,'T'))
        then xs:dateTime($rangeEnd)
        else dateTime(xs:date($rangeEnd), xs:time('23:59:59'))
    let $services:= r-cal:servicesXML($realm, $loguid, $lognam, '1', '*', $actor, $group, $sched, 'false')
(: 
    let $lll := util:log-app('DEBUG', 'eNahar', $services)
:)
    let $hds    := r-hd:holidaysXML($rangeStart,$rangeEnd)
    let $leaves := r-leave:leavesXML(
                      $realm, $loguid, $lognam
                    ,'1', '*'
                    , $actor, ''
                    , $rangeStart, $rangeEnd
                    , ('confirmed','tentative')
                    , '*') 
    let $refdss    := distinct-values($services/cal/schedule/global/reference/@value)
    let $schedules := collection($r-sched:schedule-base)/schedule[identifier/value/@value=$refdss][active[@value="true"]]
    return
    <json:array xmlns:json="http://www.json.org">
    {
        for $service in $services/cal
        let $las := 
            <leaves>
                { $leaves/leave[actor/reference/@value=$service/owner/reference/@value] }
            </leaves>
        return
            cal2event:cal2fc-events($service, $s, $e, $hds, $las, $schedules)
    }
    </json:array>
};
 
(:~
 : PUT: enahar/schedules
 : Update an existing calendar or store a new one.
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("enahar/schedules")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}") 
    %rest:produces("application/xml", "text/xml")
function r-sched:putScheduleXML(
          $content as document-node()*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $isNew   := not($content/schedule/@xml:id)
    let $cid   := if ($isNew)
        then switch($content/schedule/type/@value) 
             case 'meeting' return "me-" || $content/schedule/name/@value/string()
             default return 'sched-' || $content/schedule/name/@value/string()
        else 
            let $id := $content/schedule/id/@value/string()
            let $scheds := collection($r-sched:schedule-base)/schedule[id[@value = $id]]
            let $move := r-sched:moveToHistory($scheds)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/schedule/meta/versionId/@value/string()) + 1
    let $elems := $content/schedule/*[not(
                   self::meta
                or self::id
                or self::identifier
                )]
    let $uuid := if ($isNew)
        then switch($content/schedule/type/@value) 
             case 'meeeting' return "me-" || util:uuid()
             default return 'sched-' || util:uuid()
        else $cid
    let $meta := $content/schedule/meta/*[not(
                   self::versionID
                or self::lastUpdated
                or self::extension
                )]
    let $data :=
        <schedule xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                <versionId value="{$version}"/>
                <extension url="#lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>    
                <lastUpdated value="{current-dateTime()}"/>
            </meta>
            <identifier>
                <use value="official"/>
                <system value="#enahar-id"/>
                <value value="{concat('enahar/schedules/',$cid)}"/>
            </identifier>
            {$elems}
        </schedule>
        
(:
    let $lll := util:log-app('TRACE','apps.nabu',$data)
:)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-sched:schedule-base, $file, $data)
            , sm:chmod(xs:anyURI($r-sched:schedule-base || '/' || $file), $r-sched:data-perms)
            , sm:chgrp(xs:anyURI($r-sched:schedule-base || '/' || $file), $r-sched:data-group)))
        return
            r-sched:rest-response(200, 'schedule sucessfully stored.') 
    } catch * {
        r-sched:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

(:~
 : Validate an existing schedule.
 : The cal XML is read from the request body.
 : 
 :)
declare
    %rest:GET
    %rest:path("enahar/schedules/{$uuid}/validate")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("mode",   "{$mode}", "full") 
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-sched:validateScheduleXML(
          $uuid as xs:string*
        , $realm as xs:string* 
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $mode as xs:string*
        ) as item()+
{
    let $sched := collection($r-sched:schedule-base)/schedule[id[@value=$uuid]]
    return
        if (count($sched)=1)
        then
            let $log := util:log-app("DEBUG", 'apps.eNahar', $sched)
            let $result := icalv:validateSchedule($sched)
            return
            (
                r-sched:rest-response(200, 'schedule valid.')
            ,
                $result
            )
        else  
            (
                r-sched:rest-response(404, 'schedule: uuid not valid.')
            ,
                <result>
                    <result value="error"/>
                    <info value="{concat('schedules: ',$uuid, ': found', count($sched), ' schedules')}"/> 
                </result>
            )
};
