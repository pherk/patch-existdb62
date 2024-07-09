xquery version "3.1";


declare namespace fhir= "http://hl7.org/fhir";

let $now := current-dateTime()
let $realm := 'metis/organizations/kikl-spzn'

let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value=('on-hold')]]
return
    count($eocs)