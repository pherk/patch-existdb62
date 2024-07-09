xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $ocs := collection('/db/apps/nabuData/data/FHIR/Orders')
let $eoccs := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $os := $ocs/fhir:Order[fhir:status[@value='active']]

let $owoeocs := for $o in $os

        let $pref := $o/fhir:subject/fhir:reference/@value/string()
        let $eoc := $eoccs/fhir:EpisodeOfCare[fhir:subject[fhir:reference/@value=$pref]]
        order by $o/fhir:date/@value/string()
        return
            if ($eoc/fhir:status[@value=('active','planned','finished')])
            then ()
            else
                <order date="{$o/fhir:date/@value/string()}">
                    {$o/fhir:subject}
                    {$eoc/fhir:status}
                </order>

let $result :=
    <stats count="{count($owoeocs)}">
        {$owoeocs}
    </stats>
let $file := concat('order-wo-active-eoc-',tokenize(current-date(),'\+')[1],'.xml')

return
( 

    system:as-user("vdba","kikl823!", (
            xmldb:store("/db/apps/nabu/statistics/evals", $file, $result)
            , sm:chmod(xs:anyURI("/db/apps/nabu/statistics/evals" || '/' || $file), "rwxrw-r--")
            , sm:chgrp(xs:anyURI("/db/apps/nabu/statistics/evals" || '/' || $file), "spz")
            )
    )
    , 
       $result
)
