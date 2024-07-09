xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Patients')
return
<patient-city>
      {
for $o in $os/fhir:Patient[fhir:birthDate[@value<'1995-01-01']] 
order by $o/*:birthDate/@value/string()
return
    if (starts-with($o/fhir:address/fhir:postalCode/@value,"502"))
    then
    <patient id="{$o/*:id/@value}"><name>{concat($o/*:name/*:family/@value, ', ', $o/*:name/*:given/@value, ', *', $o/*:birthDate/@value,' : ')}</name></patient>
    else ()
      }
</patient-city>