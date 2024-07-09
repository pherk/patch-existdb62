xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace tei= "http://www.tei-c.org/ns/1.0";

let $from := "2020-09-23T14:00:00"
let $to   := '2020-09-23T15:00:00'
let $os := collection('/db/apps/nabuCommunication/data/2020')/fhir:Communication[fhir:extension/fhir:valueDateTime/@value > $from][fhir:extension/fhir:valueDateTime/@value < $to]
return
<letters count="{count($os)}">
    {
for $o in $os
return
    (:
    concat($o/*:id/@value,'   ',$o/*:subject/*:display/@value,' : ',  ' ', $o/*:lastModified/@value,$o/*:lastModifiedBy/*:display/@value, '   ', $o/*:status/@value)
    :)
    <letter name="{$o/fhir:subject/fhir:display/@value/string()}">
        <info>
        {$o//tei:list[@rend='bulleted']}
        </info>
    </letter>
}
</letters>