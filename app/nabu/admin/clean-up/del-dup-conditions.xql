xquery version "3.0";
declare namespace fhir = "http://hl7.org/fhir";

declare function local:delDups($dx, $hits-with-dx as element(fhir:Condition)*)
{
            if (count($hits-with-dx)>1) (: dup found :)
            then
                let $hits-sorted := for $h in $hits-with-dx
                    order by $h/fhir:assertedDate/@value
                    return
                        $h
                let $dels := subsequence($hits-sorted,2)
                for $del in $dels
                let $file := concat($del/@xml:id,'.xml')
                return
                    system:as-user('vdba','kikl823!',
                            xmldb:remove('/db/apps/nabuCom/data/Conditions',$file)
                        )
            else
                ()
};

declare function local:longestCommonPrefix()
{
    (: retain prefix code
        lcstr xs ys = maximumBy (compare `on` length) . concat $ [f xs' ys | xs' <- tails xs] ++ [f xs ys' | ys' <- drop 1 $ tails ys]
        where f xs ys = scanl g [] $ zip xs ys
              g z (x, y) = if x == y then z ++ [x] else []
    :)

        ()
};

declare function local:delMissingICD($hits-wo-icd as element(fhir:Condition)*)
{
    let $dxtxt   := distinct-values($hits-wo-icd/fhir:code/fhir:text/@value)
    for $dx in $dxtxt
    return
        if (string-length(normalize-space($dx))>0)
        then
            let $hits-with-dx := $hits-wo-icd/../fhir:Condition[fhir:code/fhir:text/@value = $dx]
            return
                local:delDups($dx, $hits-with-dx)
        else
            ()
};

declare function local:delDupConditions($hits as element(fhir:Condition)*)
{
    let $dxicd   := distinct-values(
        for $h in $hits/fhir:code//fhir:code/@value
        return
            replace($h,'\)','')
    )
    (: retain prefix code    :)
    let $icds := for $icd in $dxicd
        return
            if (count($dxicd[.!=$icd][starts-with($icd,.)])>1)
            then ()
            else $icd
    for $dx in $icds
    let $hits-with-dx := if (string-length($dx)>0)
        then $hits[starts-with(fhir:code//fhir:code/@value,$dx)]
        else $hits[fhir:code//fhir:code/@value=$dx]
    return
        if (string-length(normalize-space($dx))>0)
        then
            local:delDups($dx,$hits-with-dx)
        else
            local:delMissingICD($hits-with-dx)
};

let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')
let $os := collection('/db/apps/nabuCom/data/Conditions')
let $code := 'diagnosis'
let $veri := 'unknown'

for $p in $ps
let $sref    := concat('nabu/patients/',$p/fhir:Patient/fhir:id/@value)
let $disp := string-join(($p/fhir:Patient/fhir:name/fhir:family/@value,$p/fhir:Patient/fhir:name/fhir:given/@value, $p/fhir:Patient/fhir:birthDate/@value),', ')
let $lll := util:log-system-out(concat($sref,' - ', $disp))
let $sc      := $os/fhir:Condition[fhir:subject[fhir:reference/@value=$sref]]
let $hits    := $sc/../fhir:Condition[fhir:verificationStatus[@value=$veri]][fhir:category//fhir:code[@value=$code]]
return
    local:delDupConditions($hits)