xquery version "3.0";

import module namespace eoc = "http://enahar.org/exist/apps/nabu/eoc" at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare.xqm";

declare namespace fhir= "http://hl7.org/fhir";
(:
[*:member] 
[*:participant/*:participant]
:)
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value=('planned','waitlist')]][fhir:careManager[fhir:reference/@value!='']]

let $cnt := for $eoc in $eocs
        let $upd := system:as-user('vdba', 'kikl823!', 
                    update value $eoc/fhir:status/@value
                        with 'active'
                    )
        return
            ()
return
    $cnt