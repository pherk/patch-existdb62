xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
(:
[*:member] 
[*:participant/*:participant]
:)
let $tmin := "2023-02-01" || "T00:30:00"
let $tmax := "2023-06-31" || "T20:00:00"
let $es := collection('/db/apps/nabuEncounter/data/planned')
let $encs := $es/fhir:Encounter[fhir:period/fhir:start[@value<$tmax]][fhir:period/fhir:end[@value>$tmin]]
let $pids := distinct-values($encs/fhir:subject/fhir:reference/@value)


let $cts := collection('/db/apps/nabuCom/data/CareTeams')/fhir:CareTeam[fhir:subject[fhir:reference/@value=$pids]]
for $ct in $cts[*:member] | $cts[*:participant/*:participant] 
return
    $ct
