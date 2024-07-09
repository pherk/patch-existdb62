xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-appointment = "http://enahar.org/exist/restxq/nabu/appointments";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
import module namespace xqtime = "http://enahar.org/lib/xqtime";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"        at "../../modules/config.xqm";
import module namespace r-order = "http://enahar.org/exist/restxq/nabu/orders"      at "../../FHIR/Order/order-routes.xqm";
import module namespace r-respon = "http://enahar.org/exist/restxq/nabu/patient-responsibility"  at "../../FHIR/Patient/responsibility-routes.xqm";
import module namespace r-leave   = "http://enahar.org/exist/restxq/metis/leaves"   at "/db/apps/metis/FHIR/Leave/leave-routes.xqm";
import module namespace r-user    = "http://enahar.org/exist/restxq/metis/users"    at "/db/apps/metis/FHIR/user/user-routes.xqm";

import module namespace commsub    = "http://enahar.org/exist/apps/nabu/comm-submit" at "../../FHIR/Communication/comm-submit.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-appointment:enahar-schedule-ref := "enahar/schedules/";
declare variable $r-appointment:coll := collection($config:nabu-appointments);
declare variable $r-appointment:history := concat($config:history-data, '/Appointments');

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

declare %private function r-appointment:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <appointments xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </appointments>
};



declare %private function r-appointment:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~ moveToHistory
 : Move to history
 : 
 : @param $objects
 : @return ()
 :)
declare function r-appointment:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-appointment:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-appointment:history, $nameHistory)
                    )
        )
};


(:~
 : GET: nabu/appointments/{$id}
 : List appointment with id.
 : 
 : @return  <Appointment>...</Appointment>
 :)
declare
    %rest:GET
    %rest:path("nabu/appointments/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:produces("application/xml", "text/xml")
function r-appointment:appointmentByID($id as xs:string*, $realm as xs:string*, $loguid as xs:string*) as item()
{
    let $aps := $r-appointment:coll/Appointment[fhir:id[@value = $pid]]
    return
        if (count($aps)=1) 
        then $aps
        else if (count($aps)>1)
            then r-appointment:rest-response(404, concat('Appointment with ID: ',$id, ' too many. Ask the Admin.'))
        else r-appointment:rest-response(404, concat('Appointment with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : update subject 
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $pid
 : @param $pnam
 : 
 : @return 
 :)
declare function r-appointment:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-appointment:coll/fhir:Appointment[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/*:participant[*:type/*:coding/*:code/@value='patient']/fhir:actor/fhir:reference/@value with concat('nabu/patients/',$pid)
                , update value $res/*:participant[*:type/*:coding/*:code/@value='patient']/fhir:actor/fhir:display/@value with $pnam
                , update value $res/fhir:lastModifiedBy/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:lastModifiedBy/fhir:display/@value with $lognam
                , update value $res/fhir:lastModified/@value with current-dateTime()
                ))
        else ()
};

(:~
 : GET: /nabu/appointments/{$id}/_history
 : get appointment history with id $id
 : 
 : @param $id  appointment id
 : 
 : @return  appointment bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/appointments/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-appointment:appointmentHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-appointment:coll | collection($r-appointment:history)
    let $hits  := $coll/fhir:Appointment[fhir:id[@value=$id]] 
    return
        r-appointment:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/appointments/{$id}/_history/{$vid}
 : get appointment history with id $id and version $vid
 : 
 : @param $id doc id
 : @param $vid version id
 : 
 : @return  doc bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/appointments/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-appointment:appointmentVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-appointment:coll | collection($r-appointment:history)
    let $hits  := $coll/fhir:Appointment[fhir:id[@value=$id]][meta/versionId/@value=$vid]
    return
        r-appointment:prepareHistoryBundle($id, $hits)
};

declare %private function r-appointment:prepareHistoryBundle($id, $entries)
{
    let $serverip := 'http://enahar.org'
    return
        <feed>
            <id></id>
            <version>0</version>
            <type value="history"/>
            <title/>
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/appointments/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/nabu"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/meta/versionId/@value)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/nabu/appointments/{$id}/_history/{$e/meta/version/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/appointments/{$id}/_history/{$e/meta/version/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search parameters FHIR 0.4 
 : actor	reference	Any one of the individuals participating in the appointment	Appointment.participant.actor
 : date	date	Appointment date/time.	Appointment.start
 : partstatus	token	The Participation status of the subject, or other participant on the appointment	Appointment.participant.status
 : patient	reference	One of the individuals of the appointment is this patient	Appointment.participant.actor
 : status	token	The overall status of the appointment	Appointment.status
 :)
(:~
 : GET: nabu/appointments?start=1&length=10&status=...
 : List appointments for participant $uid and return them as XML.
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
    %rest:path("nabu/appointments")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("start",    "{$start}",   "1")      
    %rest:query-param("length",   "{$length}",  "*")
    %rest:query-param("uid",      "{$uid}", "")
    %rest:query-param("group",    "{$group}", "")  
    %rest:query-param("sched",    "{$sched}",  "")
    %rest:query-param("patient",  "{$patient}", "")
    %rest:query-param("rangeStart", "{$rangeStart}", "1970-01-01T00:00:00")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2021-04-01T23:59:59")
    %rest:query-param("status",   "{$status}",  "")
    %rest:query-param("_sort",   "{$sort}", "date:asc")
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-appointment:appointmentsXML(
    $realm as xs:string*, $loguid as xs:string*,
    $start as xs:string*, $length as xs:string*,
    $uid as xs:string*, $group as xs:string*, $sched as xs:string*,
    $patient as xs:string*,
    $rangeStart as xs:string*, $rangeEnd as xs:string*,
    $status as xs:string*,
    $sort as xs:string*
    ) as item()
{
    try {
        let $coll := $r-appointment:coll
        let $tmin := if (contains($rangeStart,'T'))
            then $rangeStart
            else concat($rangeStart, 'T00:00:00')
        let $tmax := if (contains($rangeEnd,'T'))
            then $rangeEnd
            else concat($rangeEnd, 'T23:59:59')
        let $uref := concat('metis/practitioners/', $uid)
        let $matched0 := if ($uid!='')
            then $coll/fhir:Appointment[fhir:participant/fhir:actor[fhir:reference[@value=$uref]]][fhir:start[@value>$tmin]][fhir:end[@value<$tmax]]
            else if ($group!='')
                then $coll/fhir:Appointment[fhir:start[@value>$tmin]][fhir:end[@value<$tmax]][fhir:participant[fhir:type/fhir:coding/fhir:code/@value = $group]]
                else $coll/fhir:Appointment[fhir:start[@value>$tmin]][fhir:end[@value<$tmax]]
        let $matched1 := if ($sched!='')
            then $matched0[fhir:type/fhir:coding/fhir:code/@value=$sched]
            else $matched0
        let $matched : = if ($status!='')
            then $matched1[status[@value=$status]]
            else $matched1

        let $sorted-hits := switch($sort)
            case "patient:asc" return
                for $a in $matched
                order by $a/participant[type/coding/code/@value eq "patient"]/actor/display/@value/string() collation "?lang=de-DE"
                return
                    $a
            case "actor:asc" return
                for $a in $matched
                order by $a/participant[type/coding/code/@value ne "patient"]/actor/display/@value/string() collation "?lang=de-DE"
                return
                    $a
            default return 
                for $a in $matched
                order by $a/start/@value/string() collation "?lang=de-DE"
                return
                    $a
        return
            r-appointment:prepareResult($sorted-hits, $start, $length)
    } catch * {
        r-appointment:rest-response(404, concat('Invalid time filter? : ', $rangeStart, ' - ', $rangeEnd))
    }
};

declare
    %rest:GET
    %rest:path("nabu/appointments")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("actor",    "{$uid}", "")
    %rest:query-param("group",    "{$group}", "")  
    %rest:query-param("sched",    "{$sched}",  "")  
    %rest:query-param("rangeStart",  "{$rangeStart}", "1970-01-01T00:00:00")      
    %rest:query-param("rangeEnd",  "{$rangeEnd}", "1970-01-01T23:59:59")
    %rest:query-param("start",    "{$start}",   "1")      
    %rest:query-param("length",   "{$length}",  "*")
    %rest:query-param("status",   "{$status}",  "booked")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-appointment:appointmentsJSON($realm as xs:string*, $loguid as xs:string*,
    $uid as xs:string*, $group as xs:string*, $sched as xs:string*,
    $rangeStart as xs:string*, $rangeEnd as xs:string*,
    $start as xs:string*, $length as xs:string*, $status as xs:string*) as item()
{
    (: let $roles := r-user:rolesByUID($uid) 
    let $lll := util:log-system-out(string-join(($uid, $group, $sched),'-'))
    return
    :)

    try {
        let $tmin := if (contains($rangeStart,'T'))
            then xs:dateTime($rangeStart)
            else dateTime(xs:date($rangeStart), xs:time('00:00:00'))
        let $tmax := if (contains($rangeEnd,'T'))
            then xs:dateTime($rangeEnd)
            else dateTime(xs:date($rangeEnd), xs:time('23:59:59'))
        let $coll := $r-appointment:coll
        let $uref := concat('metis/practitioners/',$uid)
        let $matched0 := if ($uid!='')
            then $coll/fhir:Appointment[fhir:participant/fhir:actor[fhir:reference[@value=$uref]]][fhir:start[@value>$tmin]][fhir:end[@value<$tmax]]
            else if ($group!='')
            then $coll/Appointment[participant[type/coding/code/@value=$group]][fhir:start[@value>$tmin]][fhir:end[@value<$tmax]]
            else $coll/Appointment[start/@value>$tmin][end/@value<$tmax]
        let $matched := if ($sched!='')
            then $matched0[type/coding/code/@value=$sched][status/@value=$status]
            else $matched0[status/@value=$status]

        let $sorted-hits := for $a in $matched
                order by $a/start/@value/string() collation "?lang=de-DE"
                return
                    $a
        return
            <json:value xmlns:json="http://www.json.org">
            {
                for $e in $sorted-hits
                let $title := $e/fhir:participant/fhir:actor/fhir:display/@value/string()
                return
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                        <id>{$e/fhir:id/@value/string()}</id>
                        <title>{$title}</title>
                        <description>{$e/fhir:description/@value/string()}</description>
                        <start>{$e/fhir:start/@value/string()}</start>
                        <end>{$e/fhir:end/@value/string()}</end>
                        <allDay json:literal='true'>false</allDay>
                        <editable json:literal='true'>{$e/locked/@value/string()='false'}</editable>
                        <backgroundColor>{
                            switch($e/fhir:status/@value)
                            case 'booked' return 'blue'
                            case 'tentative' return 'red'
                            case 'fulfilled' return 'green'
                            case 'arrived' return 'lime'
                            case 'registered' return 'lime'
                            case 'noshow' return 'fuchsia'
                            default return 'grey'
                        }</backgroundColor>
                    </json:value>
            }
            </json:value>
    } catch * {
        r-appointment:rest-response(404, concat('Invalid time filter? : ', $rangeStart, ' -- ', $rangeEnd))
    }
};


declare %private function local:quartal($date as xs:dateTime) as xs:string
{
    let $m := month-from-dateTime($date)
    return
        if ($m < 4)         then 'Q1'
        else if ($m < 7)    then 'Q2'
        else if ($m < 10)   then 'Q3'
        else                     'Q4'
        
};

(:~
 : GET: /nabu/apps2pdf
 : Search apps using a given field and a (lucene) query string.
 : 
 : @return apps as pdf
 :)
declare 
    %rest:GET
    %rest:path("/nabu/apps2pdf")
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
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "")
    %rest:query-param("status",   "{$status}",  "booked")
    %rest:query-param("_sort",    "{$sort}", "archive")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-appointment:app2PDF(
    $realm as xs:string*, $loguid as xs:string*, $lognam as xs:string*,
    $start as xs:string*, $length as xs:string*,
    $uid as xs:string*, $group as xs:string*, $sched as xs:string*,
    $patient as xs:string*,
    $rangeStart as xs:string*, $rangeEnd as xs:string*,
    $status as xs:string*,
    $sort as xs:string*
    )
{
    (:
    let $facets := 
        <facets xmlns="">
            <facet name="name"      method="matches" path="fhir:name[fhir:use/@value='official']/fhir:family/@value">{$name}</facet>
            <facet name="city"      method="matches" path="fhir:address/fhir:city/@value">{$city}</facet>
            <facet name="org"       method="equals"  path="fhir:organization/fhir:reference/@value">{$org}</facet>
            <facet name="role"      method="equals"  path="fhir:role/fhir:coding/fhir:code/@value">{$role}</facet>
            <facet name="specialty" method="equals"  path="fhir:specialty/fhir:coding/fhir:code/@value">{$specialty}</facet>
            <facet name="tag"       method="matches" path="fhir:meta/fhir:tag/fhir:text/@value">{$tag}</facet>
            <facet name="active"    method="equals"  path="fhir:active/@value">{$active}</facet>
        </facets>
    :)
    let $coll := $r-appointment:coll
    let $tmin := if (contains($rangeStart,'T'))
            then xs:dateTime($rangeStart)
            else dateTime(xs:date($rangeStart), xs:time('00:00:00'))
    let $tmax := if (contains($rangeEnd,'T'))
            then xs:dateTime($rangeEnd)
            else dateTime(xs:date($rangeEnd), xs:time('23:59:59'))
    let $uref := concat('metis/practitioners/', $uid)
    let $matched0 := if ($uid!='')
            then $coll/Appointment[participant/actor/reference/@value=$uref][start/@value>$tmin][end/@value<$tmax]
            else if ($group!='')
                then $coll/fhir:Appointment[fhir:start[@value>$tmin]][fhir:end[@value<$tmax]][matches(participant/type/coding/code/@value,$group)]
                else $coll/fhir:Appointment[fhir:start[@value>$tmin]][fhir:end[@value<$tmax]]
    let $matched1 := if ($sched!='')
            then $matched0[type/coding/code/@value=$sched]
            else $matched0
    let $matched : = if ($status!='')
            then $matched1[status/@value=$status]
            else $matched1
    let $range := if (r-appointment:sameDay($tmin,$tmax))
        then
            format-dateTime($tmin,'[D01].[M01].[Y01]')
        else
            concat(format-dateTime($tmin,'[D01].[M01]'),'-', format-dateTime($tmax,'[D01].[M01].[Y01]'))
    let $result := 
        switch ($sort)
        case 'perDay'  return r-appointment:preparePerDayList($matched, $tmin, $tmax)
        case 'archive' return r-appointment:prepareArchiveList($matched, $tmin, $tmax, $realm, $loguid, $lognam)
        default return ()
    let $filename := 
        switch ($sort)
        case 'perDay'  return 'tagesliste-'
        case 'archive' return 'archiv-'
        default return 'error'
    return
        if ($result)
        then 
            let $fo  := tei2fo:report($result)
            let $pdf := xslfo:render($fo, "application/pdf", ())
            let $file := concat($filename,$range,'.pdf')
            return
            (   <rest:response>
                    <http:response status="200">
                        <http:header name="Content-Type" value="application/pdf"/>
                        <http:header name="Content-Disposition" value="attachment;filename={$file}"/>
                    </http:response>
                 </rest:response>
            ,   $pdf
            )
        else
            r-appointment:rest-response(404, 'Appointment List empty')
            
};

declare %private function r-appointment:sameDay($tmin,$tmax) as xs:boolean
{
    xs:date($tmin) = xs:date($tmax)
};

declare %private function r-appointment:preparePerDayList($apps, $tmin, $tmax)
{

    let $nofd  := xs:integer(floor(($tmax - $tmin) div xs:dayTimeDuration('P1D')))
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header("Termine") }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                {
                    (: enumerate days in period :)
                    for $n in (0 to $nofd)
                    let $date  := $tmin + xs:dayTimeDuration('P1D')*$n
                    let $d := format-dateTime($date,'[Y0001]-[M01]-[D01]')
                    let $appsday := $apps[starts-with(fhir:start/@value,$d)]
                    return
                    <table rows="{count($appsday)}" cols="3.5:2:7:4"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <head>Termine vom {format-dateTime($date,'[D01].[M01].[Y01]')}</head>
                            <row role="label">
                                    <cell role="label">Uhrzeit</cell>
                                    <cell role="label">OE</cell>
                                    <cell role="label">Patient</cell>
                                    <cell role="label">Erbringer</cell>
                            </row>
                    {
                        for $a in $appsday
                        let $id := substring-after($a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value  = 'patient']/fhir:actor/fhir:reference/@value,'nabu/patients/')
                        let $oe := r-respon:managingOrganizationByIDXML($id,'kikl-spz','u-admin','Admin')
                        let $time := concat(format-dateTime($a/fhir:start/@value,'[H01]:[m01]'),' - ',format-dateTime($a/fhir:end/@value,'[H01]:[m01]'))
                        order by $time
                        return
                        <row role="data">
                            <cell role="data">{$time}</cell>
                            <cell role="data">{substring-after($oe/fhir:reference/@value,'metis/organizations/ukk-oe')}</cell>
                            <cell role="data">{$a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value  = 'patient']/fhir:actor/fhir:display/@value/string()}</cell>
                            <cell role="data">{$a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value/string() != 'patient']/fhir:actor/fhir:display/@value/string()}</cell>
                        </row>
                    }
                    </table>
                }
                </div>
            </body>
        </text>
    </TEI>
    return $result
};

declare %private function r-appointment:prepareArchiveList($apps, $tmin, $tmax, $realm, $loguid, $lognam)
{
    let $prefs := distinct-values($apps/fhir:participant[fhir:type/fhir:coding/fhir:code/@value ='patient']/fhir:actor/fhir:reference/@value)
    let $files :=
                for $pref in $prefs
                let $id       := substring-after($pref,'nabu/patients/')
                let $respon   := r-respon:responsibilitiesXML($id, $realm, $loguid, $lognam, '',  '1994-06-01T08:00:00', "2021-04-01T23:00:00","full")
                let $known    := count($respon/participant)>0
                let $lastDate := if ($known)
                    then xxpath:highest(function($p){$p/period/start/@value}, $respon/participant)[1]/period/start/@value/string()
                    else ''
                let $lastActors := if ($known)
                    then string-join($respon/participant[period/start/@value=$lastDate]/actor/display/@value,', ')
                    else ''
                let $appByPat := $apps[fhir:participant/fhir:actor[fhir:reference[@value=$pref]]]
                let $pat      := $appByPat/fhir:participant[fhir:type/fhir:coding/fhir:code/@value  = 'patient']/fhir:actor/fhir:display/@value/string()
                let $newActors:= $appByPat/fhir:participant[fhir:type/fhir:coding/fhir:code/@value/string() != 'patient']/fhir:actor/fhir:display/@value/string()
                order by $pat[1]
                return
                    if ($known)
                    then

                        let $date:=  $apps[fhir:participant/fhir:actor[fhir:reference[@value=$pref]]]/fhir:start/@value/string()
                        let $q   := if ($lastDate < '2014-01-01')
                            then ''
                            else local:quartal(xs:dateTime($lastDate))
                        return
                        <file>
                            <lastEncounterDate value="{$lastDate}"/>
                            <quartal value="{$q}"/>
                            <appDate value="{$date[1]}"/>
                            <name value="{$pat[1]}"/>
                            <lastActors value="{$lastActors}"/>
                            <newActors value="{$newActors}"/>
                        </file>
                    else ()

    let $years :=
            for $f in $files 
            return
                tokenize(tokenize($f/fhir:lastEncounterDate/@value,'T')[1],'-')[1]
    let $range := if ($tmin=$tmax)
        then
            format-dateTime($tmin,'[D01].[M01].[Y01]')
        else
            concat(format-dateTime($tmin,'[D01].[M01]'),'-', format-dateTime($tmax,'[D01].[M01].[Y01]'))
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header("Aktenliste für Archiv") }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                    <table rows="{count($files)}" cols="1:1:0.5:3.5:1.5:7:4"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <head>Aktenliste vom {$range}</head>
                            <row role="label">
                                    <cell role="label">Jahr</cell>
                                    <cell role="label">Datum</cell>    
                                    <cell role="label">Q</cell>
                                    <cell role="label">Letzte Erbringer</cell>
                                    <cell role="label">Termin</cell>
                                    <cell role="label">Patient</cell>
                                    <cell role="label">Erbringer</cell>
                            </row>
                    {
                        for $y in distinct-values($years)
                        order by $y
                        return
                            if ($y < '2014')
                            then
                                let $fInYear := $files[starts-with(fhir:lastEncounterDate/@value,$y)]
                                for $f at $i in $fInYear
                                return
                            <row role="data">
                                    <cell role="label">{if ($i=1) then $y else ''}</cell>
                                    <cell role="data">{format-dateTime($f/fhir:lastEncounterDate/@value,'[D01].[M01].')}</cell>    
                                    <cell role="data">{''}</cell>
                                    <cell role="data">{$f/fhir:lastActors/@value/string()}</cell>
                                    <cell role="data">{format-dateTime($f/fhir:appDate/@value,'[D01].[M01].')}</cell>
                                    <cell role="data">{$f/fhir:name/@value/string()}</cell>
                                    <cell role="data">{$f/fhir:newActors/@value/string()}</cell>
                            </row>
                            else
                                let $fInYear := $files[starts-with(fhir:lastEncounterDate/@value,$y)]
                                let $qs      := 
                                    for $q in distinct-values($fInYear/fhir:quartal/@value)
                                    order by $q
                                    return
                                        $q
                                for $q  in $qs
                                let $fInQ := $fInYear[fhir:quartal/@value=$q]
                                return
                                    let $fs := 
                                        for $fq in $fInQ
                                        order by $fq/fhir:name/@value/string()
                                        return
                                            $fq
                                    for $f at $i in $fs
                                    return
                            <row role="data">
                                    <cell role="label">{if ($i=1) then $y else ''}</cell>
                                    <cell role="data">{format-dateTime($f/fhir:lastEncounterDate/@value,'[D01].[M01].')}</cell>
                                    <cell role="data">{if ($i=1) then $f/fhir:quartal/@value/string() else ''}</cell>
                                    <cell role="data">{$f/fhir:lastActors/@value/string()}</cell>
                                    <cell role="data">{format-dateTime($f/fhir:appDate/@value,'[D01].[M01].')}</cell>
                                    <cell role="data">{$f/fhir:name/@value/string()}</cell>
                                    <cell role="data">{$f/fhir:newActors/@value/string()}</cell>
                            </row>
                    }
                    </table>
                </div>
            </body>
        </text>
    </TEI>
    return $result
};

(:~
 : GET: nabu/appointments/templates/{$aid}
 : get appointment template with id.
 : 
 : @return  <Appointment>...</Appointment>
 :)
declare
    %rest:GET
    %rest:path("nabu/appointments/templates/{$aid}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:produces("application/xml", "text/xml")
function r-appointment:appointmentTemplateByID($aid as xs:string*, $realm as xs:string*, $loguid as xs:string*) as item()
{
    let $appointment := collection($config:nabu-templs)//Appointment
    return
        if ($appointment)
        then $appointment
        else r-appointment:rest-response(404, concat('Appointment template with ID: ',$aid, ' not found. Ask the Admin.'))
};


(:~
 : Search parameters FHIR 0.4 
 : actor	reference	Any one of the individuals participating in the appointment	Appointment.participant.actor
 : date	date	Appointment date/time.	Appointment.start
 : partstatus	token	The Participation status of the subject, or other participant on the appointment	Appointment.participant.status
 : patient	reference	One of the individuals of the appointment is this patient	Appointment.participant.actor
 : status	token	The overall status of the appointment	Appointment.status
 :)
(:~
 : GET: nabu/appointmentsBySubject
 : List appointments for participant $uid and return them as XML.
 : 
 : @param   $subject     ids of participants
 : @param   $status  FHIR status
 : @return  bundle <appointments/>
 :)
declare
    %rest:GET
    %rest:path("nabu/appointmentsBySubject/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")    
    %rest:query-param("date",   "{$date}",  "")
    %rest:query-param("status",   "{$status}",  "")
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-appointment:appointmentsBySubject(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $date as xs:string*
        , $status as xs:string*
    ) as item()
{
    try {
        let $sref    := concat('nabu/patients/',$id)
        let $matched := if ($status="")
            then $r-appointment:coll/Appointment[fhir:participant/fhir:actor[fhir:reference[@value=$sref]]]
            else $r-appointment:coll/Appointment[fhir:participant/fhir:actor[fhir:reference[@value=$sref]]][fhir:status[@value=$status]]
        let $sorted-hits := for $a in $matched
                order by $a/start/@value/string() collation "?lang=de-DE"
                return
                    $a
        return
            r-appointment:prepareResult($sorted-hits, '1', '*')
    } catch * {
        r-appointment:rest-response(404, concat('Invalid subject? : ', $id))
    }
};
 
(:~
 : GET: nabu/appointments/{$uid}/letter
 : create appointment letter for subject
 : 
 : @return <response>
 :)
declare
    %rest:GET
    %rest:path("nabu/appointments/{$subject}/letter")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}", '')
    %rest:query-param("status", "{$status}", 'in-progress')
    %rest:produces("application/xml", "text/xml")
function r-appointment:appletter(
      $subject as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $status as xs:string*
    ) as item()
{
    try {
        let $booked := r-appointment:appointmentsBySubject($subject, 'kikl-spz', $loguid, $lognam, (), 'booked')
        (: submit communication to family if any appointments :)
        return
            if (count($booked/fhir:Appointment) > 0)
            then
                let $action := $booked/fhir:Appointment[1]/fhir:order/fhir:reference/@value
                let $comm := commsub:submitInfoLetter($realm, $loguid, $lognam, $action, $subject, $booked, (), $status)
                return
                    r-appointment:rest-response(200, 'appointment letter sucessfully stored.')
            else
                    r-appointment:rest-response(401, 'no appointments, no letter.')
    } catch * {
        r-appointment:rest-response(401, 'permission denied. Ask the admin.') 
    }  
};

 
(:~
 : PUT: nabu/order2apps
 : Make appointments, make communication resource, store referring order. 
 : The order XML is read from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/order2apps")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}", '')
    %rest:produces("application/xml", "text/xml")
function r-appointment:submitOrder(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    try {
        let $order  := $content/fhir:Order
    (:
        let $lll := util:log-app('DEBUG', 'nabu', $order)
    :)
        let $subject:= substring-after($order/fhir:subject/fhir:reference/@value, 'nabu/patients/')
        let $booked := r-appointment:appointmentsBySubject($subject, 'kikl-spz', $loguid, $lognam, (), 'booked')
        (: submit single appointments :)
        let $new := for $d in $order/fhir:detail
            return
                switch ($d/fhir:proposal/fhir:acq/@value)
                case 'open' return ()
                case 'tentative' return r-appointment:submitOrderDetail($realm, $loguid, $lognam, $order, $d, "tentative")
                case 'accepted'  return r-appointment:submitOrderDetail($realm, $loguid, $lognam, $order, $d, "booked")
                case 'confirmed' return r-appointment:submitOrderDetail($realm, $loguid, $lognam, $order, $d, "booked")
                case 'cancelled' return ()
                case 'closed'    return ()
                default return error("illegal acq code in order detail")
        (: submit communication to family :)
        let $comm := if ($new)  (: only make letter if new appointment was made :)
            then commsub:submitInfoLetter($realm, $loguid, $lognam, $order/fhir:id/@value,$subject, $booked, $new, 'in-progress')
            else ()
        (: submit order :)
        let $closed := 
            let $base := $order/fhir:*[not(self::detail)]
            let $details := $order/fhir:detail
            return
                <Order xmlns="http://hl7.org/fhir" xml:id="{$order/@xml:id/string()}">
                    { $base }
                    {
                        for $d in $details
                        let $db := $d/fhir:*[not(self::proposal)]
                        let $start:= $d/proposal/start/@value/string()
                        let $end  := $d/proposal/end/@value/string()
                        let $acq  := switch($d/proposal/acq/@value)
                            case 'tentative' return 'closed'
                            case 'accepted'  return 'closed'
                            default return $d/proposal/acq/@value/string()
                        return
                            <detail id="{$d/@id/string()}">
                                { $db }
                                <proposal>
                                    <start value="{$start}"/>
                                    <end value="{$end}"/>
                                    <acq value="{$acq}"/>
                                </proposal>
                            </detail>
                    }
                </Order>
        let $ret := r-order:putOrderXML(document {$closed}, $realm, $loguid, $lognam)
        return
            r-appointment:rest-response(200, concat(count($new), ' appointment(s) sucessfully stored.')) 
    } catch * {
        r-appointment:rest-response(401, 'permission denied. Ask the admin.') 
    }  
};

(:~
 : submitTentative 
 : submit tentative appointment to actor
 :
 : @param $order
 : @param $detail
 :)
declare %private function r-appointment:submitOrderDetail(
        $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $order as item()
        , $detail as item()
        , $status as xs:string
        ) as item()*
{
    let $app := r-appointment:fillAppointmentTemplate($order, $detail, $status)
    let $ret := r-appointment:putAppointmentXML(document {$app}, $realm, $loguid, $lognam)
    return
        switch ($status)
        case 'booked' return $app
        default return ()
};

declare %private function r-appointment:fillAppointmentTemplate(
    $order as item(),
    $detail as item(),
    $status as xs:string
    ) as item()
{
    let $oref  := concat("nabu/orders/", $order//fhir:id/@value,"?detail=",$detail/@id)
    let $pref  := $order//fhir:subject/fhir:reference/@value/string()
    let $pdis  := $order//fhir:subject/fhir:display/@value/string()
    let $reason := if ($order//fhir:reason/fhir:text/@value='')
        then $order//fhir:reason/fhir:coding/fhir:display/@value/string()
        else $order//fhir:reason/fhir:text/@value/string()
    let $info  := ''
    let $termin-info  := string-join($detail/fhir:info/@value, ' - ')
    let $start := $detail/fhir:proposal/fhir:start/@value/string()
    let $end   := $detail/fhir:proposal/fhir:end/@value/string()
    let $scode := substring-after($detail/fhir:schedule/fhir:reference/@value/string(), $r-appointment:enahar-schedule-ref)
    let $sdis  := if ($detail/fhir:schedule/fhir:display/@value/string()='')
        then 'SPZ Ambulanz'
        else $detail/fhir:schedule/fhir:display/@value/string()
    let $aref  := $detail//fhir:actor/fhir:reference/@value/string()
    let $adis  := $detail//fhir:actor/fhir:display/@value/string()
    let $arole := $detail//fhir:actor/fhir:role/@value/string()
    let $dur   := (xs:dateTime($end) - xs:dateTime($start)) div xs:dayTimeDuration('PT1M')
    let $now   := adjust-dateTime-to-timezone(current-dateTime(),())
    return
<Appointment xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionId value="0"/>
    </meta>
    <priority value="0"/>
    <status value="{$status}"/>
    <type>
        <coding>
            <system value="#appointment-type"/>
            <code value="{$scode}"/>
            <display value="{$sdis}"/>
        </coding>
        <text value="{$sdis}"/>
    </type>
    <serviceCategory>
        <coding>
            <system value="#service-category"/>
            <code value="ambulant"/>
            <display value="Ambulanz"/>
        </coding>
    </serviceCategory>
    <specialty>
        <coding>
            <system value="#specialty"/>
            <code value="pediatics"/>
            <display value="Pediatrics"/>
        </coding>
    </specialty>
    <appointmentType>
        <coding>
            <system value="#appointment-type"/>
            <code value="followup"/>
            <display value="WV"/>
        </coding>
    </appointmentType>
    <reason>
        <coding>
            <system value="#encounter-reason"/>
            <code value="appointment"/>
            <display value="{$reason}"/>
        </coding>
        <text value="{$reason}"/>
    </reason>
    <description value="{$info}"/>
    <start value="{$start}"/>
    <end value="{$end}"/>
    <minutesDuration value="{$dur}"/>
    <created value="{$now}"/>
    <location>
        <reference value="metis/locations/kikl-spz"/>
        <display value="SPZ Kinderklinik"/>
    </location>
    <comment value="{$termin-info}"/>
    <order>
        <reference value="{$oref}"/>
    </order>
    <participant>
        <type>
            <coding>
                <system value="#appointment-role"/>
                <code value="patient"/>
                <display value="Patient"/>
            </coding>
            <text value="Patient"/>
        </type>
        <actor>
            <reference value="{$pref}"/>
            <display value="{$pdis}"/>
        </actor>
        <required value="req"/>
        <status value="accepted"/>
    </participant>
    <participant>
        <type>
            <coding>
                <system value="#appointment-role"/>
                <code value="{$arole}"/>
                <display value="{$arole}"/>
            </coding>
            <text value="{$arole}"/>
        </type>
        <actor>
            <reference value="{$aref}"/>
            <display value="{$adis}"/>
        </actor>
        <required value="req"/>
        <status value="accepted"/>
    </participant>
</Appointment>
};

(:~
 : POST: nabu/appointments
 : Update an tentative appointment, send info letter to family
 : The appointment XML is read from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/appointments")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-appointment:postAppointmentAfterAccepting(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
 let $lll := util:log-system-out($loguid)
let $lll := util:log-system-out($lognam)   
    let $app    := $content/fhir:Appointment
    let $subject:= substring-after($app/fhir:participant[fhir:type/fhir:coding/fhir:code/@value='patient']/fhir:actor/fhir:reference/@value,'nabu/patients/')
    let $booked := r-appointment:appointmentsBySubject($subject, 'kikl-spz', $loguid, $lognam, (), 'booked')
    (:
    let $order  := r-order:orderByID(substring-after($app/fhir/order/fhir:reference/@value,'nabu/orders/'),$realm, $loguid)
    :)
    (: submit communication to family :)
    let $action := $app/fhir:order/fhir:reference/@value/string()
    let $comm := commsub:submitInfoLetter($realm, $loguid, $lognam, $action, $subject, $booked, $app, 'in-progress')
    return
        r-appointment:putAppointmentXML(document {$app}, $realm, $loguid, $lognam)
};

(:~
 : PUT: nabu/appointments
 : Update an existing appointment or store a new one.
 : The appointment XML is read from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/appointments")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-appointment:putAppointmentXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew   := not($content/Appointment/@xml:id)
    let $aid   := if ($isNew)
        then concat("a-", util:uuid())
        else             
            let $id := $content/fhir:Appointment/fhir:id/@value/string()
            let $apps := $r-appointment:coll/fhir:Appointment[fhir:id[@value = $id]]
            let $move := r-appointment:moveToHistory($apps)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Appointment/meta/versionId/@value/string()) + 1
    let $base := $content/Appointment/fhir:*[not(
                                               self::meta
                                            or self::id
                                            or self::lastModified
                                            or self::lastModifiedBy
                                            )]
    let $meta := $content//meta/fhir:*[not(self::versionId)]
    let $uuid := if ($isNew)
        then $aid
        else concat("a-", util:uuid())
    let $data := 
        <Appointment xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$aid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
            </meta>
            <lastModifiedBy>
                <reference value="{concat('metis/practitioners/',$loguid)}"/>
                <display value="{$lognam}"/>
            </lastModifiedBy>    
            <lastModified value="{current-dateTime()}"/>
            {$base}
        </Appointment>
(:
    let $lll := util:log-system-out($data)
:)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:nabu-appointments, $file, $data)
            , sm:chmod(xs:anyURI($config:nabu-appointments || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:nabu-appointments || '/' || $file), $config:data-group)))
        return
            r-appointment:rest-response(200, 'appointment sucessfully stored.') 
    } catch * {
        r-appointment:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

