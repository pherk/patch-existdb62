xquery version "3.0";

import module namespace eoc = "http://enahar.org/exist/apps/nabu/eoc" at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare.xqm";

declare namespace fhir= "http://hl7.org/fhir";
(:
[*:member] 
[*:participant/*:participant]
:)
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:careManager[fhir:reference/@value='']]
let $cts := collection('/db/apps/nabuCom/data/CareTeams')/fhir:CareTeam
let $cnt := for $eoc in $eocs
    let $tid := substring-after($eoc/fhir:team/fhir:reference/@value,'nabu/careteams/')
    let $ct := $cts/../fhir:CareTeam[fhir:id[@value=$tid]]
    return
        if ($ct/fhir:participant)
        then
            $eoc
        else ()
return
    $cnt