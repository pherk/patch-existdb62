xquery version "3.0";

import module namespace eoc = "http://enahar.org/exist/apps/nabu/eoc" at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare.xqm";

declare namespace fhir= "http://hl7.org/fhir";
(:
[*:member] 
[*:participant/*:participant]
:)
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value='active']]
let $cts := collection('/db/apps/nabuCom/data/CareTeams')/fhir:CareTeam
for $eoc in $eocs[1]
let $tid := substring-after($eoc/fhir:team/fhir:reference/@value,'nabu/careteams/')
let $ct := $cts[fhir:id[@value=$tid]]
return
    if ($ct)
    then 
        let $cm := eoc:careManager($ct/fhir:participant)
        return
            if ($cm/fhir:reference)
            then
                let $upd := system:as-user('vdba', 'kikl823!', 
                    update replace $eoc/fhir:careManager
                        with 
                            <careManager xmlns="http://hl7.org/fhir">
                                { $cm/fhir:reference }
                                { $cm/fhir:display }
                            </careManager>
                    )
                return
                    $cm
            else
                <error>{$ct}</error>
    else
        <error>{$eoc}</error>