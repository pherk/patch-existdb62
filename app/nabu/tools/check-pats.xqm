xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:name[fhir:family/@value='Seitz']]
for $o in $os
order by $o/fhir:date/@value/string()
return
    $o
    
    