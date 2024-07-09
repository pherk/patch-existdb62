xquery version "3.1";

module namespace wksimple = "http://enahar.org/exist/apps/enahar/wksimple";


import module namespace slot      = "http://enahar.org/exist/apps/enahar/slot"   at "../wksearch/slot.xqm";
import module namespace wkload    = "http://enahar.org/exist/apps/enahar/wkload" at "../wkload/wkload.xqm";

import module namespace r-sched = "http://enahar.org/exist/restxq/enahar/schedules" at "../schedule/schedule-routes.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"
                   at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";


declare namespace fhir = "http://hl7.org/fhir";


(:~
 : searchSimpleTimePeriod
 : gets free slots for single detail order
 : 1. get schedules
 : 2. get workload
 : 3. put it together, i.e. subtract workload from schedule
 : 
 : @param $details
 : @param $rangeStart
 : @param $rangeEnd
 : 
 : @return slots
 :)
declare function wksimple:searchSimpleTimePeriod(
          $detail as element(fhir:detail)
        , $period as element(period)
        , $params as map(*)
        ) as element(slots)
{
    let $rangeStart := xs:dateTime($period/start)
    let $rangeEnd   := xs:dateTime($period/end)
    let $fillSpecial := wksimple:shouldFillSpecialAmb($params,$rangeStart,$rangeEnd)
    let $lll := util:log-app('TRACE','apps.eNahar',concat('search simpleTimePeriod: ',$rangeStart,'-',$rangeEnd))
    let $lll := util:log-app('TRACE','apps.eNahar',concat('fillSpecialAmb: ',$fillSpecial))
    let $aref := $detail/fhir:actor/fhir:reference/@value
    let $actor:= if ($aref="") then "" else substring($aref, 21)
    let $group := $detail/fhir:actor/fhir:role/@value/string()
    let $schedule := if ($detail/fhir:schedule/fhir:reference/@value != "")
        then substring($detail/fhir:schedule/fhir:reference/@value, 18)
        else ""
    let $lll := util:log-app('TRACE', 'apps.eNahar', string-join(($actor,$group,$schedule),':')) 
    let $schedules := r-sched:scheduledEventsXML($params?realm, $params?loguid, $params?lognam, $actor, $group, $schedule, $rangeStart, $rangeEnd, xs:string($fillSpecial))
    let $schedule := if ($fillSpecial)
        then ""
        else $schedule
    let $lll := util:log-app('TRACE', 'apps.eNahar', $schedules)

    let $actors := if ($actor='')
            then r-practrole:users('', $group,'','ref')
            else r-practrole:userByID($actor,'ref')
(: 
    let $lll := util:log-app('TRACE','apps.eNahar',($group,$actor))
    let $lll := util:log-app('TRACE','apps.eNahar',$actors)
:)
    let $arefs := $actors//fhir:reference/@value/string()
    let $workload  := wkload:workloadPerDayXML($params?realm, $params?loguid, $params?lognam, $arefs, $group,"",$rangeStart, $rangeEnd, ('tentative','planned'))
(: 
    let $lll := util:log-app('TRACE', 'apps.eNahar', $workload) 
:)
    return
        (: actor is "" or id :)
        slot:slots($detail, $actor, $group, $schedule, $rangeStart, $rangeEnd, $schedules, $workload, $params?mode)
};

declare %private function wksimple:shouldFillSpecialAmb($ps as map(), $s as xs:dateTime, $e as xs:dateTime) as xs:boolean
{
    if ($ps?inclSpecialAmb)
    then $ps?now1 <= $e  and $s <= $ps?now1
    else false()
};