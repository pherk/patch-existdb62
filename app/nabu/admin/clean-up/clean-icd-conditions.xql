xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";
(:~
 : Achtung: legt ohne Index den Server lahm!!!
 : mit Index eine Minute pro 10.000
 :)
let $cs := collection('/db/apps/nabuCom/data/Conditions')/fhir:Condition[fhir:code/fhir:coding[fhir:system[@value="http://hl7.org/fhir/sid/icd-10-de"]]/fhir:code/@value!='']
for $c in $cs
let $icd := $c/fhir:code/fhir:coding[fhir:system[@value="http://hl7.org/fhir/sid/icd-10-de"]]/fhir:code/@value
return
    if (starts-with($icd,"#icd10-"))
    then
        let $sicd := substring-after($icd,"#icd10-")
        let $ssicd := if (contains($sicd,")"))
            then substring-before($sicd,")")
            else $sicd
        return
            system:as-user('vdba', 'kikl823!',
            (
             update value $c/fhir:code/fhir:coding[fhir:system[@value='http://hl7.org/fhir/sid/icd-10-de']]/fhir:code/@value with 
                $ssicd
            ))
    else ()