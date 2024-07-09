xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $pref := 'nabu/patients/' ||'p-c7f029d8-f681-4037-8f24-11f3c9f386c3'
let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:subject/fhir:reference[@value=$pref]]
for $o in $os
let $ohs := collection('/db/apps/nabuHistory/data/Orders')/fhir:Order[fhir:id[@value=$o/fhir:id/@value]]
order by $o/fhir:lastModified/@value/string() descending
return
<order>
    <last id="{$o/@xml:id/string()}" lastModified="{$o/*:lastModified/@value/string()}">
        <id>{$o/*:id/@value/string()}</id>
        <item>{concat($o/*:date/@value,' : ', string-join($o/*:detail/*:actor/*:reference/@value,','),' : ', string-join($o/*:detail/*:actor/*:display/@value,','))}</item>
        <modified>{concat($o/*:lastModifiedBy/*:display/@value,':',substring-after($o/*:lastModifiedBy/*:reference/@value,'metis/practitioners/'),' - ', $o/*:status/@value)}</modified>
    </last>
    {$o}
    <history>
    {
        for $oh in $ohs
        order by $oh/*:lastModified/@value/string()
        return
        <item id="{$oh/@xml:id/string()}" lastModified="{$oh/*:lastModified/@value/string()}">
            <info>{concat($oh/*:date/@value,' : ', string-join($oh/*:detail/*:actor/*:display/@value,','))}</info>
            <modified>{concat($oh/*:lastModifiedBy/*:display/@value,':',substring-after($oh/*:lastModifiedBy/*:reference/@value,'metis/practitioners/'), ' - ', $oh/*:status/@value)}</modified>
        {$oh}
        </item>
    }
    </history>
</order>
    