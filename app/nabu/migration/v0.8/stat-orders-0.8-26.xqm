xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

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
declare function local:mapRGStatus(
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
  $status = ('open','accepted')  
};
(: 
let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $ss := distinct-values($oc/fhir:Order/fhir:status/@value)
for $s in $ss
let $os := $oc/fhir:Order[fhir:status[@value=$s]][fhir:reason//fhir:code/@value='appointment']
return
 element {$s} {
    attribute n {count($os)}
    , let $dvs := for $o in $os
            let $ds := local:checkRGStatus($o/fhir:detail
                    let $dm := local:mapAcqStatus($d//fhir:acq/@value)
                    return
                        if ($d/fhir:status/@value=($dm,'proposed'))
                        then ()
                        else $o
      return
          $dvs
 }
 
 
let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $ss := distinct-values($oc/fhir:Order/fhir:status/@value)
for $s in $ss
let $os := $oc/fhir:Order[fhir:status[@value=$s]][fhir:reason//fhir:code/@value='appointment']
return
 element {$s} {
    attribute n {count($os)}
    , let $dvs := for $o in $os
            let $ds := try {
                    local:checkRGStatus($o/fhir:detail, $o/fhir:status/@value)
            } catch * {
                'error'
            }
            return
                if ($o/fhir:status/@value=($ds))
                then ()
                else $o
      return
          $dvs
 }
:)


let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $ss := distinct-values($oc/fhir:Order/fhir:status/@value)
for $s in $ss
let $os := $oc/fhir:Order[fhir:status[@value=$s]][fhir:reason//fhir:code/@value='appointment']
return
 element {$s} {
    attribute n {count($os)}
    , let $dvs := count($os[count(fhir:detail)=0])

        return
    
            $dvs
    }