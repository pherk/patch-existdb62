xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/fhir:Appointment[fhir:start[starts-with(@value,'2017-03-08')]][starts-with(fhir:participant/fhir:actor/fhir:display/@value,'Schend, Linus')]
for $o in $os
let $ohs := collection('/db/apps/nabuHistory/data/Appointments')/fhir:Appointment[fhir:id[@value=$o/fhir:id/@value]]
order by $o/*:lastModified/@value/string()
return
<app>
    <last id="{$o/@xml:id/string()}" lastModified="{$o/*:lastModified/@value/string()}">
        <id>{$o/*:id/@value/string()}</id>
        <item>{concat($o/*:start/@value,' - ',$o/*:end/@value,' : ', string-join($o/*:participant/*:actor/*:reference/@value,','),' : ', string-join($o/*:participant/*:actor/*:display/@value,','))}</item>
        <modified>{concat($o/*:lastModifiedBy/*:display/@value,':',substring-after($o/*:lastModifiedBy/*:reference/@value,'metis/practitioners/'),' - ', $o/*:status/@value)}</modified>
    </last>
    <history>
    {
        for $oh in $ohs
        order by $oh/*:lastModified/@value/string()
        return
        <item id="{$oh/@xml:id/string()}" lastModified="{$oh/*:lastModified/@value/string()}">
            <info>{concat($oh/*:start/@value,' - ',$oh/*:end/@value,' : ', string-join($oh/*:participant/*:actor/*:display/@value,','))}</info>
            <modified>{concat($oh/*:lastModifiedBy/*:display/@value,':',substring-after($oh/*:lastModifiedBy/*:reference/@value,'metis/practitioners/'), ' - ', $oh/*:status/@value)}</modified>
        </item>
    }
    </history>
</app>
    