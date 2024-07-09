xquery version "3.0";
(: 
 : function library for date conversion.
 : @author Peter Herkenrath
 : @version 1.3
 : @see http://www.enahar.org
 :
 :)
module namespace date="http://enahar.org/exist/apps/enahar/date";

import module namespace dt="http://exist-db.org/xquery/datetime" at "java:org.exist.xquery.modules.datetime.DateTimeModule";


declare variable $date:tzrex := "(Z|[+-](?:2[0-3]|[01][0-9])(?::?(?:[0-5][0-9]))?)";
declare variable $date:daterex := "(-?(?:[1-9][0-9]*)?[0-9]{4})-(1[0-2]|0[1-9])-(3[01]|0[1-9]|[12][0-9])";
(:~
 : converts several shortcuts to xs:date
 : ('auto','heute','h'), ('m'), ('nW'), ('nM'), ('\dw'), ('\dm'), ('dd.mm.yy'), 
 : 
 : @param $string   string
 : @return xs:date?
 :)
declare function date:easyDate($string as xs:string, $epoch as xs:date) as xs:date
{
    try {
        xs:date($string)
    } catch * {
        let $ls := lower-case($string)
        let $current := $epoch
        let $date :=
            if ($ls = ('auto','heute','h'))
            then $current
            else if ($ls = "m")
            then $current + xs:dayTimeDuration('P1D')       
            else if ($ls = "nw")
            then $current + 7*xs:dayTimeDuration('P1D')
            else if ($ls = "nm")
            then $current + 28*xs:dayTimeDuration('P1D')
            else if ($ls = "p90d")
            then current-date() + 90*xs:dayTimeDuration('P1D')
            else if (matches($ls,'^\dw$'))
            then $current + xs:int(substring($ls,1,1))*7*xs:dayTimeDuration('P1D')
            else if (matches($ls,'^\dm$'))
            then $current + xs:int(substring($ls,1,1))*28*xs:dayTimeDuration('P1D')
            else if (matches($string, '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$'))
                then if (contains($string,'.'))         (: short german date :)
                    then date:ddmmyy-to-date($string)
                    else if (contains($string,'-'))     (: short iso8601 :)
                    then date:yymmdd-to-date($string)
                    else $string
                else date:ddmmyyyy-to-date($string)     (: german date :)
        return
            adjust-date-to-timezone($date,())
    }
};

(:~
 : converts several shortcuts to xs:dateTime
 : ('auto','heute','h'), ('m'), ('nW'), ('nM'), ('\dw'), ('\dm'), ('dd.mm.yy')
 : actual time is used to fill
 : 
 : @param $string   string
 : @return xs:dateTime?
 :)
declare function date:easyDateTime($string as xs:string, $epoch as xs:dateTime) as xs:dateTime
{
    try {
        xs:dateTime($string)
    } catch * {
        let $ls := lower-case($string)
        let $current := $epoch
        let $dt :=
            switch ($ls)
            case "auto"  return $current
            case "heute" return $current
            case "h"     return $current  
            case "m"     return $current +    xs:dayTimeDuration('P1D')       
            case "nw"    return $current +  7*xs:dayTimeDuration('P1D')
            case "nm"    return $current + 28*xs:dayTimeDuration('P1D')
            case "p90d"  return current-dateTime() + 90*xs:dayTimeDuration('P1D')
            default return
                if (matches($ls,'^\dw$'))
                then $current + xs:int(substring($ls,1,1))*7*xs:dayTimeDuration('P1D')
                else if (matches($ls,'^\d\dw$'))
                then $current + xs:int(substring($ls,1,2))*7*xs:dayTimeDuration('P1D')
                else if (matches($ls,'^\dm$'))
                then $current + xs:int(substring($ls,1,1))*28*xs:dayTimeDuration('P1D')
                else if (matches($ls,'^\d\dm$'))
                then $current + xs:int(substring($ls,1,2))*28*xs:dayTimeDuration('P1D')
                else if (matches($string, '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$'))
                    then if (contains($string,'.'))         (: short german date :)
                        then xs:dateTime(concat(date:ddmmyy-to-date($string), 'T08:00:00'))
                        else if (contains($string,'-'))     (: short iso8601 :)
                        then xs:dateTime(concat(date:yymmdd-to-date($string), 'T08:00:00'))
                        else $string
                    else if (contains($string,'-'))
                        then xs:dateTime(concat(date:yyyymmdd-to-date($string), 'T08:00:00'))     (: iso date :)
                        else xs:dateTime(concat(date:ddmmyyyy-to-date($string), 'T08:00:00'))     (: german date :)
        return
            adjust-dateTime-to-timezone($dt,())
    }
};

(:~
 : show dateTime with simplifications for recent times
 : 
 : @param $dateTime
 : @return string
 :)
declare function date:formatDateTime($dateTime as xs:dateTime) {
    let $diff := current-dateTime() - $dateTime
    let $daysAgo := days-from-duration($diff)
    let $hoursAgo := hours-from-duration($diff)
    let $minAgo := minutes-from-duration($diff)
    let $secsAgo := seconds-from-duration($diff)
    return
        if ($daysAgo eq 0) then
            if($hoursAgo eq 0) then
                if ($minAgo eq 0) then
                    "just now"
                else
                    $minAgo || " minutes ago"
                
            else
                $hoursAgo || " hours ago"
        else if ($daysAgo lt 14) then
            $daysAgo || " days ago"
        else
            dt:format-dateTime($dateTime, "EEE, d MMM yyyy HH:mm:ss")
};

declare function date:mmddyyyy-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$',
                        '$3-$1-$2'))
};

declare function date:mmddyy-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$',
                        '20$3-$1-$2'))
};
 
declare function date:ddmmyyyy-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$',
                        '$3-$2-$1'))
};
 
declare function date:ddmmyy-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$',
                        '20$3-$2-$1'))
};
 
   
declare function date:yyyymmdd-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{4})\D*(\d{2})\D*(\d{2})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{4})\D*(\d{2})\D*(\d{2})\D*$',
                        '$1-$2-$3'))
};
 
declare function date:yymmdd-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$',
                        '20$1-$2-$3'))
};
 
(:  
declare function date:yyyyddmm-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{4})\D*(\d{2})\D*(\d{2})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{4})\D*(\d{2})\D*(\d{2})\D*$',
                        '$1-$3-$2'))
};
 
declare function date:yyddmm-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$',
                        '20$1-$3-$2'))
};
:)