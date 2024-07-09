xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuEncounter/data/2021')/fhir:Encounter[fhir:subject[fhir:reference/@value='nabu/patients/p-0ba6c442-1e67-4603-8249-93a77e496f85']]
for $o in $os
let $ohs := collection('/db/apps/nabuHistory/data/Encounters')/fhir:Encounter[fhir:id[@value=$o/fhir:id/@value]]
order by $o/fhir:lastModified/@value/string() descending
return
<enc>
    <last id="{$o/@xml:id/string()}" lastModified="{$o/*:lastModified/@value/string()}">
        <id>{$o/*:id/@value/string()}</id>
        <item>{concat($o/fhir:period/fhir:start/@value,' - ',$o/fhir:period/fhir:end/@value,' : ', string-join($o/*:participant/*:actor/*:reference/@value,','),' : ', string-join($o/*:participant/*:actor/*:display/@value,','))}</item>
        <modified>{concat($o/*:lastModifiedBy/*:display/@value,':',substring-after($o/*:lastModifiedBy/*:reference/@value,'metis/practitioners/'),' - ', $o/*:status/@value)}</modified>
    </last>
    <history>
    {
        for $oh in $ohs
        order by $oh/fhir:lastModified/@value/string()
        return
        <item id="{$oh/@xml:id/string()}" lastModified="{$oh/*:lastModified/@value/string()}">
            <info>{concat($oh/fhir:period/fhir:start/@value,' - ',$oh/*:end/@value,' : ', string-join($oh/*:participant/*:actor/*:display/@value,','))}</info>
            <modified>{concat($oh/*:lastModifiedBy/*:display/@value,':',substring-after($oh/*:lastModifiedBy/*:reference/@value,'metis/practitioners/'), ' - ', $oh/*:status/@value)}</modified>
        </item>
    }
    </history>
</enc>

    