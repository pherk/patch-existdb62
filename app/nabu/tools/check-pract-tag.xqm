xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/metisData/data/FHIR/Practitioners')/fhir:Practitioner[fhir:meta[count(fhir:lastUpdated)>1]]
for $o in $os
return
$o