xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
let $ecs := collection('/db/apps/nabuEncounter/data')
let $eocp := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value='planned']]
let $eocs :=
    for $eoc in $eocp
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
let $cutoff := xs:string((current-date() - xs:dayTimeDuration("P180D")))
let $sixmonthold :=
                for $eoc in $eocswoe
                let $start := $eoc/@start/string()
                order by $start ascending
                return
                    if ($start < $cutoff)
                    then
                        $eoc
                    else
                        ()
let $result :=
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
            <count>{count($sixmonthold)}</count>
            <older-than date="{$cutoff}">
            {
                subsequence($sixmonthold,1,100)
            }
            </older-than>
        </eoc-without-encs>
    </stats>
let $file := concat('stat-eoc-planned-',tokenize(current-date(),'\+')[1],'.xml')
return
(
    system:as-user("admin","kikl968", (
            xmldb:store("/db/apps/nabu/statistics/evals", $file, $result)
            , sm:chmod(xs:anyURI("/db/apps/nabu/statistics/evals" || '/' || $file), "rwxrw-r--")
            , sm:chgrp(xs:anyURI("/db/apps/nabu/statistics/evals" || '/' || $file), "spz")
            )
    )
    , $result
)