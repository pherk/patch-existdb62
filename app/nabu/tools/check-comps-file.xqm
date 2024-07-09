xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $file := "Hausner"

let $os := collection('/db/apps/nabuComposition/data/2018')/fhir:Composition[fhir:section[fhir:code/fhir:coding/fhir:code[matches(@value,$file)]]]
for $o in $os
order by $o/fhir:date/@value/string() descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:subject/*:display/@value,' : ',  ' ', $o/*:lastModified/@value,$o/*:lastModifiedBy/*:display/@value, '   ', $o/*:status/@value)
    :)
    $o