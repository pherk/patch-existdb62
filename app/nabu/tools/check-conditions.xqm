xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $pref := "nabu/patients/" || "p-af1ac55b-d051-4f51-9dc4-bd6c6884992f"
let $os := collection('/db/apps/nabuCom/data/Conditions')/fhir:Condition[fhir:subject[fhir:reference/@value=$pref]]
for $o in $os
order by $o/fhir:assertedDate/@value/string() ascending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:subject/*:display/@value,' : ',  ' ', $o/*:lastModified/@value,$o/*:lastModifiedBy/*:display/@value, '   ', $o/*:status/@value)
    :)
    $o