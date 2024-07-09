xquery version "3.1";

(:~
 : Eoc/CT Kombi, die auf "onhold" oder "waitlist" steht, auf "active" oder "completed" setzen
 : die beiden status sind illegal, da sie beim Laden des Patienten nicht mitgeladen werden
 :)

declare namespace fhir= "http://hl7.org/fhir";

let $status := "completed"


let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $eocss := $eocs/fhir:EpisodeOfCare[fhir:status[@value=("onhold","waitlist")]]
return
<eoc-status>
{
    for $e in $eocss
    return
        let $pref  := $e/fhir:subject/fhir:reference/@value/string()
        let $pdisp := $e/fhir:subject/fhir:display/@value/string()
        let $c := $cts/fhir:CareTeam[fhir:id[@value=substring-after($e/fhir:team/fhir:reference/@value,"nabu/careteams/")]]
        let $upd := system:as-user("admin","kikl968",
                (
                    update value $e/fhir:status/@value with $status
                ,   update value $c/fhir:status/@value with $status
                ))
        return
            <patient pref="{$pref}" pdisp="{$pdisp}"/>
}</eoc-status>