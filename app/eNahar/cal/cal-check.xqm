xquery version "3.0";
(: 
module namespace cc = "http://enahar.org/exist/apps/enahar/cc";
:)
import module namespace config  = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";

import module namespace ical    = "http://enahar.org/lib/ical";
import module namespace ice     = "http://enahar.org/lib/ice";
import module namespace r-ical  = "http://enahar.org/exist/restxq/enahar/icals"  at "../cal/cal-routes.xqm";
import module namespace r-practrole  = "http://enahar.org/exist/restxq/metis/practrole" 
                                            at "/db/apps/metis/PractitionerRole/practitionerrole-routes.xqm";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

declare variable $local:ruhepause := 
    map {
        "0-6": 0,
        "6-9": 30,
        "9-" : 45
    };


declare function local:check($family, $given)
{
    let $role  := "kikl-spz"
    let $loguid := "u-admin"
    let $lognam := "admin"
    let $realm := "kikl-spz"
    let $bundle := r-practrole:practRoles("1","*",$family, '', '', $role,'','','true')
    return
    <dia>
    {
        for $u in $bundle/fhir:entry/fhir:resource/fhir:PractitionerRole
        let $uid := $u/fhir:id/@value/string()
        let $cals := r-ical:cals($realm, $loguid, $lognam, '1', '*', $uid, '', '')
        let $unam := $u/fhir:practitioner/fhir:display/@value/string()
        return

            if ($cals//*:count=0)
            then    <cc unam="{$unam}" uref="{$uid}">no calendar</cc>
            else if ($cals//*:count=1)
            then    local:check($cals)
            else    <cc unam="{$unam}" uref="{$uid}">{concat($cals//*:count, " calendars.")}</cc>
    }
    </dia>
};

declare function local:check($cals as item()*)
{
    
    for $c in $cals/*:cal
    return
        local:checkOne($c)
};

(:~
 : check-one
 : checks a caelandar
 : - reular worktime
 : - schedules
 : - mettings
 : 
 : @param $cal
 : 
 : @return <cc/>
 :)
declare function local:checkOne($c as item()) 
{
    let $owner := $c/owner/display/@value/string()
    return
        <cc owner="{$owner}" uref="{substring-after($c/owner/reference/@value,'metis/practitioners/')}" xml:id="{$c/@xml:id/string()}">
        {
            (   local:worktime($c)
            ,   local:services($c)
            )
        }
        </cc>
};

(:~
 : worktime
 : analyzes worktime
 : 
 : @param $cal
 : 
 : @return <worktime/>
 :)
declare function local:worktime($cal as item())
{
    let $wk := $cal/*:schedule[./*:global/*:type/@value='worktime']
    return
    <worktime>
    {
        if ($wk)
        then 
            let $even := local:enumPeriodWk($wk, "2017-11-09", "2017-11-13")
            let $odd  := local:enumPeriodWk($wk, "2017-11-16", "2017-11-20")
            return
            (
                for $day in ($even,$odd)
                return
                    if ($day/ups)
                    then $day
                    else ()
            ,   <hours>{sum(($even/wk, $odd/wk)) div 120}</hours>
            )
        else <ups>no worktime</ups>
    }
    </worktime>
};

(:~
 : services
 : analyzes services
 : 
 : @param $cal
 : 
 : @return <services/>
 :)
declare function local:services($cal as item())
{
    let $services := $cal/*:schedule[./*:global/*:type/@value='service']
    return
        if ($services)
        then 
            for $srv in $services
            let $even := local:enumPeriodSrv($srv, "2015-11-09", "2015-11-13")
            let $odd  := local:enumPeriodSrv($srv, "2015-11-16", "2015-11-20")
            return
            <service ref="{substring-after($srv/global/reference/@value,'enahar/schedules/')}" name="{$srv/global/display/@value/string()}">
            {
            (
                for $day in ($even,$odd)
                return
                    if ($day/ups)
                    then $day
                    else ()
            ,   <hours>{sum(($even/wk, $odd/wk)) div 120}</hours>
            )
            }
            </service>
        else <ups>no services</ups>
};

declare function local:less($a as xs:string, $b as xs:dateTime)
{
  if ($a="")
  then true()
  else xs:dateTime($a) <= $b
};
declare function local:greater($a as xs:string, $b as xs:dateTime)
{
  if ($a="")
  then true()
  else xs:dateTime($a) > $b
};

declare function local:filterValidAgendas($agendas as item()*, $start as xs:dateTime, $end as xs:dateTime) as item()*
{
    $agendas[local:less(period/start/@value/string(),$start)][local:greater(period/end/@value/string(),$end)]
};

declare function local:filterValidAgendas($agendas as item()*, $date as xs:date) as item()?
{
let $dt := xs:dateTime(concat($date,"T08:00:00"))
let $res := $agendas[local:less(period/start/@value/string(),$dt)][local:greater(period/end/@value/string(),$dt)]
return
    if (count($res)>1)
    then error(xs:QName("XPTY0004"), 'eNahar: overlapping agenda!')
    else $res
};

declare function local:enumPeriodWk($schedule, $start as xs:date, $end as xs:date)
{
    let $nofd  := 4
    (: enumerate days in period :)
    for $d in (0 to $nofd)
    let $date  := $start + xs:dayTimeDuration('P1D')*$d
    return
        <day date="{$date}" wkday="{ical:day-of-week($date)}">
        {
                let $agendas := local:filterValidAgendas($schedule/agenda,$start,$end)
                return
                    if (count($agendas)>0)
                    then
                        try {
                            let $shifts    := local:filterValidAgendas($schedule/agenda,$date)/event
                            let $rawEvents := (ice:match-rdates($date,$shifts),ice:match-rrules($date, $shifts))
                            let $wktime    := for $e in $rawEvents
                                return
                                    local:subtractPause(local:duration($e))
                            return
                                if (count($wktime)>1)
                                then <ups>more than one worktime shift per day?</ups>
                                else if (count($wktime)=1)
                                then <wk>{$wktime}</wk>
                                else <wk>0</wk>
                        } catch * {
                            <ups>overlapping agenda!</ups>            
                        }
                    else <wk>0</wk>
        }
        </day>

};
declare function local:enumPeriodSrv($schedule, $start as xs:date, $end as xs:date)
{
    let $nofd  := 4
    (: enumerate days in period :)
    for $d in (0 to $nofd)
    let $date  := $start + xs:dayTimeDuration('P1D')*$d
    return
        <day date="{$date}" wkday="{ical:day-of-week($date)}">
        {
                let $agendas := local:filterValidAgendas($schedule/agenda,$start,$end)
                return
                    if (count($agendas)>0)
                    then
                        try {
                            let $shifts    := local:filterValidAgendas($schedule/agenda,$date)/event
                            let $rawEvents := (ice:match-rdates($date,$shifts),ice:match-rrules($date, $shifts))
                            let $wktime    := for $e in $rawEvents
                                return
                                    local:subtractPause(local:duration($e))
                            return
                                if (count($wktime)>0)
                                then <wk>{sum($wktime)}</wk>
                                else <wk>0</wk>
                        } catch * {
                            <ups>{concat($schedule/global/display/@value,': overlapping agenda!')}</ups>            
                        }
                    else <wk>0</wk>
        }
        </day>

};

declare function local:duration($event as item()*) as xs:integer
{
    if ($event)
    then (xs:time($event/end/@value) - xs:time($event/start/@value)) div xs:dayTimeDuration('PT1M')
    else 0 
};

declare function local:subtractPause($dur as xs:integer) as xs:integer
{
    if ($dur <= 360)
    then $dur
    else if ($dur <= 540)
    then $dur - 30
    else $dur - 45
};


local:check('Fazeli', 'Walid')