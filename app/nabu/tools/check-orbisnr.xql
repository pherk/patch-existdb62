xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:identifier[fhir:value/@value!='']][fhir:active[@value="true"]]
let $ids :=  distinct-values($os/fhir:identifier/fhir:value/@value)
for $id in $ids
order by $id
return
    if (count($os/../fhir:Patient[fhir:identifier[fhir:value/@value=$id]])>1)
    then $os/../fhir:Patient[fhir:identifier[fhir:value/@value=$id]]
    else ()