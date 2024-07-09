xquery version "3.0";

module namespace ical-fmt = "http://enahar.org/exist/exist/apps/enahar/format";
 
(:
    Note that all codes are case sensitive. All non-code characters are passed through the formatting.
    Sunday is the first day of the week (1) and Saturday the last (7).
    January is the first month (1) and December the last (12).
    Hours of the day start on 1 and end on 12 or 24.
 
    Code    Description                             Examples
    G       Era designator                          BC, AD
    yy      Two digit year                          89, 10
    yyyy    Four digit year                         1989, 2010
    M       Single digit month, or two if two       4, 12
    MM      Forced two digit month                  04, 12
    MMM     Three letter month abreviation          Jan, May
    MMMM    Full month name                         January, May
    d       Single digit day num, or two if two     3, 27
    dd      Forced double digit day num             03, 27
    h       Single digit 12 hour, or two if two     7, 11
    hh      Forced double digit 12 hour             07, 11
    H       Single digit 24 hour, or two if two     8, 19
    HH      Forced double digit 24 hour             08, 19
    m       Single digit minute, or two if two      3, 59
    mm      Forced double digit minute              03, 59
    s       Single digit seconds, or two if two     4, 30
    ss      Forced double digit seconds             04, 30
    S       First digit of milliseconds             1, 5
    SS      First two digits of miliseconds         11, 54
    SSS     First three digits of milliseconds      114, 543
    SSSS    First four digits of milliseconds       1148, 5437
    SSSSS   All five digits of milliseconds         11489, 54376
    a       AM/PM Marker in lowercase               am, pm
    A       AM/PM Marker in uppercase               AM, PM
    EEE     Three letter day of week abreviation    Tue, Fri
    EEEE    Full name of day of week                Tuesday, Friday
     
    Examples:
     
    ical-fmt:format-dateTime(xs:dateTime(fn:current-dateTime()), "M-d-yy")
    => 8-27-10
     
    ical-fmt:format-dateTime(xs:dateTime(fn:current-dateTime()), "MM/dd/yyyy hh:mm:ss:SSSSS A")
    => 08/27/2010 01:31:30:00852 PM
     
    ical-fmt:format-dateTime(xs:dateTime("1345-08-01T16:47:49.619899-06:00"), "EEEE, MMMM dd, yyyy G @hh:m A")
    => Sunday, August 01, 1345 AD @04:47 PM
     
    ical-fmt:format-dateTime(xs:dateTime("-0044-05-13T00:00:00.00000-06:00"), "yyyy G")
    => 44 BC
     
:)
 
declare function ical-fmt:format-date($date as xs:date, $pattern as xs:string) {
    ical-fmt:format-dateTime(xs:dateTime($date), $pattern)
};
 
declare function ical-fmt:format-dateTime($date-time as xs:dateTime, $pattern as xs:string) {
 
    let $tokens := (
        let $first-pattern-char := fn:substring($pattern, 1, 1)
        let $remaining-pattern := fn:substring($pattern, 2)
        return ical-fmt:determine-token($remaining-pattern, $first-pattern-char, ())
    )
 
    let $year := fn:year-from-dateTime($date-time)
    let $month := fn:month-from-dateTime($date-time)
    let $day := fn:day-from-dateTime($date-time)
    let $hours := fn:hours-from-dateTime($date-time)
    let $minutes := fn:minutes-from-dateTime($date-time)
    let $raw-seconds := fn:seconds-from-dateTime($date-time)
    let $whole-seconds := xs:int(
        if (fn:substring-before(xs:string($raw-seconds), "."))
        then (fn:substring-before(xs:string($raw-seconds), "."))
        else (0)
    )
    let $milliseconds := xs:int(
        if (fn:substring-after(xs:string($raw-seconds), "."))
        then (fn:substring-after(xs:string($raw-seconds), "."))
        else (0)
    )
     
    let $formatted-tokens := (
        for $token-el in $tokens
        let $token := $token-el/text()
        let $token-value := (
            if ($token eq "yyyy")
            then (fn:abs($year))
            else if ($token eq "yy")
            then (fn:substring(xs:string(fn:abs($year)), 3))
            else if ($token eq "M")
            then ($month)
            else if ($token eq "MM")
            then (ical-fmt:pad-to-fill(xs:string($month), 2, "0", fn:true()))
            else if ($token eq "MMM")
            then (ical-fmt:translate-month($month, fn:false()))
            else if ($token eq "MMMM")
            then (ical-fmt:translate-month($month, fn:true()))
            else if ($token eq "d")
            then ($day)
            else if ($token eq "dd")
            then (ical-fmt:pad-to-fill(xs:string($day), 2, "0", fn:true()))
            else if ($token eq "h")
            then (
                if ($hours > 12)
                then ($hours - 12)
                else ($hours)
            )
            else if ($token eq "hh")
            then (
                let $under-13 :=
                    if ($hours > 12)
                    then ($hours - 12)
                    else ($hours)
                return ical-fmt:pad-to-fill(xs:string($under-13), 2, "0", fn:true())
            )
            else if ($token eq "H")
            then ($hours)
            else if ($token eq "HH")
            then (ical-fmt:pad-to-fill(xs:string($hours), 2, "0", fn:true()))
            else if ($token eq "m")
            then ($minutes)
            else if ($token eq "mm")
            then (ical-fmt:pad-to-fill(xs:string($minutes), 2, "0", fn:true()))
            else if ($token eq "s")
            then ($whole-seconds)
            else if ($token eq "ss")
            then (ical-fmt:pad-to-fill(xs:string($whole-seconds), 2, "0", fn:true()))
            else if ($token = ("S", "SS", "SSS", "SSSS", "SSSSS", "SSSSSS"))
            then (
                let $num-places:= fn:string-length($token)
                let $rounded-millis := fn:substring(xs:string($milliseconds), 1, $num-places)
                return ical-fmt:pad-to-fill($rounded-millis, $num-places, "0", fn:true())
            )
            else if ($token eq "a")
            then (
                if ($hours > 11)
                then ("pm")
                else ("am")
            )
            else if ($token eq "A")
            then (
                if ($hours > 11)
                then ("PM")
                else ("AM")
            )
            else if ($token eq "EEE")
            then (ical-fmt:translate-day( ical-fmt:day-of-week($date-time), fn:false()))
            else if ($token eq "EEEE")
            then (ical-fmt:translate-day( ical-fmt:day-of-week($date-time), fn:true()))
            else if ($token eq "G")
            then (
                if ($year > 0)
                then ("AD")
                else ("BC")
            )
            else ($token )
        )
         
        return xs:string($token-value)
    )
     
    return fn:string-join($formatted-tokens, "")
};
 
 
declare function ical-fmt:translate-month($month-num as xs:int, $full as xs:boolean) {
    ical-fmt:translate-month($month-num, $full, "")
};
 
declare function ical-fmt:translate-month($month-num as xs:int, $full as xs:boolean, $lang as xs:string) {
    let $trans :=
        <month-translations>
            <month-translation lang="en" default="true">
                <month num="1">
                    <short>Jan</short>
                    <full>January</full>
                </month>
                <month num="2">
                    <short>Feb</short>
                    <full>February</full>
                </month>
                <month num="3">
                    <short>Mar</short>
                    <full>March</full>
                </month>
                <month num="4">
                    <short>Apr</short>
                    <full>April</full>
                </month>
                <month num="5">
                    <short>May</short>
                    <full>May</full>
                </month>
                <month num="6">
                    <short>Jun</short>
                    <full>June</full>
                </month>
                <month num="7">
                    <short>Jul</short>
                    <full>July</full>
                </month>
                <month num="8">
                    <short>Aug</short>
                    <full>August</full>
                </month>
                <month num="9">
                    <short>Sep</short>
                    <full>September</full>
                </month>
                <month num="10">
                    <short>Oct</short>
                    <full>October</full>
                </month>
                <month num="11">
                    <short>Nov</short>
                    <full>November</full>
                </month>
                <month num="12">
                    <short>Dec</short>
                    <full>December</full>
                </month>
            </month-translation>
        </month-translations>
         
    let $month-trans := (
        if ($trans/month-translation[@lang eq $lang])
        then ($trans/month-translation[@lang eq $lang])
        else ($trans/month-translation[@default eq "true"])
    )
     
    return (
        if ($full)
        then ($month-trans/month[@num = $month-num]/full/text())
        else ($month-trans/month[@num = $month-num]/short/text())
    )
         
};
 
declare function ical-fmt:translate-day($day-of-week-num as xs:int, $full as xs:boolean) {
    ical-fmt:translate-day($day-of-week-num, $full, "")
};
 
declare function ical-fmt:translate-day($day-of-week-num as xs:int, $full as xs:boolean, $lang as xs:string) {
    let $trans :=
        <day-translations>
            <day-translation lang="en" default="true">
                <day num="1">
                    <short>Sun</short>
                    <full>Sunday</full>
                </day>
                <day num="2">
                    <short>Mon</short>
                    <full>Monday</full>
                </day>
                <day num="3">
                    <short>Tue</short>
                    <full>Tuesday</full>
                </day>
                <day num="4">
                    <short>Wed</short>
                    <full>Wednesday</full>
                </day>
                <day num="5">
                    <short>Thu</short>
                    <full>Thursday</full>
                </day>
                <day num="6">
                    <short>Fri</short>
                    <full>Friday</full>
                </day>
                <day num="7">
                    <short>Sat</short>
                    <full>Saturday</full>
                </day>
            </day-translation>
        </day-translations>
         
    let $day-trans := (
        if ($trans/day-translation[@lang eq $lang])
        then ($trans/day-translation[@lang eq $lang])
        else ($trans/day-translation[@default eq "true"])
    )
     
    return (
        if ($full)
        then ($day-trans/day[@num = $day-of-week-num]/full/text())
        else ($day-trans/day[@num = $day-of-week-num]/short/text())
    )
         
};
 
(: adapted from functx:day-of-week by Priscilla Walmsley :)
declare function ical-fmt:day-of-week($date as xs:anyAtomicType?) as xs:integer? {
    if (fn:empty($date))
    then ()
    else (
        if (xs:date('1901-01-04') < xs:date($date))
        then ((xs:integer((xs:date($date) - xs:date('1901-01-04')) div xs:dayTimeDuration('P1D')) mod 7) )
        else ((xs:integer((xs:date('1901-01-04') - xs:date($date)) div xs:dayTimeDuration('P1D')) mod 7) )
    )
};
 
declare function ical-fmt:determine-token($source, $current-tok, $tok-xml) {
    if (fn:string-length($source) = 0)
    then (($tok-xml, <token>{$current-tok}</token>))
    else (
        let $first-seq-char := fn:substring($source, 1, 1)
        let $current-tok-length := fn:string-length($current-tok)
        let $last-current-tok-char := fn:substring($current-tok, $current-tok-length, 1)
        return (
            if ($first-seq-char eq $last-current-tok-char)
            then (
                let $new-source := fn:substring($source, 2)
                let $new-tok := fn:concat($current-tok, $first-seq-char)
                return ical-fmt:determine-token($new-source, $new-tok, $tok-xml)
            )
            else (
                let $new-source := fn:substring($source, 2)
                let $new-current-tok := $first-seq-char
                let $new-tok-xml := ($tok-xml, <token>{$current-tok}</token>)
                return ical-fmt:determine-token($new-source, $new-current-tok, $new-tok-xml)
            )
        )
    )
};
 
declare function ical-fmt:pad-to-fill($value as xs:string, $length as xs:int, $pad-char as xs:string, $pad-left as xs:boolean) {
    if (fn:string-length($value) >= $length)
    then ($value)
    else (
        let $pad-string := fn:string-join((
            for $i in (1 to ($length - fn:string-length($value)))
            return $pad-char
        ), "")
         
        return (
            if ($pad-left)
            then (fn:concat($pad-string, $value))
            else (fn:concat($value, $pad-string))
        )
    )
};
