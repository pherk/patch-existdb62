xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
let $ecs := collection('/db/apps/nabuEncounter/data')
let $eocp := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value='planned']]
let $eocs :=
    for $eoc in subsequence($eocp,40,80)
    let $sref := $eoc/fhir:subject/fhir:reference/@value/string()
    let $start := $eoc/fhir:period/fhir:start/@value/string()
    order by $start descending
    return
    <eoc start="{$start}">
    {
          $eoc/fhir:subject
        , let $es := $ecs/fhir:Encounter[fhir:subject[fhir:reference/@value=$sref]][fhir:status[@value='finished']][fhir:period/fhir:start/@value > $start]
          return
            if (count($es)>0)
            then $es
            else ()
    }
    </eoc>
let $eocswe := $eocs[fhir:Encounter]
let $eocswoe := $eocs[not(fhir:Encounter)]
return
    <stats count="{count($eocp)}">
        <eoc-with-encs>
            <count>{count($eocswe)}</count>
            {
                let $freq := for $eoc in $eocswe
                        return
                            <freq count="{count($eoc/fhir:Encounter)}">
                                {$eoc//fhir:subject}
                            </freq>
                let $dvf := distinct-values($freq/@count)
                return
                    for $f in $dvf
                    order by $f descending
                    return
                    <encs count="{$f}">
                    {
                        $freq[./@count=$f]/fhir:subject
                    }
                    </encs>
            }
        </eoc-with-encs>
        <eoc-without-encs>
            <count>{count($eocswoe)}</count>
            <older-three-month>
            {
                for $eoc in $eocswoe
                let $start := $eoc/@start/string()
                order by $start descending
                return
                    if ($start < xs:string((current-date() - xs:dayTimeDuration("P100D"))))
                    then
                        $eoc
                    else
                        ()
            }
            </older-three-month>
        </eoc-without-encs>
    </stats>