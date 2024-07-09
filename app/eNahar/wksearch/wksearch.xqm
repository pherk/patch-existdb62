xquery version "3.1";

module namespace wksearch = "http://enahar.org/exist/apps/enahar/wksearch";

import module namespace proposals = "http://enahar.org/exist/eNahar/proposals"     at "../wksearch/proposals.xqm";
import module namespace slot-util = "http://enahar.org/exist/apps/enahar/slot-util" at "../wksearch/slot-util.xqm";
import module namespace wkload    = "http://enahar.org/exist/apps/enahar/wkload"   at "../wkload/wkload.xqm";
import module namespace wksimple  = "http://enahar.org/exist/apps/enahar/wksimple" at "../wkload/wksimple.xqm";


declare namespace fhir = "http://hl7.org/fhir";

declare variable $wksearch:maxiter := 6;


declare function wksearch:searchSlots(
          $order as element(fhir:Order)+
        , $cart as element(cart)
        , $params as map(*)
        )
{
    switch($params?mode)
    case 'pressing' return wksearch:searchSlotsNormal($order, $cart, $params)
    case 'parallel' return wksearch:searchSlotsNormal($order, $cart, $params)
    case 'uptodate' return wksearch:searchSlotsUptoDate($order, $cart, $params)
    (: normal :)
    default return wksearch:searchSlotsNormal($order, $cart, $params)
};


(:~
 : searchSlotsNormal
 : organizes proposed slots for every detail in order
 :
 : @param $order
 : @param $cart
 : @return <proposals/>
 :)
declare %private function wksearch:searchSlotsNormal(
          $order as element(fhir:Order)+
        , $cart as element(cart)
        , $params as map(*)
        ) as element(proposals)
{
    let $sameDays := wksearch:searchCombiUptoDate($order, $cart, $params)
    let $otherSlots :=
        for $od in $order/fhir:detail[@id= distinct-values($cart/simple/@id)]
        return
            wksimple:searchSimpleTimePeriod($od, $cart/simple[@id=$od/@id]/period, $params)
(: 


<day>
    <date value="2016-06-23"/>
    <zip>
        <detail id="c9b1889a-2b16-4046-b345-2a4831b8e676">
            <schedule ref="enahar/schedules/amb-spz-arzt" display="Arzt"/>
            <actor ref="metis/practitioners/u-gaffgah" display="Gaffga"/>
            <tp start="2016-06-23T13:30:00" end="2016-06-23T14:30:00"/>
        </detail>
        <detail id="c9b1889a-2b16-4046-b345-2a4831b8e676">
            <schedule ref="enahar/schedules/amb-spz-arzt" display="Arzt"/>
            <actor ref="metis/practitioners/u-gaffgah" display="Gaffga"/>
            <tp start="2016-06-23T14:30:00" end="2016-06-23T15:30:00"/>
        </detail>
    </zip>
</day>
:)
    let $lll := util:log-app('TRACE', 'apps.eNahar', $sameDays)
    let $lll := util:log-app('TRACE', 'apps.eNahar', $otherSlots)
    let $info :=  $sameDays/info
    let $proposals := proposals:zipProposals($sameDays/day, $otherSlots, $order, $cart)

    let $np := count($proposals)
    return
        <proposals>
            <index>1</index>
            <count>{$np}</count>
            { $cart }
            { $proposals }
            { $info }
        </proposals>
};


(:~
 : searchSlotsUptoDate
 : organizes proposed slots for every detail in order
 :
 : @param $order
 : @param $cart
 : @return <proposals/>
 :)
declare %private function wksearch:searchSlotsUptoDate(
          $order as element(fhir:Order)+
        , $cart as element(cart)
        , $params as map(*)
        ) as element(proposals)
{
    let $sameDays := wksearch:searchCombiUptoDate($order, $cart, $params)
    let $simpleSlots := wksearch:mapSimpleUptoDate($order, $cart, $params)


    let $lll := util:log-app('TRACE', 'apps.eNahar', $sameDays)
    let $lll := util:log-app('TRACE', 'apps.eNahar', $simpleSlots)

    let $proposals :=  proposals:zipProposals($sameDays/day, $simpleSlots/slots, $order, $cart)

    let $np := count($proposals)
    let $info :=
        <info>
            { $sameDays/info/combi }
            { $simpleSlots/info/simple }
        </info>
    return
        <proposals>
            <index>1</index>
            <count>{$np}</count>
            { $cart }
            { $proposals }
            { $info }
        </proposals>
};


declare %private function wksearch:searchCombiUptoDate(
          $order as element(fhir:Order)+
        , $cart as element(cart)
        , $params as map(*)
        ) as element(samedays)
{
    if ($cart/sameday)
    then
            let $zippedDays := wksearch:searchCombiUptoDate1($order, $cart, $params)
            return
                $zippedDays
    else
        <samedays>
            <info>
                <text>keine Kombisuche</text>
            </info>
        </samedays>
};

declare %private function wksearch:searchCombiUptoDate1(
          $order as element(fhir:Order)+
        , $cart as element(cart)
        , $params as map(*)
        ) as element(samedays)
{
    let $start := $cart/sameday/period
    let $maxiter := if ($params?mode='uptodate')
        then $wksearch:maxiter
        else 1
    let $cdetails := 
            for $d in $order/fhir:detail[@id = distinct-values($cart/sameday/id)]
            order by $d/fhir:spec/fhir:combination/@value/string()
            return
                $d
    let $ret := wksearch:advanceCombiUptoDate($cdetails, $order, $cart, $start, $maxiter, $params)
    let $lll := util:log-app('TRACE','apps.eNahar',$ret)
    return
        if ($ret/ok)
        then
            <samedays>
                { $ret/value/* }
            </samedays>
        else
            <samedays>
                { $ret/info }
            </samedays>
};

declare %private function wksearch:advanceCombiUptoDate(
          $cdetails as element(fhir:detail)+
        , $order
        , $cart
        , $period as element(period)
        , $iter as xs:int
        , $params as map(*)
        )
{
    let $lll := util:log-app('TRACE','apps.eNahar', concat("... advanceCombiUptoDate: ",$iter))
    let $ret := wksearch:tryCombiUptoDate($cdetails, $order, $cart, $period, $iter, $params)
    let $lll := util:log-app('TRACE','apps.eNahar', $ret)
    let $niter := xs:int($ret/info/combi/request/iter) - 1
    return
        if (count($ret/value/day)>0)
        then
            <result>
                <ok/>
                <value>{$ret/value/day}</value>
            </result>
        else
            if ($niter > 0)
            then
                (:~ 
                 :
                 :)
                let $start := xs:dateTime($ret/info/combi/request/start)
                let $end   := xs:dateTime($ret/info/combi/request/end) 
                let $incr := xs:dateTime($end) - xs:dateTime($start)
                let $new  := xs:dateTime(concat(substring-before($ret/info/combi/request/end,'T'),'T08:00:00')) + xs:dayTimeDuration('P1D')
                let $nstart := 
                    <period>
                        <start>{$new }</start>
                        <end>{$new + $incr}</end>
                    </period>
                return
                    wksearch:advanceCombiUptoDate($cdetails, $order, $cart, $nstart, $niter, $params)
            else
                <result>
                    <notfound/>
                    { $ret/info }
                </result>
};

declare %private function wksearch:tryCombiUptoDate(
          $details as element(fhir:detail)+
        , $order as element(fhir:Order)
        , $cart as element(cart)
        , $start as element(period)
        , $iter as xs:int
        , $params as map(*)
        ) as element(result)
{    
    let $lll := util:log-app('TRACE','apps.eNahar', "... tryCombiUptoDate")
    let $selected := head($details)
    let $rest     := tail($details)
    let $sret := wksearch:searchSimpleUptoDate($selected, $start, $iter, $params)
    let $lll := util:log-app('TRACE','apps.eNahar', $sret)
    return
        if ($sret/ok)
        then
            let $nstart := 
                    <period>
                        { $sret/info/request/start }
                        { $sret/info/request/end }
                    </period>
            let $slots := wksearch:tryRestNormal(head($rest),tail($rest),$sret/slots, $nstart, $params)
            let $lll := util:log-app('TRACE','apps.eNahar', $slots)
            (: zipSameDay expects slots in details/spec/combination order :)
            let $zippedDays := slot-util:zipSameDay($cart/sameday, $order/fhir:detail, $slots)
            return
                if (count($zippedDays)>0)
                then
                    <result>
                        <ok/>
                        <value>{$zippedDays}</value>
                    </result>
                else
                    <result>
                        <error/>
                        <info>
                            <combi>
                            <request>
                                <iter>{$sret/info/request/iter/string()}</iter>
                                <start>{$sret/info/request/start/string()}</start>
                                <end>{$sret/info/request/end/string()}</end>
                            </request>
                            <rawSlots>
                            {
                                for $slot in $slots
                                return
                                    <detail id="{$slot/detail/@id/string()}">
                                        <label>{$order/fhir:detail[@id=$slot/detail/@id]/fhir:schedule/fhir:display/@value/string()}</label>
                                        <days>{count($slot/day)}</days>
                                        <slots>{count($slot/day//tp)}</slots>
                                    </detail>
                            }
                            </rawSlots>
                            </combi>
                        </info>
                    </result>
        else
                    <result>
                        <error>kein Termin: {$selected/fhir/actor/fhir:role/@value/string()}</error>
                        <info>
                            <combi>
                                <request>
                                    <iter>{$sret/info/request/iter/string()}</iter>
                                    <start>{$sret/info/request/start/string()}</start>
                                    <end>{$sret/info/request/end/string()}</end>
                                </request>
                            </combi>
                        </info>
                    </result>
};

declare %private function wksearch:tryRestNormal(
          $head as element(fhir:detail)
        , $tail as element(fhir:detail)*
        , $seq as element(slots)+
        , $start as element(period)
        , $params as map(*)
        ) as element(slots)+
{
    let $res := wksimple:searchSimpleTimePeriod($head, $start, $params)
    let $ret :=
            (
              $res
            , $seq
            )
    return
        (: break if res empty :)
        if (count($tail)>0)
        then
            wksearch:tryRestNormal(head($tail), tail($tail), $ret, $start, $params)
        else
            reverse($ret)
};

declare %private function wksearch:mapSimpleUptoDate(
          $order as element(fhir:Order)+
        , $cart as element(cart)
        , $params as map(*)
        )
{
    let $simple := for $od in $order/fhir:detail[@id= distinct-values($cart/simple/@id)]
        return
            wksearch:searchSimpleUptoDate($od, $cart/simple[@id=$od/@id]/period,$wksearch:maxiter, $params)
    return
        <single>
            { $simple/slots }
            <info>
                <simple>
                <text>Suche bis der Arzt kommt</text>
                <rawSlots>
                {
                    for $res in $simple
                    return
                        <detail id="{$res/slots/detail/@id/string()}">
                            <label>{$order/fhir:detail[@id=$res/slots/detail/@id]/fhir:schedule/fhir:display/@value/string()}</label>
                            <request>
                                { $res/iter }
                                { $res/period/start }
                                { $res/period/end }
                            </request>
                            <days>{count($res/slots/day)}</days>
                            <slots>{count($res/slots/day//tp)}</slots>
                        </detail>
                }
                </rawSlots>
                </simple>
            </info>
        </single>
};

declare %private function wksearch:searchSimpleUptoDate(
          $detail as element(fhir:detail)
        , $period as element(period)
        , $iter as xs:int
        , $params as map(*)
        ) as element(result)
{
    let $res := wksimple:searchSimpleTimePeriod($detail, $period, $params)
    let $niter := $iter - 1
    return
        if (count($res/day)>0 or $niter=0)
        then 
            <result>
                { if (count($res/day)>0) then <ok/> else <notfound/> }
                <info>
                    <request>
                        <iter>{$iter}</iter>
                        { $period/start }
                        { $period/end }
                    </request>
                </info>
                { $res }
            </result>
        else 
            let $start := xs:dateTime($period/start)
            let $end   := xs:dateTime($period/end) 
            let $incr  := xs:dateTime($end) - xs:dateTime($start)
            let $new   := xs:dateTime(concat(substring-before($period/end,'T'),'T08:00:00')) + xs:dayTimeDuration('P1D')
            let $nstart := 
                <period>
                    <start>{$new }</start>
                    <end>{$new + $incr}</end>
                </period>
            return
                wksearch:searchSimpleUptoDate($detail, $nstart, $niter, $params)
};

