xquery version "3.0";

(: 
 : converts meeting schedules in cal to events
 : 
 : @version 0.9
 : @since
 : @created 2018-07-29
 : 
 : @copyright Peter Herkenrath 2018
 :)
module namespace meeting = "http://enahar.org/exist/apps/enahar/meeting";

import module namespace functx =  "http://www.functx.com" at "../modules/functx.xqm";

import module namespace config = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";
import module namespace ical  = "http://enahar.org/lib/ical";
import module namespace ice   = "http://enahar.org/lib/ice";

import module namespace xqtime= "http://enahar.org/lib/xqtime";

import module namespace cal-util = "http://enahar.org/exist/apps/enahar/cal-util" at "../schedule/cal-utils.xqm";

declare function meeting:events(
          $cal as element(cal)+
        , $date as xs:date
        , $meetings as element(schedule)*
        ) as element(tp)*
{
    let $lll := if (count($cal)>1)
        then
            util:log-app('ERROR','apps.eNahar',$cal)
        else
            ()
    let $mrefs := $cal/schedule/global[type/@value='meeting']/reference/@value/string()
    let $msas   := 
        for $mref in distinct-values($mrefs)
        return
            $meetings/../schedule[identifier/value[@value=$mref]]/agenda
    let $shifts     := cal-util:filterValidAgendas($msas,$date)/event
    let $rrEvents  := (ice:match-rdates($date,$shifts),ice:match-rrules($date, $shifts))
    (: let $lll := util:log-app('TRACE','apps.nabu',$rrEvents) :)
    let $exEvents  := ice:match-exdates($date,$shifts)
    let $rawEvents := functx:distinct-nodes($rrEvents[not(.=$exEvents)])
    let $rawTPs    := cal-util:event2tp($date, $rawEvents)
(: 
    let $lll := util:log-app('TRACE','apps.eNahar',$rawTPs)
:)
    return
        $rawTPs
};