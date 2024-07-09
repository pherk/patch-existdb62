xquery version "3.1";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace dates="http://xqdev.com/dateparser" at "/db/apps/tumblr/modules/date-parser.xqm";
import module namespace iu = "http://history.state.gov/ns/xquery/import-utilities" at "/db/import-utilities.xqm";

for $section in doc('/db/apps/administrative-history/timeline.xml')//tei:div
let $head := $section/tei:head
let $date-string := $head/string()
let $analyze := iu:analyze-date-string($date-string)
let $convert :=
    if ($analyze/self::error) then
        ( 
            'Error: ' || $analyze/string()
        ) 
    else 
        try 
            { 
                let $dates := $analyze/descendant-or-self::date
                return
                    if (count($dates) eq 1) then
                        <date xmlns="http://www.tei-c.org/ns/1.0" when="{dates:parseDate($dates)/string()}">{$date-string}</date>
                    else
                        <date xmlns="http://www.tei-c.org/ns/1.0" from="{dates:parseDate($dates[1])/string()}" to="{dates:parseDate($dates[2])/string()}">{$date-string}</date>
            } 
        catch * 
            {
                "Error parsing " || $date-string 
            }
return
    if ($analyze/self::error) then () else
update value $head with $convert