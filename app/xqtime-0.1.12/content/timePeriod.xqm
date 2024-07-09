xquery version "3.0";
(: ~
 : time period
 : 
 : @author Peter Herkenrath
 : @version 0.2.1
 : 2016-01-23
 : 
 : TODO: handle indefinite periods, e.g. without defined start or end
 :)
module namespace xqtime ="http://enahar.org/lib/xqtime";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace allen = "http://enahar.org/lib/allen";
import module namespace tlm   = "http://enahar.org/lib/tlm";

(:~
 : Time Period
 : properties
 :     start
 :     end
 :     duration
 :     hasStart
 :     hasEnd
 :     isAnytime
 :     isMoment
 : start, end, and duration of the time period
 : hasStart is true if the Start time is defined
 : hasEnd is true if the End time is defined
 : isAnytime is true if neither the Start nor the End times are defined
 : isMoment is true if Start and End hold identical values
 :)

declare variable $xqtime:minValue := "1970-01-01T00:00:00";
declare variable $xqtime:maxValue := "2021-04-01T23:59:59";

declare function xqtime:new($start as xs:dateTime, $end as xs:dateTime, $ref as xs:string*) as item()
{
    if ($start <= $end)
    then 
        if ($ref)
        then <tp start="{$start}" end="{$end}" ref="{$ref}"/>
        else <tp start="{$start}" end="{$end}" ref=""/>
    else
        error(xs:QName("xqtime:error"), "invalid time period")
};

(:~
 : start
 : get start of first period
 : 
 : @param $tps sequence of tp
 : 
 : @return dateTime
 :)
declare function xqtime:start($tps as element(tp)*) as xs:dateTime
{
    if (count($tps)=1)
    then xs:dateTime($tps/@start)
    else xs:dateTime(xxpath:lowest(function($tp){xs:dateTime($tp/@start)},$tps)/@start)
};

(:~
 : end
 : get end of last period
 : 
 : @param $tps sequence of tp
 : 
 : @return dateTime
 :)
declare function xqtime:end($tps as element(tp)*) as xs:dateTime
{
    if (count($tps)=1)
    then xs:dateTime($tps/@end)
    else xs:dateTime(xxpath:highest(function($tp){xs:dateTime($tp/@end)},$tps)/@end)
};


(:~
 : hasInside
 : 
 : @param $tp     time period
 : @param $moment 
 :
 : @return boolean
 :)
declare function xqtime:hasInside($tp as element(tp), $moment as xs:dateTime) as xs:boolean
{
    ($moment > $tp/@start and $moment < $tp/@end)
};

(:~
 : intersectsWith
 :
 : @param $tp1  time period
 : @param $tp2  time period to be tested
 :
 : @return boolean
 :)
declare function xqtime:intersectsWith($tp1 as element(tp), $tp2 as element(tp)) as xs:boolean
{
    xqtime:hasInside($tp1, $tp2/@start) or
    xqtime:hasInside($tp1, $tp2/@end) or
    ($tp2/@start <= $tp1/@start and $tp2/@end >= $tp1/@end)
};

(:~
 : slice
 : divides time period in subintervals with given duration
 : 
 : @param $tp     timeperiod (tp)
 : @param $durint duration in minutes (xs:integer)
 : 
 : return element(tp)*
 :)
declare function xqtime:slice($tp as element(tp), $durint as xs:integer) as element(tp)*
{
    let $duration := (xs:dateTime($tp/@end) - xs:dateTime($tp/@start)) div xs:dayTimeDuration("PT1M")
    let $dur  := xs:dayTimeDuration("PT1M") * $durint
    let $ns   := $duration idiv $durint
    let $start := xs:dateTime($tp/@start)
    return
        for $i in (1 to $ns)
        let $tps := $start + ($dur * ($i - 1))
        return
            <tp start="{$tps}" end="{$tps + $dur}"/>
(:
    ,   if (($duration mod $durint) > 0)
        then <tp start="{$start + ($dur*$ns)}" end="{$tp/@end}"/>
        else ()
    )
:)
};

(:~
 : overlap
 : true if tp overlaps all $os

 : @param $os
 : @param $tp
 : @return boolean
 :)
declare function xqtime:overlap($os as element(tp)+, $tp as element(tp)) as xs:boolean
{
    count($os) = count($os[allen:relation($tp,.)=("e","s","d","f","o","S","D","F","O")])

};

(:~
 : combinePeriods
 : combine time periods if adjacent
 : 
 : @param $tlms  sequence of tlm
 : 
 : @return sequence of tp
 :)
declare function xqtime:combinePeriods($tps as element(tp)*) as element(tp)*
{
    reverse(fold-left(tail($tps), head($tps), function($acc, $tp) {
        let $tail := tail($acc)
        let $head := head($acc)
        return
            if (allen:contains($head, $tp))
            then $acc
            else if ($head/@start <= $tp/@start and $tp/@start <= $head/@end)
            then (xqtime:new($head/@start,$tp/@end, ()), $tail)
            else ($tp,$acc)
    }))
};

(:~
 : intersectPeriods
 : intersect sequence of time periods (sorted by @start)
 : 
 : @param $tps  sequence of tp
 : 
 : @return sequence of tp
 :)
declare function xqtime:intersectPeriods($tps as element(tp)*) as element(tp)*
{
    let $list := fold-left(tail($tps), head($tps), function($old, $tp) {
        let $tail := tail($old)
        let $head := head($old)
        let $new := if ($head/@ref=("","f"))
            then $tail
            else $old
        let $allen := allen:relation($head, $tp)
 let $lll := util:log-app('TRACE','apps.nabu',($old, $tp, $allen)) 
        return
            switch ($allen)
            case "p" return (xqtime:new($tp/@start,$tp/@end, "f"), $new)
            case "m" return (xqtime:new($tp/@start,$tp/@end, "f"), $new)
            case "o" return (xqtime:new($head/@end,$tp/@end,'f'),xqtime:new($tp/@start,$head/@end, "i"), $tail)
            case "F" return (xqtime:new($tp/@start,$head/@end, "i"), $tail)
            case "D" return (xqtime:new($tp/@end,$head/@end,"f"), xqtime:new($tp/@start,$tp/@end, "i"), $tail)
            case "s" return (xqtime:new($head/@end,$tp/@end,'f'),xqtime:new($head/@start,$head/@end, "i"), $tail)
            case "e" return (xqtime:new($head/@start,$head/@end, "i"), $tail)
            case "S" return (xqtime:new($tp/@end,$head/@end,"f"), xqtime:new($tp/@start,$tp/@end, "i"), $tail)
            case "O" return (xqtime:new($head/@start,$tp/@end, "i"), $tail)
            (: should not happen if list sorted :)
            case "d" return (xqtime:new($head/@start,$head/@end, "i"), $tail)
            case "f" return (xqtime:new($head/@start,$tp/@end, "i"), $tail)
            case "M" return $tail
            case "P" return $tail
            default return $tail
    })
    return
        if (head($list)/@ref="i")
        then reverse($list)
        else reverse(tail($list))
};
(: 
-- Given a list of intervals, select those which overlap with at least one other inteval in the set.
import Data.List

type Interval = (Integer, Integer)

overlap (a1,b1)(a2,b2) | b1 < a2 = False
                       | b2 < a1 = False
                       | otherwise = True

mergeIntervals (a1,b1)(a2,b2) = (min a1 a2, max b1 b2)

sortIntervals::[Interval]->[Interval]
sortIntervals = sortBy (\(a1,b1)(a2,b2)->(compare a1 a2))

sortedDifference::[Interval]->[Interval]->[Interval]
sortedDifference [] _ = []
sortedDifference x [] = x
sortedDifference (x:xs)(y:ys) | x == y = sortedDifference xs ys
                              | x < y  = x:(sortedDifference xs (y:ys))
                              | y < x  = sortedDifference (x:xs) ys

groupIntervals::[Interval]->[Interval]
groupIntervals = foldr couldCombine []
  where couldCombine next [] = [next]
        couldCombine next (x:xs) | overlap next x = (mergeIntervals x next):xs
                                 | otherwise = next:x:xs

findOverlapped::[Interval]->[Interval]
findOverlapped intervals = sortedDifference sorted (groupIntervals sorted)
  where sorted = sortIntervals intervals

sample = [(1,3),(12,14),(2,4),(13,15),(5,10)]
:)

(:~
 : subtractPeriods
 : compute valid gaps for tp sequence
 : 
 : @param $tps1  sequence of tp
 : @param $tps2  sequence of tp
 : 
 : @return sequence of tp
 :)
declare function xqtime:subtractPeriods($tps1 as element(tp)*, $tps2 as element(tp)*) as element(tp)*
{
    if (count($tps1)=0)
    then ()
    else if (count($tps2)=0)
    then $tps1 (: evtl combined :)
    else
        (: combine periods :)
        let $tps1c := xqtime:combinePeriods($tps1)
        let $tps2c := xqtime:combinePeriods($tps2)
	(: invert subtracting periods :)
	let $limits := xqtime:new(xqtime:start($tps1c), xqtime:end($tps1c), ())
	let $gaps   := xqtime:gaps( $limits, $tps2c)
(:  let $lll := util:log-system-out($gaps) :)
        let $sorted := for $t in ($tps1c, $gaps)
	    order by $t/@start/string()
	    return
		$t
        return
	    xqtime:intersectPeriods( $sorted )
};

(:~
 : gaps
 : compute gaps for tp sequence within range
 : 
 : @param $range  tp
 : @param $tps  sequence of tp
 : 
 : @return sequence of tp
 :)
declare function xqtime:gaps($range as element(tp), $tps as element(tp)*) as element(tp)*
{
    let $iw := filter($tps, function($tp) {
                xqtime:intersectsWith($tp, $range)
            })
    return
        if (count($iw) > 0)
        then tlm:gaps( $range, tlm:tp2tlm($iw) )
        else $range
};



