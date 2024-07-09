xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/metisData/data/FHIR/Practitioners')/fhir:Practitioner[fhir:name/fhir:family[starts-with(@value,'Barth')]]
for $o in $os
return
 $o