xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";


let $year := '2023'
let $cs := collection('/db/apps/nabuComposition/data/' || $year)
let $ss := distinct-values($cs//fhir:subject/fhir:reference/@value/string())
for $pat in $ss
let $c := $cs/fhir:Composition[fhir:subject[fhir:reference/@value=$pat]]
return
    if (count($c) > 1)
    then (: check if possible dups :)
        let $paths := distinct-values($c/fhir:section/fhir:code/fhir:text/@value/string())
        return
            if (count($c)>count($paths))
            then
                for $p in $paths
                let $cp := $c/../fhir:Composition[fhir:section/fhir:code/fhir:text/@value=$p]
                return
                    if (count($cp)>1)
                    then
                        let $file := concat($cp[1]/@xml:id,'.xml')
                        return
                           system:as-user('vdba','kikl823!', xmldb:remove('/db/apps/nabuComposition/data/' || $year, $file))
                        (: $cp[1]/@xml:id/string() :)
                    else ()
            else ()
    else ()