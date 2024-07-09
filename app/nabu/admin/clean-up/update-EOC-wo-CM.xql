xquery version "3.0";
import module namespace eoc      = "http://enahar.org/exist/apps/nabu/eoc"  at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare.xqm";

declare namespace fhir= "http://hl7.org/fhir";

let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:careManager/fhir:reference[@value='']][fhir:status[@value=('planned','active')]]
for $o in $eocs[1]
let $cid := substring-after($o/fhir:team/fhir:reference/@value,'nabu/careteams/')
let $ct := $cts/*:CareTeam[*:id[@value=$cid]]
return
    $ct