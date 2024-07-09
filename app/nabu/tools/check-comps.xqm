xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $pid := concat("nabu/patients/", "p-2b2005f8-208b-483a-8165-394f63358393")

let $os := collection('/db/apps/nabuComposition/data')/fhir:Composition[fhir:subject[fhir:reference/@value=$pid]]
for $o in $os
order by $o//fhir:lastUpdated/@value/string() descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:subject/*:display/@value,' : ',  ' ', $o/*:lastModified/@value,$o/*:lastModifiedBy/*:display/@value, '   ', $o/*:status/@value)
    :)
    $o