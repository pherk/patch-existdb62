xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
(:
[*:member] 
[*:participant/*:participant]
:)
let $pid := concat("nabu/patients/", "p-2c6fe7ed-5a5c-4601-b955-df8e95da8d47")
let $cts := collection('/db/apps/nabuCom/data/CareTeams')/fhir:CareTeam[fhir:subject[fhir:reference/@value=$pid]]
for $ct in $cts

order by $ct/fhir:period/fhir:start/@value/string() descending
return
    $ct