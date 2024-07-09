xquery version "3.1";

let $import-base := "/db/apps/nabuCom/import"
let $error-base  := "/db/apps/nabuCom/errors"
let $comp-base   := "/db/apps/nabuComposition/data"
let $cond-base   := "/db/apps/nabuData/data/FHIR/Conditions"
let $letter-base := "Befunde1912"
let $letters     := collection(concat($import-base,'/',$letter-base))
let $nol         := count($letters)
let $fails       := collection("/db/apps/nabuCom/errors")
let $errors      := $fails/error[starts-with(*:collection,$letter-base)]
let $noe         := count($errors)
let $comps       := collection($comp-base)
let $noss         := count($comps)
let $nofs         := count($fails)
return
    <import-stats>
       <total>
        <success>{$noss}</success>
        <fail>{$nofs}</fail>
       </total>
        <collection>{$letter-base}</collection>
        <letter-collection>
            <no>{$nol}</no>
        </letter-collection>
        <errors>
            <no>{$noe}</no>
            <subjects>
                <no>{count($errors[subjects])}</no>
                <patient>{count($errors[subjects]/subjects[starts-with(error,'patient')])}</patient>
            </subjects>
            <physician>{count($errors[physician])}</physician>
            <authors>{count($errors[authors])}</authors>
        </errors>
    </import-stats>