xquery version "3.1";
(: ~
 : slot utils
 : 
 : @author Peter Herkenrath
 : @version 0.9
 : @created 2018-07-15
 : 
 : 
 :)
module namespace slot-util = "http://enahar.org/exist/apps/enahar/slot-util";

import module namespace xqtime = "http://enahar.org/lib/xqtime";

declare namespace fhir= "http://hl7.org/fhir";

declare function slot-util:display($tp as element(tp)) as item()
{
    <display value="{format-dateTime($tp/@start,"[FNn,*-2] [D01].[M01].[Y01] [H01]:[m01]","de",(),())}"/>
};


(:~
 : zip
 : zips multiple appointment slots
 : all sequential (order by lfdNo) or all parallel
 : 
 : @param $sameday   structure with cart analysis
 : @param $details   order details
 : @param $slots     free time slots detail->day->schedule->actor->tp
 : 
 : @return <zip/>    zip = proposal for combining details
 :  :)
declare function slot-util:zipSameDay(
          $sameday
        , $details as element(fhir:detail)*
        , $slots as item()*
        ) as element(day)*
{
(: 
    let $lll := util:log-app('TRACE','apps.eNahar',$slots)
:)
    (: enumerate only days, for which exist common slots :)
    if ($sameday/sequential)
    then
        slot-util:inSequence($slots)
    else 
        let $lll := util:log-app('TRACE','apps.eNahar', 'zip slots parallel')
        let $nos := count($slots)
        for $date in distinct-values($slots/day/date/@value)
        where $nos=count($slots/day[date/@value=$date])
        return
            slot-util:zipDayPar($date, $details, $slots)
};

(:~
 : inSequence
 : zip appointment slots
 : order by lfdNo
 : 
 : @param $slots
 : 
 : @return <day/>   list of days with <zip/>
 :)
declare %private function slot-util:inSequence(
          $slots
        ) as element(day)*
{
        let $lll := util:log-app('TRACE','apps.eNahar', 'zip slots as sequence')
        let $ps := head($slots)
        let $pid:= $ps/detail/@id/string()
        let $os := tail($slots)
        let $nos:= count($os)
        
        for $pd in $ps/day
        let $date := $pd/date/@value
        let $od   := $os/day[date/@value=$date]
        where $nos=count($od)  (: count of further slots after prefix slot :)
        return
            let $day :=
            <day>
                {$pd/date}
                {
                    for $s in $pd/schedule
                    for $a in $s/actor
                    for $prefix in $a/tp
                    return

                        let $zip :=
                        <zip>
                            <detail id="{$pid}">
                                <schedule ref="{$s/@ref/string()}" display="{$s/@display/string()}"/>
                                <actor ref="{$a/@ref/string()}" display="{$a/@display/string()}"/>
                                {$prefix}
                                { slot-util:display($prefix) }
                            </detail>
                        {   slot-util:nextSlotInSeq(head($os), tail($os), head($od), tail($od), $prefix) }
                        </zip>
                        return
                            if (count($zip/detail)=$nos+1)
                            then $zip
                            else ()
                }
            </day>
            return
                if ($day/zip)
                then $day
                else ()
};

declare %private function slot-util:nextSlotInSeq(
          $hslot as item()*
        , $tslots
        , $hday
        , $tdays
        , $prefix as element(tp)
        ) as element(detail)*
{
    if ($hslot)
    then
    let $atmostone  :=
        for $s in $hday/schedule
        for $a in $s/actor
        let $tpseq := $a/tp[@start >= $prefix/@end][@start < (xs:dateTime($prefix/@end) + xs:dayTimeDuration("PT1H"))]
        return
            if (count($tpseq)>0)
            then
            (
                <detail id="{$hslot/detail/@id/string()}">
                    <schedule ref="{$s/@ref/string()}" display="{$s/@display/string()}"/>
                    <actor ref="{$a/@ref/string()}" display="{$a/@display/string()}"/>
                    {$tpseq[1]}
                    { slot-util:display($tpseq[1]) }
                </detail>
            ,   slot-util:nextSlotInSeq(head($tslots), tail($tslots), head($tdays), tail($tdays), $tpseq[1])
            )
            else ()
        return
            $atmostone
    else ()
};

(:~
 :  zipDayPar 
 :  zip one Day parallel
 :  
 : @param $date
 : @param $details
 : @param $slots     all slots have day with date
 : 
 : @return <day/>    list days with <zip/>
 :)
declare %private function slot-util:zipDayPar(
          $date
        , $details as element(fhir:detail)+
        , $slots as element(slots)+
        ) as element(day)?
{
    let $day := 
        <day>
            <date value="{$date}"/>
            {   
                if (count($details)>1)
                then slot-util:zipSlotsPar($date, $details, $slots)
                else slot-util:onlyone($date, $details, $slots)
            }
        </day>
    let $lll := util:log-app('TRACE','apps.eNahar',$day)
    return
        if ($day/zip)
        then $day
        else ()
};

(:~
 : zipSlotsPar
 : zip slots for single day
 : 
 : @param $date
 : @param $details
 : @param $slots
 : 
 : @return <zip/>
 : 
 : assuming head as the main event
 : needs sorting of details and slots
 :)
declare %private function slot-util:zipSlotsPar(
          $date
        , $details
        , $slots as element(slots)+
        ) as element(zip)*
{
    let $lll := util:log-app('TRACE','apps.eNahar','zipSlotsPar')
    let $lll := util:log-app('TRACE','apps.eNahar', $slots)
    let $head := head($slots)
    let $id  := $head/detail/@id/string()
    for $s in $head/day[date/@value=$date]/schedule
    for $a in $s/actor
    for $tp in $a/tp
    return
        slot-util:zipTailSlotsPar($id, $s, $a, $tp, $date, tail($slots))
};

(:~
 : zipTailSlotsPar
 : zip remaining slots after selecting leading slot
 : 
 : @param $hid   id of leading detail
 : @param $hs    schedule
 : @param $ha    actor
 : @param $htp   slot
 : @param $tail  remaining slots
 : 
 : @param <zip/>
 :)
declare %private function slot-util:zipTailSlotsPar(
          $hid
        , $hs
        , $ha
        , $htp
        , $date
        , $tail
        ) as element(zip)?
{
    let $ts := for $t in $tail
        return
            slot-util:firstOverlap($htp, $date, $t)
    let $lll := util:log-app('TRACE','apps.eNahar',$ts)
    return
        if (count($ts)=count($tail))
        then
            <zip>
                <detail id="{$hid}">
                    <schedule ref="{$hs/@ref/string()}" display="{$hs/@display/string()}"/>
                    <actor ref="{$ha/@ref/string()}" display="{$ha/@display/string()}"/>
                    {$htp}
                    { slot-util:display($htp) }
                </detail>
                { $ts }
            </zip>
        else ()
};

(:~
 : firstOverlap
 : selects tp for parallel slot
 : - fist schedules
 : - first actor
 : - first tp
 : 
 : @param $h    leading tp
 : @param $date 
 : @param $slot
 : 
 : @return <detail/>
 :)
declare %private function slot-util:firstOverlap(
          $h
        , $date
        , $slot
        ) as element(detail)?
{
    let $id := $slot/detail/@id/string()
    let $ts :=
        for $s in $slot/day[date/@value=$date]/schedule
        for $a in $s/actor
        let $first := head($a/tp[xqtime:overlap(.,$h)])
        let $lll := util:log-app('TRACE','apps.eNahar',$first)
        return
            if ($first)
            then
                <detail id="{$id}">
                    <schedule ref="{$s/@ref/string()}" display="{$s/@display/string()}"/>
                    <actor ref="{$a/@ref/string()}" display="{$a/@display/string()}"/>
                    {$first}
                    { slot-util:display($first) }
                </detail>
            else ()
    return
        head($ts)
};

(:~
 : onlyone
 : nothing to zip
 : enumerate zip for day
 : 
 : @param $date
 : @param $detail
 : @param $slot
 : 
 : @return </detail>
 :)
declare %private function slot-util:onlyone(
          $date
        , $detail
        , $slot
        ) as element(zip)
{
        let $day := $slot/day[date/@value=$date]
        for $s in $day/schedule
        for $a in $s/actor
        for $tp in $a/tp
        return
        <zip>
            <detail id="{$detail/@id/string()}">
                <schedule ref="{$s/@ref/string()}" display="{$s/@display/string()}"/>
                <actor ref="{$a/@ref/string()}" display="{$a/@display/string()}"/>
                {$tp}
                { slot-util:display($tp) }
            </detail>
        </zip>
};
