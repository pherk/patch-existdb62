xquery version "3.1";
(: ~
 : rawslot for cal-heatmap
 : 
 : @author Peter Herkenrath
 : @version 0.9
 : 2018-07-15
 : 
 : 
 :)
module namespace rawslot = "http://enahar.org/exist/apps/enahar/rawslot";

import module namespace xqtime = "http://enahar.org/lib/xqtime";

declare namespace fhir= "http://hl7.org/fhir";

(:~
 : rawSlots 
 : extracts free slots from precomputed schedules and workloads within range
 : 
 : @param $actor
 : @param $group
 : @param $schedule
 : @param $rangeStart
 : @param $rangeEnd
 : @param $schedules
 : @param $workload 
 : 
 : @return slots
 :)
declare function rawslot:rawSlots(
          $actor, $group, $schedule
        , $rangeStart as xs:dateTime, $rangeEnd as xs:dateTime
        , $schedules
        , $workload
        ) as element(slots)
{
    let $nofd  := xs:integer(floor(($rangeEnd - $rangeStart) div xs:dayTimeDuration('P1D')))
    let $sls:=  for $d in (0 to $nofd)
            let $date  := xs:date($rangeStart) + xs:dayTimeDuration('P1D')*$d
            let $slices := (: matches also empty actor or schedule :)
                let $ds := $schedules//day[date/@value=$date]
                let $ss := if ($schedule="")
                    then distinct-values($ds/schedule[@ref!='worktime']/@ref)
                    else distinct-values($ds/schedule[matches(@ref,$schedule)]/@ref)
                let $as := if ($schedule="")
                    then distinct-values($ds/schedule[@ref!='worktime']/actor[matches(@ref,$actor)]/@ref)
                    else distinct-values($ds/schedule[matches(@ref,$schedule)]/actor[matches(@ref,$actor)]/@ref)
                for $sref in $ss
                let $dschedule := $ds/schedule[@ref=$sref]
                let $sdisp := $dschedule/@display/string()
                return
                <schedule ref="{$sref}" display="{$sdisp}">
                {
                    for $aref in $as
                    let $adisp := $dschedule/actor[@ref=$aref]/@display/string()
                    return
                    <actor ref="{$aref}" display="{$adisp}">
                    {
                    let $range := $ds/schedule[matches(@ref,$sref)]/actor[matches(@ref,$aref)]/tp
                    let $wkldtps := $workload//day[date/@value=$date]/schedule/actor[matches(@ref,$aref)]/tp
                    for $r in $range
                        let $gaps := xqtime:gaps($r, $wkldtps)
                        return
                            $gaps
                    }
                    </actor>
                }
                </schedule>
            return
                if (count($slices//tp)>0)
                then
                    <day>
                        <date value="{$date}"/>
                        { $slices }
                    </day>
                else ()
    return
        <slots>
        {
            $sls
        }
        </slots>
};
