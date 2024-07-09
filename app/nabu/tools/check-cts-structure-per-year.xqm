xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
(:
[*:member] 
[*:participant/*:participant]
:)
let $year := "2016"
for $month in ("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")
let $tmin := $year || "-" || $month || "-16" || "T00:30:00"
let $tmax := $year || "-" || $month || "-31" || "T20:00:00"
let $es := collection('/db/apps/nabuEncounter/data/' || $year)
let $encs := $es/fhir:Encounter[fhir:period/fhir:start[@value<$tmax]][fhir:period/fhir:end[@value>$tmin]]
let $pids := distinct-values($encs/fhir:subject/fhir:reference/@value)
return
    let $cts := collection('/db/apps/nabuCom/data/CareTeams')/fhir:CareTeam[fhir:subject[fhir:reference/@value=$pids]]
    for $ct in $cts[*:member] | $cts[*:participant/*:participant] 
    return
        $ct
