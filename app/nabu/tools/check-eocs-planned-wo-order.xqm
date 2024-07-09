xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $eoc := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $eps := $eoc/fhir:EpisodeOfCare[fhir:status[@value='planned']]

let $ess := for $eoc in $eps
    let $sref := $eoc/fhir:subject/fhir:reference/@value
    order by $eoc/fhir:period/fhir:start/@value/string() 
    return
        let $os := $oc/fhir:Order[fhir:subject[fhir:reference[@value=$sref]]]
        let $hasOrder := count($os)>0
        return
        if ($hasOrder)
        then ()
        else
            <eoc start="{$eoc/fhir:period/fhir:start/@value/string()}">
                {
                    $eoc/fhir:subject
                }
            </eoc>
return
<eocwocm>{$ess}</eocwocm>