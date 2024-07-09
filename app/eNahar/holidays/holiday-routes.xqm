xquery version "3.0";
(: ~
 : Defines all the RestXQ endpoints used for holidays.
 : 
 : @author Peter Herkenrath
 : @version 0.1
 : 2015-03-28
 :)
module namespace r-hd = "http://enahar.org/exist/restxq/enahar/holidays";


import module namespace ice    = "http://enahar.org/lib/ice";   (: ice:match-rrules() :)
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";
import module namespace config = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";

declare namespace xdb ="http://exist-db.org/xquery/xmldb";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare %private function r-hd:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};


(:~
 : GET: enahar/holidays/{uuid}
 : get holiday by id
 : 
 : @param $id  uuid
 :)
declare
    %rest:GET
    %rest:path("enahar/holidays/{$uuid}")
    %rest:produces("application/xml", "text/xml")
function r-hd:holidayByID($uuid as xs:string*) as item()*
{
    let $cals := collection($config:enahar-data)/holidays
    return
        if (count($cals)>0) then
            xxpath:highest(function($e){xs:integer($e/meta/versionID/@value)}, $cals)
        else  r-hd:rest-response(404, 'icals: uuid not valid.')
};

(:~
 : GET: enahar/holidays
 : get holidays by owner
 : 
 : @param $start    begin as date or dateTime
 : @param $end      end as date or dateTime
 : @param $owner    owner ref aka user id
 : @param $group    group
 : @param $sched    schedule
 : 
 : @return bundle of <events/>
 :)
declare
    %rest:GET
    %rest:path("enahar/holidays")
    %rest:query-param("start", "{$start}", "1970-01-01")
    %rest:query-param("end",   "{$end}",   "1970-01-01")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-hd:holidaysXML($start as xs:string*, $end as xs:string*) as item()
{
    let $s  := xs:date(tokenize($start,'T')[1])
    let $e  := xs:date(tokenize($end,  'T')[1])
    let $nofd  := xs:integer(floor(($e - $s) div xs:dayTimeDuration('P1D')))
    let $hds   := collection($config:ical-data)/holidays
    let $events := $hds/event
    return
    <events>
    {
        for $d in (0 to $nofd)
        let $date  := $s + xs:dayTimeDuration('P1D')*$d
        let $hde := ice:match-rrules($date, $events)
        return
                r-hd:fc-eventXML($hde, $date)
    }
    </events>
};

declare %private function r-hd:fc-eventXML($e as item()?, $date as xs:date) as item()?
{
    if (empty($e)) then
        ()
    else
        <event>
            <id value="{$e/name/@value/string()}"/>
            <title value="{$e/description/@value/string()}"/>
            <type value="{$e/type/@value/string()}"/>
            { if ($e/type/@value='official')
                then
                    (
                      <allDay value="true"/>
                    , <start value="{dateTime($date, xs:time(xs:dateTime($e/start/@value)))}"/>
                    )
                else
                    (
                      <allDay value="false"/>
                    , <start value="{dateTime($date, xs:time(xs:dateTime($e/start/@value)))}"/>
                    , <end value="{if ($e/type/@value='traditional') then dateTime($date, xs:time(xs:dateTime($e/end/@value))) else concat($date,'T23:59:59')}"/>
                    )
            }
        </event>
};


(:~
 : GET: enahar/holidays
 : get holidays 
 : 
 : @param $start  
 : @param $end
 : 
 : @return json array
 :)
declare
    %rest:GET
    %rest:path("enahar/holidays")
    %rest:query-param("rangeStart", "{$rangeStart}", "1970-01-01")
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "1970-01-01")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-hd:holidaysJSON($rangeStart as xs:string*, $rangeEnd as xs:string*)
{
    let $s  := xs:date($rangeStart)
    let $e  := xs:date($rangeEnd)
    let $last  := day-from-date($e)
    let $nofd  := xs:integer(floor(($e - $s) div xs:dayTimeDuration('P1D')))
    let $hds := collection($config:ical-data)/holidays
    let $events := $hds/event
    return
    <json:array xmlns:json="http://www.json.org">
    {
        let $attributes := 
            ( 
                <class>{$hds/className/@value/string()}</class>
            ,   <backgroundColor>{$hds/backgroundColor/@value/string()}</backgroundColor>
            ,   <textColor>{$hds/textColor/@value/string()}</textColor>
            ,   <editable>{$hds/editable/@value/string()}</editable>
            )
        for $d in (0 to $nofd)
        let $date  := $s + xs:dayTimeDuration('P1D')*$d
        let $hde := ice:match-rrules($date, $events)
        return
            r-hd:fc-eventJSON($hde, $date, $attributes)
    }
    </json:array>
};

declare %private function r-hd:fc-eventJSON($e as item()?, $date as xs:date, $attributes as item()*) as item()?
{
    if (empty($e)) then
        ()
    else
        <json:value xmlns:json="http://www.json.org" json:array="true">
            <id>{$e/name/@value/string()}</id>
            <title>{$e/description/@value/string()}</title>
            <type>{$e/type/@value/string()}</type>
            <start>{dateTime($date, xs:time(xs:dateTime($e/start/@value)))}</start>
            {if ($e/type/@value='traditional') then
                <end>{dateTime($date, xs:time(xs:dateTime($e/end/@value)))}</end>
             else ()
            }
            {$attributes/*[not(
                        self::editable
                    or  self::allDay)
                ]}
            <editable json:literal='true'>false</editable>
            <allDay json:literal='true'>true</allDay>
        </json:value>
};
