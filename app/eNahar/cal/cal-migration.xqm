xquery version "3.0";

module namespace calmigr = "http://enahar.org/exist/apps/eNahar/cal-migration";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";



declare function calmigr:update-0.9-specialamb($c)
{
    for $s in $c/schedule
    return
        if ($s/global/type/@value='service')
        then if (count($s/global/isSpecial)=0)
            then system:as-user("vdba","kikl823!",
                    (
                      update insert <isSpecial value="false"/> into $s/global
                    , update insert <ff value="true"/> into $s/global
                    ))
            else ()
        else ()
};


declare function calmigr:update-0.9-rdates($o)
{
<update-0.9-rdates owner="{$o/owner/display/@value/string()}">
{
    for $e in $o//event
    return
        if ($e/rdate)
        then
            let $ds := $e/rdate/date
            let $rd := 
                <rdate>
                {
                    for $d in $ds
                    return
                        <date value="{$d/@value/string()}"/>
                }
                </rdate>
            let $upd := system:as-user("vdba","kikl823!",
                    (
                      update delete $e/rdate
                    , if ($e/note)
                      then update insert $rd following $e/note
                      else update insert $rd following $e/name
                    ))
            return
                <rdate n="{count($ds)}"/>
        else ()
}
</update-0.9-rdates>
};
