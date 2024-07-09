xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $pid := concat("nabu/patients/", "p-705753f7-ade1-41e5-8fd8-3d3a424e80a1")

let $os := collection('/db/apps/nabuCom/data/CarePlans')/fhir:CarePlan[fhir:subject[fhir:reference/@value=$pid]]
for $o in $os
order by $o/fhir:id/@value/string() descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:subject/*:display/@value,' : ',  ' ', $o/*:lastModified/@value,$o/*:lastModifiedBy/*:display/@value, '   ', $o/*:status/@value)
    :)
    $o