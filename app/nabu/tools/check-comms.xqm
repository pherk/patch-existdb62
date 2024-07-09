xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuCommunication/data/2024')/fhir:Communication[fhir:subject[fhir:reference/@value='nabu/patients/p-e9d903e9-c221-4c95-90f1-ea25199f25b9']]
for $o in $os
order by $o/fhir:lastModified/@value descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:subject/*:display/@value,' : ',  ' ', $o/*:lastModified/@value,$o/*:lastModifiedBy/*:display/@value, '   ', $o/*:status/@value)
    :)
    $o