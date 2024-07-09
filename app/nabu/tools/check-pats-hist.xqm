xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $pcs := collection('/db/apps/nabuData/data/FHIR/Patients')
(: 
let $ps := $pcs/fhir:Patient[fhir:name/fhir:family[starts-with(@value,'Sahin')]]
:)
let $ps := $pcs/fhir:Patient[fhir:id[@value="p-6a935ae9-665c-4bd9-977f-4fd6b66783b0"]]
for $o in $ps
let $ohs := collection('/db/apps/nabuHistory/data/Patients')/fhir:Patient[fhir:id[@value=$o/fhir:id/@value]]
order by $o/fhir:meta/fhir:lastUpdated/@value/string() descending
return
<patient>
    <last id="{$o/fhir:id/@value/string()}">
        <item id="{$o/@xml:id/string()}" lastModified="{$o/fhir:meta/fhir:lastUpdated/@value/string()}"/>
        <info>{string-join(($o/fhir:id/@value,$o/fhir:name/fhir:family/@value, $o/fhir:name/fhir:given/@value, $o/fhir:birthDate/@value,$o/fhir:meta/fhir:lastUpdated/@value, $o/fhir:active/@value),'::')}</info>
        <modified>{concat($o/fhir:meta/fhir:extension/fhir:display/@value,':',substring-after($o/fhir:meta/fhir:extension/fhir:reference/@value,'metis/practitioners/'),' - ', $o/fhir:active/@value)}</modified>
    </last>
    { $o }
    <history>
    {
        for $oh in $ohs
        order by $oh/fhir:meta/fhir:versionId/@value/string() 
        return
        <item id="{$oh/@xml:id/string()}" lastModified="{$oh/fhir:meta/fhir:lastUpdated/@value/string()}">
            <info>"{string-join(($oh/fhir:id/@value,$oh/fhir:name/fhir:family/@value, $oh/fhir:name/fhir:given/@value, $oh/fhir:birthDate/@value, $oh/fhir:active/@value),'::')}</info>
            <modified>{concat($oh/fhir:meta/fhir:extension/fhir:display/@value,':',substring-after($oh/fhir:meta/fhir:extension/fhir:reference/@value,'metis/practitioners/'), ' - ', $oh/fhir:status/@value)}</modified>
            { $oh }
        </item>
    }
    </history>
</patient>
    