xquery version "3.0";
import module namespace eoc      = "http://enahar.org/exist/apps/nabu/eoc"  at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare.xqm";

declare namespace fhir= "http://hl7.org/fhir";

let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:careManager[fhir:reference/@value='']][fhir:status[@value=('active')]]
return
    count($eocs)