xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-cal = "http://enahar.org/exist/restxq/enahar/icals";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";
import module namespace date = "http://enahar.org/exist/apps/enahar/date"     at "../modules/date.xqm";
import module namespace icalv     = "http://enahar.org/exist/apps/enahar/ical-validate" at "../schedule/cal-validate.xqm";

import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole" at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare namespace fo     ="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  ="http://exist-db.org/xquery/xslfo";

declare variable $r-cal:data-perms := "rwxrwxr-x";
declare variable $r-cal:data-group := "spz";
declare variable $r-cal:perms      := "rwxr-xr-x";
declare variable $r-cal:cals       := collection($config:enahar-icals);
declare variable $r-cal:history    := "/db/apps/eNaharHistory/data/Cals";
declare variable $r-cal:schedule-base := "/db/apps/eNaharData/data/schedules";


declare %private function r-cal:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-cal:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <cals>
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </cals>
};

(:~ moveToHistory
 : Move to history
 : 
 : @param $objects
 : @return ()
 :)
declare %private function r-cal:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-cal:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-cal:history, $nameHistory)
                    )
        )
};

(:~
 : GET: enahar/icals/{uuid}
 : get cal by id
 : 
 : @param $id  uuid
 : 
 : @return <cal/>
 :)
declare
    %rest:GET
    %rest:path("enahar/icals/{$uuid}")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-cal:calByID($uuid as xs:string*) as item()*
{
    let $cals := $r-cal:cals/cal[id[@value=$uuid]]
    return
        if (count($cals)=1)
        then $cals
        else  r-cal:rest-response(404, 'icals: uuid not valid.')
};

(:~
 : GET: enahar/icals
 : get cals by owner
 : 
 : @param $owner   owner ref aka user id
 : @param $group   group
 : @param $sched   schedule
 : 
 : @return bundle of <cal/>
 :)
declare
    %rest:GET
    %rest:path("enahar/icals")
    %rest:query-param("realm", "{$realm}","") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("start",  "{$start}",   "1")      
    %rest:query-param("length", "{$length}",  "*")
    %rest:query-param("owner",  "{$owner}",   "")
    %rest:query-param("group",  "{$group}",   "")
    %rest:query-param("sched",  "{$schedule}","")
    %rest:produces("application/xml", "text/xml")
function r-cal:cals(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $owner as xs:string*
        , $group as xs:string*
        , $schedule as xs:string*
    ) as item()
{
    let $oref := concat('metis/practitioners/', $owner)
    let $sref := concat('enahar/schedules/', $schedule)
    let $hits0 := if ($owner != '')
        then $r-cal:cals/cal[owner/reference[@value=$oref]][active[@value="true"]]
        else r-cal:calsByGroup($group)
    let $valid := if ($schedule='')
        then $hits0
        else $hits0/schedule[global/reference[@value=$sref]]/../.. (: tricky: match any cal with a certain schedulue :)

    let $sorted-hits :=
        for $c in $valid
        order by lower-case($c/owner/display/@value/string())
        return
            $c
    return
        r-cal:prepareResult($sorted-hits, $start, $length)
};

(:~
 : calsByGroup
 : cals for owners which belong to $group
 : 
 : @param $group
 : 
 : @return item(cal)*
 :)
declare function r-cal:calsByGroup($role as xs:string)
{
    let $bundle := r-practrole:practRoles("1","*",'', '', '', $role,'','','true')
    let $prrefs := $bundle/fhir:entry/fhir:resource/fhir:PractitionerRole/fhir:practitioner/fhir:reference/@value/string()
    return
        $r-cal:cals/cal[owner/reference[@value=$prrefs]][active/@value="true"]
};

(:~
 : GET: enahar/subscribers
 : get subscribers
 : 
 : @param $sched   schedule
 : 
 : @return bundle of <subscribers/>
 :)
declare
    %rest:GET
    %rest:path("enahar/subscribers")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("schedule",  "{$schedule}","")
    %rest:query-param("active", "{$active}", "true")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-cal:subscribersXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $schedule as xs:string*
        , $active as xs:string*
        ) as item()
{ 
    let $today := current-dateTime() 
    let $sref := concat('enahar/schedules/', $schedule)
     let $valid := if ($schedule='')
        then $r-cal:cals/cal[active/@value='true']
        else $r-cal:cals/cal[active/@value='true']/schedule[global/reference[@value=$sref]]/.. (: tricky: match any cal with a certain schedule :)

    let $sorted-hits :=
        for $qcal in $valid
        order by lower-case($qcal/owner/display/@value/string())
        return
            <cal>
            { $qcal/*[not(self::schedule)] }
            {   (: filter schedule :)
                if ($schedule='')
                then $qcal/schedule[global/reference/@value ne 'enahar/schedules/worktime'][global/reference/@value ne 'enahar/schedules/reserve'][r-cal:isActiveAt(./agenda,$today)]
                else $qcal/schedule[global/reference/@value=$sref][r-cal:isActiveAt(./agenda,$today)]
            }
            </cal>
    let $start := 1
    let $length := '*'
    let $count := count($sorted-hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <subscribers>
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </subscribers>
};

declare %private function r-cal:isActiveAt(
          $agendas as element(agenda)*
        , $date as xs:dateTime
        ) as xs:boolean
{
    if ($agendas)
    then
        count($agendas[./start/@value='' or start/@value<=$date][./end/@value='' or ./end/@value>=$date]) > 0
    else
        true()
};
        
(:~
 : PATCH: enahar/{$owner}/schedules
 : add schedule, no duplicates
 : delete schedule
 : 
 : @param $sid   schedule id
 : @param $name  name of schedule
 : 
 : @return <cal/>
 :)
declare
    %rest:POST
    %rest:path("enahar/icals/{$owner}/schedules")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("sid",    "{$sid}","")
    %rest:query-param("name",   "{$sdisp}","")
    %rest:query-param("type",   "{$stype}","")
    %rest:query-param("action", "{$action}","add")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-cal:updateScheduleXML(
          $owner  as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $sid as xs:string*
        , $sdisp as xs:string*
        , $stype as xs:string*
        , $action as xs:string*
        ) as item()
{
    let $log := util:log-app("TRACE", 'apps.eNahar', $owner)
    let $today := current-dateTime()
    let $oref := concat('metis/practitioners/',$owner)
    let $sref := concat('enahar/schedules/', $sid)
    let $cals := $r-cal:cals/cal[owner/reference/@value=$oref]
    return
        if (count($cals)=1)
        then 
            (: 
                meeting or service can have active or inactive agenda
            :)
            let $schedule := $cals/schedule[global/reference/@value=$sref]
            let $log := util:log-app("TRACE", 'apps.eNahar', $schedule)
            let $agenda := $schedule/agenda[r-cal:isActiveAt(.,$today)]
            let $log := util:log-app("TRACE", 'apps.eNahar', $action)
            let $doit := switch($action)
                case 'add' return
                    if ($schedule) (: already there :)
                    then if ($agenda) (: open new agenda if needed :)
                        then ()
                        else ()
                    else
                        let $insert := 
                                if ($cals/schedule[global/type/@value=$stype][last()])
                                then $cals/schedule[global/type/@value=$stype][last()]
                                else $cals/lastModified
                        let $log := util:log-app("TRACE", 'apps.eNahar', $insert)
                        return
                        system:as-user('vdba', 'kikl823!', (
                              update insert 
                                    <schedule>
                                        <global>
                                            <reference value="{$sref}"/>
                                            <display value="{$sdisp}"/>
                                            <type value="{$stype}"/>
                                        </global>
                                        <note value=""/>
                                        {
                                            if ($stype='meeting')
                                            then () (: agenda not needed :)
                                            else
                                                <agenda>
                                                    <period>
                                                    <start value="{adjust-dateTime-to-timezone(current-dateTime(),())}"/>
                                                    <end value=""/>
                                                    </period>
                                                    <note value=""/>
                                                </agenda>
                                        }
                                    </schedule>
                                    following $insert
                            ))
                case 'delete' return
                    if ($schedule/global/type/@value='meeting')
                    then
                        system:as-user('vdba', 'kikl823!', (
                              update delete $schedule
                            ))
                    else () (: agenda will be closed :)
                default return ()
            return
                r-cal:rest-response(200, 'icals: schedule updated.')
        else if (count($cals>1))
        then
            let $log := util:log-app("TRACE", 'apps.eNahar', $owner)
            return
                r-cal:rest-response(404, 'icals: only one cal is allowed.')
        else
            r-cal:rest-response(404, 'icals: uuid not valid.')
};

(:~
 : GET: enahar/services
 : get services
 : 
 : @param $owner   owner display value
 : @param $group   group
 : @param $sched   schedule
 : 
 : @return bundle of <services/>
 :)
declare
    %rest:GET
    %rest:path("enahar/services")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("start",  "{$start}",   "1")      
    %rest:query-param("length", "{$length}",  "*")
    %rest:query-param("owner",  "{$owner}",   "")
    %rest:query-param("group",  "{$group}",   "")
    %rest:query-param("sched",  "{$schedule}","")
    %rest:query-param("fillSpecial",  "{$fillSpecial}","false")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-cal:servicesXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length   as xs:string*
        , $owner as xs:string*
        , $group as xs:string*
        , $schedule as xs:string*
        , $fillSpecial as xs:string*
        ) as item()
{
    let $lll := util:log-app('DEBUG', 'apps.eNahar', $owner)
    let $lll := util:log-app('DEBUG', 'apps.eNahar', $schedule)
    let $oref := concat('metis/practitioners/', $owner)
    let $sref := concat('enahar/schedules/', $schedule)
    let $gcals := if ($group='' and $owner='')
        then $r-cal:cals/cal[active[@value="true"]]
        else if ($owner!='')
        then $r-cal:cals/cal[owner/reference[@value=$oref]][active[@value="true"]]
        else r-cal:calsByGroup($group)
    let $valid := if ($schedule='')
        then $gcals
        else $gcals/schedule[global/reference[@value=$sref]]/.. (: tricky: match any cal with a certain schedule :)

    let $sorted-hits :=
        for $qcal in $valid
        order by lower-case($qcal/owner/display/@value/string())
        return
            <cal>
            { $qcal/*[not(self::schedule)] }
            {   (: filter schedule :)
                if ($schedule='')
                then $qcal/schedule[global/reference/@value ne 'enahar/schedules/worktime']
                else 
                    (
                        $qcal/schedule[global/reference/@value=$sref]
                    ,   $qcal/schedule[global/type/@value='meeting']
                    ,   if ($fillSpecial='true')
                        then $qcal/schedule[global/isSpecial/@value='true'][global/ff/@value='true'][global/reference/@value!=$sref]
                        else ()
                    )
            }
            </cal>
    let $lll := util:log-app('DEBUG', 'apps.eNahar', $sorted-hits/owner/display/@value/string())
    let $count := count($sorted-hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <services>
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </services>
};


(:~
 : GET: enahar/services
 : get services
 : 
 : @param $owner   owner display value
 : @param $group   group
 : @param $sched   schedule
 : 
 : @return bundle for select2
 :)
declare
    %rest:GET
    %rest:path("enahar/services")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("start",  "{$start}",   "1")      
    %rest:query-param("length", "{$length}",  "*")
    %rest:query-param("owner",  "{$owner}",   "")
    %rest:query-param("group",  "{$group}",   "")
    %rest:query-param("sched",  "{$schedule}","")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-cal:servicesJSON(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length   as xs:string*
        , $owner as xs:string*
        , $group as xs:string*
        , $schedule as xs:string*
        ) as item()
{
    let $oref := concat('metis/practitioners/', $owner)
    let $sref := if ($schedule='')
        then ''
        else concat('enahar/schedules/', $schedule)
    let $gcals := if ($group='' and $owner='')
        then $r-cal:cals/cal[active[@value="true"]]
        else if ($owner='')
        then r-cal:calsByGroup($group)
        else $r-cal:cals/cal[owner/reference[@value=$oref]][active[@value="true"]]
    let $valid := if ($schedule='')
        then $gcals
        else $gcals/schedule[global/reference[@value=$sref]]/.. (: tricky: match any cal with a certain schedulue :)

    return
    <json:value xmlns:json="http://www.json.org">
            <data>
            {   
                for $g in ('service','worktime')
                return
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                        <text>{$g}</text>
                        <children>
                        {
                            for $s in distinct-values($valid/schedule/global[type/@value=$g]/reference/@value)
                            let $proto := $valid/schedule[global/reference/@value=$s][1]
                            let $id    := substring-after($proto/global/reference/@value,'enahar/schedules/')
                            let $text  := $proto/global/display/@value/string()
                            order by $text
                            return
                            <json:value xmlns:json="http://www.json.org" json:array="true">
                                <id>{$id}</id>
                                <text>{$text}</text>
                            </json:value>
                        }
                        </children>
                    </json:value>

            }
            </data>
    </json:value>
};

    
(:~
 : PUT: enahar/icals
 : Update an existing calendar or store a new one. 
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("enahar/icals")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","") 
    %rest:produces("application/xml", "text/xml")
function r-cal:putCalXML(
          $content as node()*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $isNew   := not($content/cal/@xml:id)
    let $cid   := if ($isNew)
        then "cal-" || substring-after($content/cal/owner/reference/@value,'metis/practitioners/')
        else             
            let $id := $content/cal/id/@value/string()
            let $cals := $r-cal:cals/cal[id[@value = $id]]
            let $move := r-cal:moveToHistory($cals)
            return
                $id

    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/cal/meta/versionID/@value/string()) + 1
    let $elems := $content/cal/*[not(self::meta or self::version or self::id or self::lastModified or self::lastModifiedBy)]
    let $uuid := if ($isNew)
        then $cid
        else "cal-" || util:uuid()
    let $cudir := switch($content//*:cutype//*:code/@value/string())
        case 'person' return 'individuals'
        case 'room'   return 'rooms'
        case 'role'   return 'roles'
        default return error('invalid cutype')
    let $data :=
        <cal xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                <versionID value="{$version}"/>
            </meta>
            <lastModifiedBy>
                <reference value="metis/practitioners/{$loguid}"/>
                <display value="{$lognam}"/>
            </lastModifiedBy>    
            <lastModified value="{adjust-dateTime-to-timezone(current-dateTime(),())}"/>
            {$elems}
        </cal>
        
(:
    let $lll := util:log-system-out($data)
:)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:enahar-icals || '/' || $cudir  , $file, $data)
            , sm:chmod(xs:anyURI($config:enahar-icals || '/' || $cudir || '/' || $file), $r-cal:data-perms)
            , sm:chgrp(xs:anyURI($config:enahar-icals || '/' || $cudir || '/' || $file), $r-cal:data-group)))
        return
            r-cal:rest-response(200, 'cal sucessfully stored.') 
    } catch * {
        r-cal:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

(:~
 : GET: enahar/d2d
 : convert date to date
 : 
 : @param $date
 : 
 : @return json:array
 :)
declare
    %rest:GET
    %rest:path("enahar/d2d")
    %rest:header-param("realm", "{$realm}") 
    %rest:header-param("loguid", "{$loguid}")
    %rest:query-param("date", "{$date}", "")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-cal:d2dJSON($realm as xs:string*, $loguid as xs:string*,
    $date as xs:string*) as item()
{
    try {
        let $s := adjust-date-to-timezone(date:easyDate($date,()), ())
        return
        <json:array xmlns:json="http://www.json.org">
        {
            <json:value xmlns:json="http://www.json.org" json:array="true">
                <id>{$s}</id>
                <text>{$s}</text>
            </json:value>
        }
        </json:array>
    } catch * {
        <json:array xmlns:json="http://www.json.org">
        {
            <json:value xmlns:json="http://www.json.org" json:array="true">
                <id>-1</id>
                <text>illegal date</text>
            </json:value>
        }
        </json:array>
    }

};


(:~
 : Validate an existing ical.
 : The cal XML is read from the request body.
 : 
 :)
declare
    %rest:GET
    %rest:path("enahar/icals/{$uuid}/validate")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("mode",   "{$mode}", "full") 
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-cal:validateCalXML(
          $uuid as xs:string*
        , $realm as xs:string* 
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $mode as xs:string*
        ) as item()+
{
    let $cals := $r-cal:cals/cal[id[@value=$uuid]]
    return
        if (count($cals)=1)
        then 
            let $log := util:log-app("DEBUG", 'apps.eNahar', $cals)
            let $result := icalv:validateCalendar($cals)
            return
            (
                r-cal:rest-response(200, 'schedule valid.')
            ,
                $result
            )
        else  
            (
                r-cal:rest-response(404, 'icals: uuid not valid.')
            ,
                <result>
                    <error/>
                    <info value="{concat('icals: ',$uuid, ': found', count($cals), ' cals')}"/> 
                </result>
            )
};



declare function local:parse-epoch($time as xs:string*) as item()+
{
let $now := current-dateTime()
return
    ( $now, $now + xs:dayTimeDuration('P90D'))
};


