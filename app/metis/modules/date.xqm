xquery version "3.0";
(: 
 : function library for date conversion.
 : @author Peter Herkenrath
 : @version 1.0
 : @see http://www.enahar.org
 :
 :)
module namespace date="http://enahar.org/exist/apps/metis/date";


declare function date:shortTime(
    $dt as xs:dateTime
    )
{
    let $hour := hours-from-dateTime($dt)
    let $min := minutes-from-dateTime($dt)
    return
        concat(if ($hour=0) then "00" else $hour,':', if ($min=0) then "00" else $min)
};
(:~
 : converts several shortcuts to xs:date
 : ('auto','heute','h'), ('m'), ('nW'), ('nM'), ('\dw'), ('\dm'), ('dd.mm.yy')
 : 
 : @param $string   string
 : @return xs:date?
 :)
declare function date:date($string as xs:string) as xs:date?
{
let $ls := lower-case($string)
return
    if ($ls = ('auto','heute','h'))
    then current-date()
    else if ($ls = "m")
    then current-date() + xs:dayTimeDuration('P1D')       
    else if ($ls = "nw")
    then current-date() + 7*xs:dayTimeDuration('P1D')
    else if ($ls = "nm")
    then current-date() + 28*xs:dayTimeDuration('P1D')
    else if (matches($ls,'^\dw$'))
    then current-date() + xs:int(substring($ls,1,1))*7*xs:dayTimeDuration('P1D')
    else if (matches($ls,'^\dm$'))
    then current-date() + xs:int(substring($ls,1,1))*28*xs:dayTimeDuration('P1D')
    else date:ddmmyy-to-date($string)
};

(:~
 : converts several shortcuts to xs:dateTime
 : ('auto','heute','h'), ('m'), ('nW'), ('nM'), ('\dw'), ('\dm'), ('dd.mm.yy')
 : actual time is used to fill
 : 
 : @param $string   string
 : @return xs:dateTime?
 :)
declare function date:dateTime($string as xs:string) as xs:dateTime
{
    let $ls := lower-case($string)
    return
        switch ($ls)
        case "auto"  return current-dateTime()
        case "heute" return current-dateTime()
        case "h"     return current-dateTime()  
        case "m"     return current-dateTime() + xs:dayTimeDuration('P1D')       
        case "nw"    return current-dateTime() + 7*xs:dayTimeDuration('P1D')
        case "nm"    return current-dateTime() + 28*xs:dayTimeDuration('P1D')
        default return
            if (matches($ls,'^\dw$'))
            then current-dateTime() + xs:int(substring($ls,1,1))*7*xs:dayTimeDuration('P1D')
            else if (matches($ls,'^\dm$'))
            then current-dateTime() + xs:int(substring($ls,1,1))*28*xs:dayTimeDuration('P1D')
            else date:ddmmyy-to-date($string)
    (: 
        default             return error(xs:QName("XPTY0004"), concat("Unknown Date: ", $string))
    :)
};

(:~
 : show dateTime with simplifications for recent times
 : 
 : @param $dateTime
 : @return string
 :)
declare function date:formatDate($dateTime as xs:dateTime) {
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
            format-dateTime($dateTime, "EEE, d MMM yyyy HH:mm:ss")
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
 
  
 declare function date:yyyyddmm-to-date 
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
 
 declare function date:yyddmm-to-date 
  ( $dateString as xs:string? )  as xs:date? {
       
   if (fn:empty($dateString))
   then ()
   else if (fn:not(fn:matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$')))
   then fn:error(xs:QName('date:Invalid_Date_Format'))
   else xs:date(fn:replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{2})\D*$',
                        '$1-$2-20$3'))
 };