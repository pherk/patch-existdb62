declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace functx="http://www.functx.com" at "/db/system/repo/functx-1.0/functx/functx.xql";

(: drew on technique from https://github.com/marklogic/commons/blob/master/dates/date-parser.xqy :)

let $months := (
    	"jan", "january", "enero", "janvier", "januar", "gennaio",
    	"feb", "february", "febrero", "fevrier", "februar", "febbraio",
    	"mar", "march", "marzo", "mars", "marz", "marzo",
    	"apr", "april", "abril", "avril", "april", "aprile",
    	"may", "may", "mayo", "mai", "mai", "maggio",
    	"jun", "june", "junio", "juin", "juni", "giugno",
    	"jul", "july", "julio", "juillet", "juli", "luglio",
    	"aug", "august", "agosto", "aout", "august", "agosto",
    	"sep", "september", "septiembre", "septembre", "september", "settembre",
    	"oct", "october", "octubre", "octobre", "oktober", "ottobre",
    	"nov", "november", "noviembre", "novembre", "november", "novembre",
    	"dec", "december", "diciembre", "decembre", "dezember", "dicembre"
    )
let $month-year-regex := '^(' || string-join($months, "|") || ') \d{4}\?$')
for $section in doc('/db/apps/administrative-history/timeline.xml')//tei:div[not(tei:head/tei:date) and matches(lower-case(tei:head), $month-year-regex]
let $head := $section/tei:head
let $month-string := tokenize($head, '\s+')[1]
let $year-string := substring-before(tokenize($head, '\s+')[2], '?')
let $month := functx:pad-integer-to-length(ceiling(index-of($months, lower-case($month-string))[1] div 6), 2)
let $start-date := string-join(($year-string, $month, "01"), "-") cast as xs:date
let $days-in-month := functx:days-in-month($start-date)
let $end-date := string-join(($year-string, $month, functx:pad-integer-to-length($days-in-month, 2)), "-")
let $date :=
    <date xmlns="http://www.tei-c.org/ns/1.0" notBefore="{$start-date}" notAfter="{$end-date}">{$head/string()}</date>
return
update value $head with $date