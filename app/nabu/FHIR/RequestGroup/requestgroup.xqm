xquery version "3.0";

(: 
 : Defines the RequestGroup utility functions.
 : @author Peter Herkenrath
 : @version 1.0
 : @see http://www.enahar.org
 :
 :)
module namespace requestgrp = "http://enahar.org/exist/apps/nabu/requestgroup";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

declare namespace fhir   = "http://hl7.org/fhir";

declare variable $requestgrp:validRequestStatus       := ('draft','active','suspended','completed','cancelled','entered-in-error','unknown');
declare variable $requestgrp:validOrderDetailStatus   := ('draft','active','completed','cancelled','entered-in-error');
declare variable $requestgrp:validTaskStatus          := ('draft','requested','received','accepted','completed','cancelled','entered-in-error');

declare function requestgrp:checkGroupStatus(
      $request as item()*
    , $old as xs:string
    , $did as xs:string
    , $dnew as xs:string
    ) as xs:string
{
    let $ss := distinct-values($request[@id!=$did]/fhir:status/@value)
    let $ngs := switch($old)
        case 'draft' return if (count($request)>0)
                then requestgrp:rating($ss,$old,$dnew)
                else 'draft'
        case 'active' return requestgrp:rating($ss,$old,$dnew)
        default return $old
    return
    $ngs
};

declare function requestgrp:rating(
          $rs  as xs:string*
        , $old as xs:string
        , $new as xs:string
    ) as xs:string
{
    let $ss := $rs[.!='cancelled']          (: 'cancelled' is ignored in rating :)
    return
        if (count($ss)=0)
        then requestgrp:mapStatus($new)
        else if (count($ss)=1)              (: all other request have same status :)
        then if ($new=$ss or $new='cancelled')  
            then requestgrp:mapStatus($ss)
            else requestgrp:mapStatus($new)
        else $old                           (: if multiple substatus other than cancelled old status remains :)
};

declare function requestgrp:mapStatus(
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
declare function requestgrp:isActive(
        $status as xs:string
    ) as xs:boolean
{
  $status = ('active','requested','received','accepted')  
};