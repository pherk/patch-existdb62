xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $pid := concat("nabu/patients/", "p-5da33fde-3b32-4da1-a33f-de3b328da1dc")
let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:patient[fhir:reference/@value=$pid]]
for $o in $eocs
let $cid := substring-after($o/fhir:team/fhir:reference/@value,'nabu/careteams/')
let $ct := $cts/fhir:CareTeam[fhir:id[@value=$cid]]
order by $o/fhir:period/fhir:start/@value/string() descending
return
    ($o,$ct)