xquery version "3.0";
(: ~
 : iCalendar engine
 : matches rrule, rdate, exdate
 : 
 : @author Peter Herkenrath
 : @version Nabu 0.9
 : @since Nabu v0.6 2015-03-29
 : @date 2018-01-29
 : 
 : 
 :)
module namespace ice ="http://enahar.org/lib/ice";

import module namespace ical ="http://enahar.org/lib/ical";

(:~
 : filter events
 : 
 : @param $date
 : @param $events
 : 
 : @return events
 :)
declare function ice:match-simple($date as xs:dateTime, $events as item()* ) as item()*
{
    for $e in $events
    return
        $e[start/@value<=$date and end/@value>=$date]
};

(:~
 : filter events with rdates
 : 
 : @param $date
 : @param $events
 : 
 : @return events
 :)
declare function ice:match-rdates($date as xs:dateTime, $events as item()* ) as item()*
{
    for $e in $events
    return
        if ($e/rdate) then
            if ($e/rdate/period) then
                ice:match-rperiod($date, $e)
            else if ($e/rdate/date) then
                ice:match-rdate($date, $e)
            else ()
        else ()
};

(:~
 : filter event with rdates defined by period
 : 
 : @param $date
 : @param $event
 : 
 : @return event?
 :)
declare function ice:match-rperiod($date as xs:dateTime, $event as item()) as item()?
{
    if (ice:match-interval($date,$event/rdate/period)) then
            $event
    else ()
};

(:~
 : filter event with rdates defined by date
 : 
 : @param $date
 : @param $event
 : 
 : @return events?
 :)
declare function ice:match-rdate($date as xs:dateTime, $event as item()) as item()?
{
    for $rd in $event/rdate/date
    return
    if (xs:date($date)=xs:date($rd/@value)) then
            $event
    else ()
};

(:~
 : filter events with exdates
 : 
 : @param $date
 : @param $events*
 : 
 : @return events*
 :)
declare function ice:match-exdates($date as xs:dateTime, $events as item()* ) as item()*
{
    for $e in $events
    return
        if ($e/exdate/date) then
            ice:match-exdate($date, $e)
        else ()
};

(:~
 : filter event with exdate defined by date
 :
 : @param $date
 : @param $event
 :
 : @return events*
 :)
declare function ice:match-exdate($date as xs:dateTime, $event as item()) as item()*
{
    for $xd in $event/exdate/date
    return
        if (xs:date($date)=xs:date($xd/@value)) then
            $event
        else ()
};


declare %private function ice:match-interval($date as xs:dateTime, $period as item()) as xs:boolean
{
    let $start := xs:dateTime($period/start/@value)
    let $end   := xs:dateTime($period/end/@value)
    return
      ($date >= $start and $date <= $end)
};

declare function ice:match-rrules($date as xs:dateTime, $events as item()* ) as item()*
{
    for $e in $events[exists(rrule)]
    return
        switch ($e/rrule/freq/@value)
        case 'daily'   return ice:match-daily($date, $e)
        case 'weekly'  return ice:match-weekly($date, $e)
        case 'monthly' return ice:match-monthly($date, $e)
        case 'yearly'  return ice:match-yearly($date, $e)
        default return fn:error(fn:QName('http://www.w3.org/2005/xqt-errors', 'err:FOER0000'))
};

declare function ice:match-daily($date as xs:dateTime, $event as item()) as item()?
{
    if (ice:match-byWeekNo($date,$event/rrule/byWeekNo)) then
        if (ice:match-byDay($date,$event/rrule/byDay)) then
            $event
        else ()
    else ()
};

declare function ice:match-weekly($date as xs:dateTime, $event as item()) as item()?
{
    let $rday := $event/rrule/byDay
    return
        if (ice:match-byDay($date,$rday)) then
            $event
        else ()
};

declare function ice:match-monthly($date as xs:dateTime, $event as item()) as item()?
{
    if (true() = ice:match-byRDay($date,$event/rrule/byDay)) then
            $event
    else ()
};

declare function ice:match-yearly($date as xs:dateTime, $event as item()) as item()?
{
if ($event/rrule/byEaster) then
    if (ice:match-byEaster($date, xs:integer($event/rrule/byEaster/@value))) then
        $event
    else ()
else
    if (ice:match-byDayMonth($date, $event/start/@value)) then
        $event
    else ()
};

declare function ice:match-byDay($date as xs:dateTime, $byDay as item()?) as xs:boolean
{
if ($byDay) then
    let $dn := ical:day-of-week-shortname($date)
    return
        contains($byDay/@value,$dn)
else true()
};

declare %private function ice:match-byRDay($date as xs:dateTime, $rday as item()?) as xs:boolean*
{
    let $dn := ical:day-of-week-shortname($date)
    let $d  := day-from-date($date)
    for $rd in tokenize($rday/@value,',')
    return
        ice:match-singleRDay($date,$d,$dn,$rd)
};

declare %private function ice:match-singleRDay(
            $date as xs:dateTime,
            $d as xs:integer, $dn as xs:string, $rday as xs:string
        ) as xs:boolean
{
    let $rtoks := tokenize($rday,':')
    let $rdn := $rtoks[2]
    let $rno := xs:integer($rtoks[1])
    return
        if ($dn=$rdn) then
            if ($rno>0)
            then (($d - 1) idiv 7)=($rno - 1)            (: nth-weekday => DOW and NthDay :)
            else                                         (: nthlast-weekday :)
                let $m  := month-from-date($date)
                let $nextMonth := if($m<12) then $m+1 else 1
                let $year  := if ($m<12) then year-from-date($date) else year-from-date($date)+1
                let $dow := ical:dayname-to-dow($rdn)
                return
                    (xs:date($date) = (ical:first-weekday-of-month($year,$nextMonth,$dow) + xs:dayTimeDuration('P1D') * 7 * $rno))
        else false()
};

declare %private function ice:match-byWeekNo($date as xs:dateTime, $byWeekNo as item()?) as xs:boolean
{
    if ($byWeekNo and $byWeekNo/@value!='') then
        let $wno := ical:week-of-year($date)
        let $odd := $wno mod 2 = 1
        return
            if ($byWeekNo/@value='odd' and $odd) then
                true()
            else if ($byWeekNo/@value='even' and not($odd)) then
                true()
            else let $kws := tokenize($byWeekNo/@value,',')
                return
                    xs:string($wno) = $kws
    else true()
};


declare %private function ice:match-byEaster($date as xs:dateTime, $add as xs:integer) as xs:boolean
{
    let $easter := ical:easter(year-from-date($date))
    return
        (xs:date($date) = ($easter + xs:dayTimeDuration('P1D') * $add))
};

declare %private function ice:match-byDayMonth($date1 as xs:dateTime, $date2 as xs:dateTime) as xs:boolean
{
    (day-from-date($date1) = day-from-date($date2)  and month-from-date($date1) = month-from-date($date2))
};

