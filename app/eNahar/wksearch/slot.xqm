xquery version "3.0";
(: ~
 : slot
 : 
 : @author Peter Herkenrath
 : @version 0.2
 : 2016-01-15
 : 
 : 
 :)
module namespace slot = "http://enahar.org/exist/apps/enahar/slot";

import module namespace xqtime = "http://enahar.org/lib/xqtime";
import module namespace slot-util = "http://enahar.org/exist/apps/enahar/slot-util" at "../wksearch/slot-util.xqm";

declare namespace fhir= "http://hl7.org/fhir";

(:~
 : slots is an intermediate structure as a response to an order detail.
 : It holds the freetime periods per day.
 : detail
 :    reference
 : day
 :    sequence of tp
 : example:
 <slots>
    <detail id="8335930d-a6c3-42e5-a109-710abc45832f"/>
    <day>
        <date value="2016-05-17"/>
        <schedule name="enahar/schedules/fun-spz-eeg">
            <actor ref="metis/practitioners/u-eeg">
                <tp start="2016-05-17T08:00:00" end="2016-05-17T09:00:00"/>
                <tp start="2016-05-17T10:00:00" end="2016-05-17T11:00:00"/>
            </actor>
        </schedule>
    </day>
  </slots>
  <slots>
    <detail id="9335930d-a6c3-42e5-a109-710abc45832f"/>
    <day>
        <date value="2016-05-17"/>
        <schedule name="enahar/schedules/amb-spz-arzt">
            <actor ref="metis/practitioners/u-pmh">
                <tp start="2016-05-18T08:00:00" end="2016-05-18T09:00:00"/>
                <tp start="2016-05-18T09:30:00" end="2016-05-18T10:30:00"/>
                <tp start="2016-05-18T11:00:00" end="2016-05-18T12:00:00"/>
                <tp start="2016-05-18T13:00:00" end="2016-05-18T14:00:00"/>
                <tp start="2016-05-18T14:30:00" end="2016-05-18T15:30:00"/>
            </actor>
>         </schedule>
    </day>
  </slots>
 :)

(:~
 : slots
 : extracts free slots from precomputed schedules and workloads within range
 : 
 : @param $details   order detail
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
declare function slot:slots(
          $detail as element(fhir:detail)
        , $actor, $group, $schedule                   (: actor is "" or id :)
        , $rangeStart as xs:dateTime
        , $rangeEnd as xs:dateTime
        , $schedules
        , $workload
        , $mode as xs:string
        ) as element(slots)
{
    let $ll := util:log-app('TRACE','apps.eNahar', concat('generate slots in mode:', $mode))
    let $ll := util:log-app('TRACE','apps.eNahar', $schedule)
    return
        switch($mode)
        case 'parallel' return slot:parallel($detail, $actor, $group, $schedule, $rangeStart, $rangeEnd, $schedules, $workload)
        case 'pressing' return slot:pressing($detail, $actor, $group, $schedule, $rangeStart, $rangeEnd, $schedules, $workload)
        default return slot:free($detail, $actor, $group, $schedule, $rangeStart, $rangeEnd, $schedules, $workload)
};

declare %private function slot:free(
          $detail as element(fhir:detail)
        , $actor, $group, $schedule                (: actor is "" or id :)
        , $rangeStart as xs:dateTime
        , $rangeEnd as xs:dateTime
        , $schedules
        , $workload
        ) as element(slots)
{
(:~
 :  if actor is empty it will be supplied via scheduleEvents   
 :)
    let $nofd  := xs:integer(floor(($rangeEnd - $rangeStart) div xs:dayTimeDuration('P1D')))
    let $sls:=  for $d in (0 to $nofd)
            let $date  := xs:date($rangeStart) + xs:dayTimeDuration('P1D')*$d
            let $slices := (: matches also empty actor or schedule :)
                let $ds := $schedules/day[date[@value=$date]]
                let $ss := if ($schedule="")
                    then distinct-values($ds/schedule[@ref!='worktime']/@ref)
                    else distinct-values($ds/schedule[matches(@ref,$schedule)]/@ref)
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $ss)
:)
                for $sref in $ss
                let $dschedule := $ds/schedule[@ref=$sref]
                let $sdisp := $dschedule/@display/string()
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $dschedule)
:)
                let $as := distinct-values($dschedule/actor[matches(@ref,$actor)]/@ref)
                return
                    if (count($as) > 0)
                    then
                <schedule ref="{$sref}" display="{$sdisp}">
                {
                    for $aref in $as
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $aref)
:)
                    let $adisp := $dschedule/actor[@ref=$aref]/@display/string()
                    return
                    <actor ref="{$aref}" display="{$adisp}">
                    {
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $ds/schedule[@ref=$sref])
    let $ll := util:log-app('TRACE','apps.eNahar', concat($sref, ' - ', $aref))
:)
                    let $range := $ds/schedule[@ref=$sref]/actor[@ref=$aref]/tp
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $range)
:)
                    let $wkldtps := $workload/day[date/@value=$date]/schedule/actor[matches(@ref,$aref)]/tp

                    for $r in $range
                        let $gaps := xqtime:gaps($r, $wkldtps)
(: 
                        let $ll := util:log-app('TRACE','apps.eNahar', $r)
                        let $ll := util:log-app('TRACE','apps.eNahar', $gaps)
:)
                        return
                            for $g in $gaps
                                return 
                                    xqtime:slice($g, xs:integer($detail/fhir:spec/fhir:duration/@value/string()))
                    }
                    </actor>
                }
                </schedule>
                else ()
(:  
            let $ll := util:log-app('TRACE','apps.eNahar', $slices)
:)
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
            <detail id="{$detail/@id/string()}"/>
        {
            if (count($sls)>0)
            then $sls
            else 
               <error>kein passender Termin</error>
        }
        {   $workload    }
        </slots>
};

declare %private function slot:parallel(
          $detail as element(fhir:detail)
        , $actor, $group, $schedule
        , $rangeStart as xs:dateTime
        , $rangeEnd as xs:dateTime
        , $schedules
        , $workload
        ) as element(slots)
{
(:~
 :  if actor is empty it will be supplied via scheduleEvents   
 :)
    let $nofd  := xs:integer(floor(($rangeEnd - $rangeStart) div xs:dayTimeDuration('P1D')))
    let $sls:=  for $d in (0 to $nofd)
            let $date  := xs:date($rangeStart) + xs:dayTimeDuration('P1D')*$d
            let $slices := (: matches also empty actor or schedule :)
                let $ds := $schedules/day[date[@value=$date]]
                let $ss := if ($schedule="")
                    then distinct-values($ds/schedule[@ref!='worktime']/@ref)
                    else distinct-values($ds/schedule[matches(@ref,$schedule)]/@ref)
    let $ll := util:log-app('TRACE','apps.eNahar', $ss)
                for $sref in $ss
                let $dschedule := $ds/schedule[@ref=$sref]
                let $sdisp := $dschedule/@display/string()
    let $ll := util:log-app('TRACE','apps.eNahar', $dschedule)
                let $as := distinct-values($dschedule/actor[matches(@ref,$actor)]/@ref)
                return
                    if (count($as) > 0)
                    then
                <schedule ref="{$sref}" display="{$sdisp}">
                {
                    for $aref in $as
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $aref)
:)
                    let $adisp := $dschedule/actor[@ref=$aref]/@display/string()
                    return
                    <actor ref="{$aref}" display="{$adisp}">
                    {
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $ds/schedule[@ref=$sref])
    let $ll := util:log-app('TRACE','apps.eNahar', concat($sref, ' - ', $aref))
:)
                    let $range := $ds/schedule[@ref=$sref]/actor[@ref=$aref]/tp

    let $ll := util:log-app('TRACE','apps.eNahar', $range)
                    
                    let $wkldtps := $workload/day[date/@value=$date]/schedule/actor[matches(@ref,$aref)]/tp
    let $ll := util:log-app('TRACE','apps.eNahar', $wkldtps)

                    for $r in $range
                    let $gaps :=
                        if ($dschedule/timing/overbookable/@value='true')
                        then
                            slot:parallel($r, $wkldtps, $dschedule)
                        else    
                            xqtime:gaps($r, $wkldtps)
(: 
                        let $ll := util:log-app('TRACE','apps.eNahar', $r)
                        let $ll := util:log-app('TRACE','apps.eNahar', $gaps)
:)
                        return
                            for $g in $gaps
                                return 
                                    xqtime:slice($g, $detail/fhir:spec/fhir:duration/@value)
                    }
                    </actor>
                }
                </schedule>
                else ()
(:  
            let $ll := util:log-app('TRACE','apps.eNahar', $slices)
:)
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
            <detail id="{$detail/@id/string()}"/>
        {
            if (count($sls)>0)
            then $sls
            else 
               <error>kein passender Termin</error>
        }
        {   $workload    }
        </slots>
};

declare %private function slot:parallel(
          $r as element(tp)
        , $wkldtps as element(tp)*
        , $dschedule as element(schedule)
        ) as element(tp)*
{
    let $pph    := tokenize($dschedule/timing/parallel-per-hour/@value,'\+')
    let $nslph  := count($pph)
    let $sldur  := if($nslph>0)
            then 60 div $nslph
            else 60
    let $slices := xqtime:slice($r, $sldur)
    let $ll := util:log-app('TRACE','apps.eNahar', $slices)
    return
        let $filtered :=
                for $s at $pos in $slices
                let $wrapid := (($pos + 1) mod $nslph) + 1
                return
                    let $wkldPerSlice := 
                            for $tp in $wkldtps
                            return
                                if (xqtime:intersectsWith($s,$tp))
                                then $tp
                                else ()
                    let $cntPerSlice := count($wkldPerSlice)
                    let $ll := util:log-app('TRACE','apps.eNahar', $cntPerSlice)
                    let $ll := util:log-app('TRACE','apps.eNahar', string-join(($pos,$wrapid,$pph[$wrapid]),'::'))
                    return
                        if ($cntPerSlice < xs:int($pph[$wrapid]))
                        then $s
                        else ()
        let $ll := util:log-app('TRACE','apps.eNahar', $filtered)
        return
            $filtered
};

declare %private function slot:pressing(
          $detail as element(fhir:detail)
        , $actor, $group, $schedule
        , $rangeStart as xs:dateTime
        , $rangeEnd as xs:dateTime
        , $schedules
        , $workload
        ) as element(slots)
{
(:~
 :  if actor is empty it will be supplied via scheduleEvents   
 :)
    let $nofd  := xs:integer(floor(($rangeEnd - $rangeStart) div xs:dayTimeDuration('P1D')))
    let $sls:=  for $d in (0 to $nofd)
            let $date  := xs:date($rangeStart) + xs:dayTimeDuration('P1D')*$d
            let $slices := (: matches also empty actor or schedule :)
                let $ds := $schedules/day[date[@value=$date]]
                let $ss := if ($schedule="")
                    then distinct-values($ds/schedule[@ref!='worktime']/@ref)
                    else distinct-values($ds/schedule[matches(@ref,$schedule)]/@ref)
    let $ll := util:log-app('TRACE','apps.eNahar', $ss)
                for $sref in $ss
                let $dschedule := $ds/schedule[@ref=$sref]
                let $sdisp := $dschedule/@display/string()
    let $ll := util:log-app('TRACE','apps.eNahar', $dschedule)
                let $as := distinct-values($dschedule/actor[matches(@ref,$actor)]/@ref)
                return
                    if (count($as) > 0)
                    then
                <schedule ref="{$sref}" display="{$sdisp}">
                {
                    for $aref in $as
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $aref)
:)
                    let $adisp := $dschedule/actor[@ref=$aref]/@display/string()
                    return
                    <actor ref="{$aref}" display="{$adisp}">
                    {
(: 
    let $ll := util:log-app('TRACE','apps.eNahar', $ds/schedule[@ref=$sref])
    let $ll := util:log-app('TRACE','apps.eNahar', concat($sref, ' - ', $aref))
:)
                        let $range := $ds/schedule[@ref=$sref]/actor[@ref=$aref]/tp

    let $ll := util:log-app('TRACE','apps.eNahar', $range)
                    
                        let $wkldtps := $workload/day[date/@value=$date]/schedule/actor[matches(@ref,$aref)]/tp
    let $ll := util:log-app('TRACE','apps.eNahar', $wkldtps)

                        for $r in $range
                        let $gaps :=
                            if ($dschedule/timing/overbookable/@value='true')
                            then
                                slot:pressing($r,$wkldtps,$dschedule,$detail/fhir:spec/fhir:duration/@value)
                            else    
                                let $gaps0 := xqtime:gaps($r, $wkldtps)
                                return
                                    for $g in $gaps0
                                    return 
                                        xqtime:slice($g, $detail/fhir:spec/fhir:duration/@value)
 
                        let $ll := util:log-app('TRACE','apps.eNahar', $r)
                        let $ll := util:log-app('TRACE','apps.eNahar', $gaps)

                        return
                            $gaps
                    }
                    </actor>
                }
                </schedule>
                else ()
(:  
            let $ll := util:log-app('TRACE','apps.eNahar', $slices)
:)
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
            <detail id="{$detail/@id/string()}"/>
        {
            if (count($sls)>0)
            then $sls
            else 
               <error>kein passender Termin</error>
        }
        {   $workload    }
        </slots>
};

declare %private function slot:pressing(
          $r as element(tp)
        , $wkldtps as element(tp)*
        , $schedule as element(schedule)
        , $dur as xs:int
        ) as element(tp)*
{
    let $plan := count(xqtime:slice($r, $schedule/timing/exam/@value)) (: TODO ineffective :)
    let $wkldPerSlice := 
            for $tp in $wkldtps
            return
                if (xqtime:intersectsWith($r,$tp))
                then $tp
                else ()
    let $real := count($wkldPerSlice)
    let $ll := util:log-app('TRACE','apps.eNahar', $real)
    let $ll := util:log-app('TRACE','apps.eNahar', $schedule/timing/exam/@value)
        return
            if ($real < $plan)
            then slot:trySelectOneOrMore($r,$wkldPerSlice,$real, $schedule/timing/exam/@value, $dur)
            else ()
};

declare %private function slot:trySelectOneOrMore(
          $r as element(tp)
        , $wkldPerSlice as element(tp)*
        , $noccupied as xs:int
        , $default as xs:int
        , $dur as xs:int
        ) as element(tp)*
{
    if ($noccupied > 0)
    then 
        (: slot partially occupied :)
        let $gaps := xqtime:gaps($r, $wkldPerSlice)
        (: should not select last half hour of slot :)
        (: step 1: search for gaps but not in last part of slot :)
        let $gapsnl := 
                let $remgaps := slot:notlast($gaps, $r/@end)
                (: if gaps found, slice it :)
                for $rg in $remgaps
                return 
                    xqtime:slice($rg, $dur)
        let $selected :=
            if (count($gapsnl) > 0)
            then 
                $gapsnl
            else 
                let $longest := slot:longerThan($wkldPerSlice, $default)
                let $newgaps := 
                    for $long in $longest
                    return
                        xqtime:new(xs:dateTime($long/@end) - xs:dayTimeDuration('PT1M') * $dur, $long/@end, 'pressing')
                let $newgapsnl := slot:notlast($newgaps, $r/@end)
                let $ll := util:log-app('TRACE','apps.eNahar', $newgapsnl)
                return
                    $newgapsnl
        return
            $selected
    else
        (: slot empty :)
        xqtime:slice($r, $dur)
};

declare %private function slot:notlast(
          $gaps as element(tp)*
        , $limit as xs:dateTime
        ) as element(tp)*
{
    let $last := xqtime:new($limit - xs:dayTimeDuration('PT30M'), $limit, '')
    for $g in $gaps
    return
        if (xqtime:intersectsWith($g,$last))
        then ()
        else $g
};

declare %private function slot:longerThan(
          $wkld as element(tp)*
        , $limit as xs:int
        ) as element(tp)*
{
    for $tp in $wkld
    (: TODO replace with xqtime:duration :)
    let $duration := (xs:dateTime($tp/@end) - xs:dateTime($tp/@start)) div xs:dayTimeDuration("PT1M")
    order by $duration descending
    return
        if ($duration > $limit)
        then
            $tp
        else
            ()
};
