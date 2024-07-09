xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $aes0 := collection('/db/apps/nabuCom/data/CarePlans')/fhir:CarePlan[fhir:activity[fhir:reference/fhir:reference[@value='']]]
let $aes1 := collection('/db/apps/nabuCom/data/CarePlans')/fhir:CarePlan[fhir:activity[not(fhir:detail) and not(fhir:reference)]]
for $o in ($aes0,$aes1)
order by $o/fhir:id/@value/string() descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:subject/*:reference/@value,':',$o/*:subject/*:display/@value,' : ',  ' ', $o/*:lastModified/@value,$o/*:lastModifiedBy/*:display/@value, '   ', $o/*:status/@value)
    :)
    let $upd := system:as-user("vdba","kikl823!",
                (
                  update delete $o/fhir:activity[fhir:reference/fhir:reference[@value='']][fhir:reference/fhir:display/@value=('NewOrder','NewTask')]
                , update delete $o/fhir:activity[not(fhir:detail) and not(fhir:reference)]
                ))
    return
        <deleted/>
        