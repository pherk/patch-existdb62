xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Patients')
return
<bd-problems>
      {
for $o in $os/fhir:Patient[fhir:active[@value="true"]][fhir:birthDate[@value<'1974-01-01']] | $os/fhir:Patient[fhir:active[@value="true"]][fhir:birthDate[@value>'2020-12-31']]
order by $o/fhir:birthDate/@value/string()
return
    <patient id="{$o/*:id/@value}"><name>{concat($o/*:name/*:family/@value, ', ', $o/*:name/*:given/@value, ', *', $o/*:birthDate/@value,' : ')}</name></patient>
      }
</bd-problems>