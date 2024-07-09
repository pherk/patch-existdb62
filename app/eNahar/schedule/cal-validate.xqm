xquery version "3.0";

(: 
 : calendar validation
 : 
 : @version 0.9
 : @since
 : @created 2018-09-29
 : 
 : @copyright Peter Herkenrath 2018
 :)
module namespace icalv = "http://enahar.org/exist/apps/enahar/ical-validate";

import module namespace ice   = "http://enahar.org/lib/ice";
import module namespace xqtime= "http://enahar.org/lib/xqtime";

declare function icalv:validateSchedule(
          $s as element(schedule)
        ) as element(result)
{
                <result>
                    <result value="ok"/>
                    <info value="schedule valid"/>
                </result>
};

declare function icalv:validateCalendar(
          $s as element(cal)
        ) as element(result)
{
                <result>
                    <result value="ok"/>
                    <info value="cal valid"/>
                </result>
};
