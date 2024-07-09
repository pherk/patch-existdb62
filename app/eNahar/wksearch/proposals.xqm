xquery version "3.1";
(: 
 : proposals
 :)
module namespace proposals = "http://enahar.org/exist/eNahar/proposals";

import module namespace math = "http://exist-db.org/xquery/math";

import module namespace slot-util = "http://enahar.org/exist/apps/enahar/slot-util" at "../wksearch/slot-util.xqm";

declare namespace fhir = "http://hl7.org/fhir";

declare variable $proposals:noPropMax    := 15;

declare function proposals:zipProposals(
          $sameDays as element(day)*
        , $simpleSlots as element(slots)*
        , $order as element(fhir:Order)
        , $cart as element(cart)
        )
{
        if ($cart/sameday)
        then
            proposals:zipProposalsCombi($cart, $order, $sameDays, $simpleSlots)
        else
            proposals:zipProposalsSimple($cart, $order, $simpleSlots)
};

declare %private function proposals:zipProposalsCombi(
          $cart
        , $order as element(fhir:Order)
        , $sameDays as element(day)*
        , $otherSlots
        ) as item()*
{
    let $np := if (count($sameDays) > $proposals:noPropMax)
        then $proposals:noPropMax
        else count($sameDays)
    let $dids := $order//fhir:detail[fhir:status[@value=('active','tentative','accepted')]]/@id/string()
    let $props := for $pid in (1 to $np) (: enumerate days with slots :)
            let $day := $sameDays[$pid]
            return
                <proposal id="{$pid}">
                {
                    for $did in $dids
                    return
                        if ($did = $cart/sameday/id)
                        then 
                            head($day/zip/detail[@id=$did])
                        else if ($did = $cart/simple/@id)
                        then 
                            proposals:selectOne($otherSlots,$did,$pid)
                        else
                            <detail id="{$did}">
                                <notprocessed/>
                                <schedule ref="" display="--"/>
                                <actor ref="" display="--"/>
                                <tp start="" end=""/>
                                <display value="not in cart"/>
                            </detail>
                }
                    <acq value="open"/>
                </proposal>
    return
        if (count($props) > 0)
        then $props
        else 
              <error>kein Kombitermin innerhalb {$cart/rtp/duration/string()} Tagen</error>
};

declare %private function proposals:flattenSlots($slots)
{
    for $sched in $os/day/schedule
    for $actor in $sched/actor
    order by math:random()
    return
        $actor/tp
};

declare %private function proposals:zipProposalsSimple(
          $cart
        , $order as element(fhir:Order)
        , $otherSlots
        ) as item()*
{
    let $na := count($otherSlots//actor)
    let $np := if (count($otherSlots/day//tp) > $proposals:noPropMax)
        then $proposals:noPropMax
        else count($otherSlots/day//tp)
    let $dids := $order//fhir:detail[fhir:status[@value=('active','tentative','accepted')]]/@id/string()
    let $props := for $pid in (1 to $np)
            return
            <proposal id="{$pid}">
            {
                for $did in $dids
                return
                    if ($did = $cart/simple/@id)
                    then 
                        proposals:selectOne($otherSlots,$did, $pid)
                    else
                        <detail id="{$did}">
                            <notprocessed/>
                            <schedule ref="" display="--"/>
                            <actor ref="" display="--"/>
                            <tp start="" end=""/>
                            <display value="not in cart"/>
                        </detail>
            }
                <acq value="open"/>
            </proposal>
    return
        if (count($props) > 0)
        then $props
        else 
              <error>kein Termin innerhalb {$cart/rtp/duration/string()} Tagen</error>
};

declare %private function proposals:selectOne($slots, $did , $nth)
{
    let $details := proposals:enumSlots($slots[detail/@id=$did],$did, $nth)
    return
        if (count($details) >= $nth)
        then
            let $d := $details[$nth]
            return
                <detail id="{$d/@id/string()}">
                    { $d/* }
                    { slot-util:display($d/tp) }
                </detail>
        else 
            <detail id="{$did}">
                <notprocessed/>
                <schedule ref="" display="--"/>
                <actor ref="" display="--"/>
                <tp start="" end=""/>
                <display value="kein Vorschlag"/>
            </detail>
};

declare %private function proposals:enumSlots($slots,$did, $nth)
{
    for $day in $slots/day
    return
        for $sched in $day/schedule
        for $actor in $sched/actor
        return
            for $tp in $actor/tp
            order by $tp/@start/string()
            return
            <detail id="{$did}">
                <schedule ref="{$sched/@ref/string()}" display="{$sched/@display/string()}"/>
                <actor ref="{$actor/@ref/string()}" display="{$actor/@display/string()}"/>
                { $tp }
            </detail>
};

declare function local:process($seq) {
  if (exists($seq) and $seq[1] != 0) then
    ($seq[1], local:process(subsequence($seq, 2)))
  else
    ()
};
