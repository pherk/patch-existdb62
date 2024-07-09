xquery version "3.1";

module namespace wkheatmap    = "http://enahar.org/exist/apps/enahar/wkheatmap";

import module namespace xqtime = "http://enahar.org/lib/xqtime";

import module namespace wkload    = "http://enahar.org/exist/apps/enahar/wkload"    at "../wkload/wkload.xqm";
import module namespace rawslot  = "http://enahar.org/exist/apps/enahar/rawslot"   at "../wksearch/rawslot.xqm";

import module namespace r-sched = "http://enahar.org/exist/restxq/enahar/schedules" at "../schedule/schedule-routes.xqm";


declare namespace fhir = "http://hl7.org/fhir";


declare function wkheatmap:wkslotsPerDayXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $arefs as xs:string+
        , $group as xs:string*
        , $schedule as xs:string*
        , $tmin as xs:dateTime
        , $tmax as xs:dateTime
        , $status as xs:string*
        ) as element(workload)
{
    let $schedules := r-sched:scheduledEventsXML($realm, $loguid, $lognam, $actor, $group, $schedule, $start, $end, "false" )
let $lll := util:log-app("DEBUG","nabu",count($schedules//tp))


    let $workload  := wkload:workloadPerDayXML($realm, $loguid, $lognam, $actors, $group,"",$tmin, $tmax, ('tentative','planned'))
    let $aref := concat("metis/practitioners/",$actor)
    let $rawSlots := rawslot:rawSlots($aref, $group, $schedule, $start, $end, $schedules, $workload)
let $lll := util:log-app("DEBUG","nabu",count($rawSlots//tp))  

    let $nofd  := xs:integer(floor(($tmax - $tmin) div xs:dayTimeDuration('P1D')))
    let $lll := util:log-app("DEBUG","nabu",concat('Workload for ', $actor, ': ', count($workload//tp)))
return
    <json:value xmlns:json="http://www.json.org">
        <title>workload and free slot score</title>
        <actor>{$actor}</actor>
        <group>{$group}</group>
        <schedule>{$schedule}</schedule>
        <data>
        {
            for $d in (0 to $nofd)
            let $start := xs:date($tmin) + xs:dayTimeDuration('P1D') * ($d)

            let $events := $workload/day[date/@value=$start]/schedule
            let $wkload := if ($events)
                    then sum($events/nOfEvents/@value)
                    else 0
            let $amb := $rawSlots/day[date/@value=$start]/schedule[starts-with(@ref,"enahar/schedules/amb")]
            let $slots := if ($amb)
                    then for $g in $amb/actor/tp
                         return
                            xqtime:slice($g, 60)
                    else ()
            return
                (:~
                 : wkload = no of encounters
                 : ftscore = no of free slots
                 : TBD : scaled for group
                 :)
                <json:value xmlns:json="http://www.json.org" json:array="true">
                    <date>{$start}</date>
                    <wkload>{$wkload}</wkload>
                    <fs>{count($slots)}</fs>
                </json:value>
        }
        </data>
    </json:value>
};