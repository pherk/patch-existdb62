xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuCom/data/Tasks')/fhir:Task[fhir:for[fhir:reference/@value='nabu/patients/p-26995']]
for $o in $os
order by $o/fhir:meta/fhir:lastUpdated/@value/string() descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:date/@value,' : ',$o/fhir:meta/fhir:lastUpdated/@value,'   ', $o/*:extension//*:code/@value)
    :)
    $o