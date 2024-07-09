xquery version "3.0";
(: ~
 : time line moments
 : 
 : @author Peter Herkenrath
 : @version 0.1
 : 2015-07-03
 : 
 : 
 :)
module namespace tlm = "http://enahar.org/lib/tlm";

(:~
 : TimeLineMoment
 : sequence of start and end points of time periods
 : use to calculate a balance of intersecting/overlapping periods
 : 
 : properties
 :     startCount
 :     endCount
 :     moment
 :)

declare function tlm:new($moment as xs:dateTime) as element(tlm)
{
    <tlm startCount="0" endCount="0" moment="{$moment}"/> 
};

declare function tlm:balance($tlm as element(tlm)) as xs:integer
{
    xs:integer($tlm/@startCount) - xs:integer($tlm/@endCount)
};

declare function tlm:isEmpty($tlm as element(tlm)) as xs:integer
{
    $tlm/@startCount='0' and $tlm/@endCount='0'
};

declare function tlm:addStart($tlm as element(tlm)) as item()
{
    let $new := xs:integer($tlm/@startCount) + 1
    return
        <tlm startCount="{$new}" endCount="{$tlm/@endCount/string()}" moment="{$tlm/@moment/string()}"/>
};


declare function tlm:subStart($tlm) as item()
{
    let $new := xs:integer($tlm/@startCount) - 1
    return
        <tlm startCount="{$new}" endCount="{$tlm/@endCount/string()}" moment="{$tlm/@moment/string()}"/>
};

declare function tlm:addEnd($tlm) as item()
{
    let $new := xs:integer($tlm/@endCount) + 1
    return
        <tlm startCount="{$tlm/@startCount/string()}" endCount="{$new}" moment="{$tlm/@moment/string()}"/>
};


declare function tlm:subEnd($tlm) as item()
{
    let $new := xs:integer($tlm/@endCount) - 1
    return
        <tlm startCount="{$tlm/@startCount/string()}" endCount="{$new}" moment="{$tlm/@moment/string()}"/>
};


declare function tlm:insertStart($tlms as item()*, $m as xs:dateTime) as item()*
{
    let $tlm := $tlms[@moment=$m]
    return
        if ($tlm)
        then
            for $tlm in $tlms  
            return
                if ($tlm/@moment=$m)
                then tlm:addStart($tlm)
                else $tlm
        else
            (
              tlm:addStart(tlm:new($m))
            , $tlms
            )
};

declare function tlm:insertEnd($tlms as item()*, $m as xs:dateTime) as item()*
{
    let $tlm := $tlms[@moment=$m]
    return
        if ($tlm)
        then
            for $tlm in $tlms  
            return
                if ($tlm/@moment=$m)
                then tlm:addEnd($tlm)
                else $tlm
        else
            (
              tlm:addEnd(tlm:new($m))
            , $tlms
            )
};


declare function tlm:insert($tlms as item()*, $tp as item()) as item()*
{
    let $tlms1 := tlm:insertStart($tlms, xs:dateTime($tp/@start/string()))
    let $tlms2 := tlm:insertEnd($tlms1,  xs:dateTime($tp/@end/string()))
    return 
        tlm:sort($tlms2)
};


declare function tlm:insertAll($tlms as element(tlm)*, $tps as element(tp)*) as element(tlm)*
{
    let $tlms2 := fn:fold-left($tps, $tlms, function ($tlms0, $tp)
        { 
            let $tlms1 := tlm:insertStart($tlms0, xs:dateTime($tp/@start/string()))
            return
                tlm:insertEnd($tlms1, xs:dateTime($tp/@end/string()))
        })
    return 
        tlm:sort($tlms2)
};

declare function tlm:sort($tlms as item()*) as item()*
{
    for $tlm in $tlms
    order by $tlm/@moment/string()
    return
        $tlm
};

declare function tlm:hasOverlaps($tlms as item()*) as xs:boolean*
{
	if ( count($tlms) > 1 )
	then
        count(fn:filter(tlm:weights($tlms), function($w){ $w > 1 })) > 0
    else false()
};

declare function tlm:hasGaps($tlms as item()*) as xs:boolean*
{
    0 = tlm:weights($tlms)
};

declare function tlm:weights($tlms as item()*) as xs:integer*
{
	fn:fold-left(tail($tlms), tlm:balance(head($tlms)), function($bals, $tlm) {
            let $bal := $bals[last()] + tlm:balance($tlm)
            return ($bals, $bal)
	    })
};

(:~
 : gaps
 : calculates gaps for time line within range
 : 
 : cave: if range falls within timeline all inner gaps will be returned
 :       can be avoided if only periods intersecting range are inserted
 : 
 : @param $range  period for which gaps are calculated
 : @param $tlms   time line moments
 : 
 : @eturn sequence of tp
 :)
declare function tlm:gaps($range, $tlms as item()*) as item()*
{
    if ( $tlms )
    then 
	let $pre :=
	    if ($range/@start < head($tlms)/@moment)
	    then
	        <tp start="{$range/@start/string()}" end="{if ($range/@end < head($tlms)/@moment) then $range/@end/string() else head($tlms)/@moment/string()}"/>
	    else ()
        let $inner := 
            for $i in index-of(reverse(tail(reverse(tlm:weights($tlms)))), 0)
	    let $gapStart := $tlms[$i]/@moment
            let $gapEnd   := $tlms[$i+1]/@moment
            return
                <tp start="{$gapStart/string()}" end="{$gapEnd/string()}"/>
	let $post :=
	    if ($range/@end > $tlms[last()]/@moment)
	    then
	        <tp start="{if ($range/@start > $tlms[last()]/@moment) then $range/@start/string() else $tlms[last()]/@moment/string()}" end="{$range/@end/string()}"/>
	    else  ()
        return
	    ($pre, $inner, $post)
    else ()
};

(:~
 : tp2tlm
 : convert tp sequence to gap sequence with all start and end points
 : 
 : @param $tps  sequence of tp
 : 
 : @return sequence of tlm
 :)
declare function tlm:tp2tlm($tps as element(tp)*) as element(tlm)*
{
    tlm:insertAll((), $tps)
};

