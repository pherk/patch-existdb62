xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

(: 
 : Analysis of Order data
 : 1. all order details have ((acq = open and no date in start) or (acq = closed and date in start))
 : 2. order with status = (cancelled,completed) should remain in this status because they are really completed or order/encounters are cancelled
 : 3. a small amount of order detail status does not agree with acq value
 :    -  
 :)
declare function local:sequence-node-equal-any-order
  ( $seq1 as node()* ,
    $seq2 as node()*
  )  as xs:boolean
{

  not( ($seq1 except $seq2, $seq2 except $seq1))
 };
 declare function local:is-node-in-sequence-deep-equal
  ( $node as node()? ,
    $seq as node()* )  as xs:boolean {

   some $nodeInSeq in $seq satisfies deep-equal($nodeInSeq,$node)
 };
 declare function local:distinct-deep
  ( $nodes as node()* )  as node()* {

    for $seq in (1 to count($nodes))
    return $nodes[$seq][not(local:is-node-in-sequence-deep-equal(
                          .,$nodes[position() < $seq]))]
};

declare function local:checkRGStatus(
      $request as item()*
    , $old as xs:string
    ) as xs:string
{
    let $ss := distinct-values($request/fhir:status/@value)
    let $ngs := switch($old)
        case 'draft' return if (count($request)>0)
                then local:ratingRG($ss,$old)
                else 'draft'
        case 'active' return local:ratingRG($ss,$old)
        default return $old
    return
        $ngs
};

declare function local:ratingRG(
          $rs  as xs:string*
        , $old as xs:string
    ) as xs:string
{
    let $ss := $rs[.!='cancelled']          (: 'cancelled' is ignored in rating :)
    return
        if (count($ss)=0)
        then 'cancelled'
        else if (count($ss)=1)              (: all other request have same status :)
        then $ss
        else $old                           (: if multiple substatus other than cancelled old status remains :)
};

declare function local:mapAcqStatus(
        $status as xs:string
    )
{
    switch($status)
    case 'open'     return 'active'
    case 'accepted' return 'active'
    case 'closed' return 'completed'
    case 'cancelled' return 'cancelled'
    default return 'active'
};
declare function local:mapRequestStatus(
        $status as xs:string
    )
{
    switch($status)
    case 'draft'     return 'draft'
    case 'cancelled' return 'cancelled'
    case 'completed' return 'completed'
    case 'entered-in-error' return 'entered-in-error'
    default return 'active'
};

declare function local:isActiveAcq(
        $status as xs:string
    ) as xs:boolean
{
  $status = ('open','received','accepted')  
};

let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $ss := distinct-values($oc/fhir:Order/fhir:status/@value)
for $s in $ss
let $os := $oc/fhir:Order[fhir:status[@value=$s]][fhir:reason//fhir:code/@value='appointment']
return
 element {$s} {
    attribute n {count($os)}
    , let $dvs := for $o in $os
            for $d in $o/fhir:detail
            let $dm := local:mapAcqStatus($d//fhir:acq/@value)
            let $ds  := local:mapRequestStatus($d/fhir:status/@value)
            return
                if ($ds=($dm,'cancelled'))
                then if ($ds=$d/fhir:status/@value)
                    then ()
                    else <status>
                            {$d//fhir:acq}
                            {$d/fhir:status}
                        </status>
                else <acq>
                    {$d//fhir:acq}
                    {$d/fhir:status}
                    <ids>{string-join(($o/fhir:detail/@id),'-')}</ids>
                    </acq>
      return
        local:distinct-deep($dvs)
 }
(:  
 
let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $ss := distinct-values($oc/fhir:Order/fhir:status/@value)
for $s in $ss
let $os := $oc/fhir:Order[fhir:status[@value=$s]][fhir:reason//fhir:code/@value='appointment']
return
 element {$s} {
    attribute n {count($os)}
    , let $dvs := for $o in $os
            let $ds := for $d in $o/fhir:detail[fhir:status/@value!='cancelled']
                return
                    local:mapRequestStatus($d/fhir:status/@value)
            return
                if ($o/fhir:status/@value=($ds))
                then
                    ()
                    (:
                    <order>
                        <details>{string-join(($ds),'-')}</details>
                        {$o/fhir:status}
                    </order>
                    :)
                else if (count(distinct-values($ds))=1)
                then switch($s)
                    case 'cancelled' return
                        if ($ds[1]='completed')
                        then <same>completed</same>
                        else ()
                    case 'completed' return ()
                    default return
                        if ($ds[1]='completed')
                        then <same>completed</same>
                        else <same>active</same>
                else switch($s)
                    case 'cancelled' return ()
                    case 'completed' return ()
                    default return
                            <same>active</same>
      return
        local:distinct-deep($dvs)
 }
:)
