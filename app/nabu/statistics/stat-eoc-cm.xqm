xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $ewocm := $eocs/fhir:EpisodeOfCare[fhir:status[@value="active"]][fhir:careManager[fhir:reference/@value='']]

return
    <eoc total="{count($eocs/fhir:EpisodeOfCare)}" nocm="{count($ewocm)}"/>