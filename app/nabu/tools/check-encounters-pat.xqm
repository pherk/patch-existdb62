xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuEncounter/data/2024')/fhir:Encounter[fhir:subject[fhir:reference/@value='nabu/patients/p-24782']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
    (:
    concat($o/*:lastModified/@value,' - ',$o/*:period/*:start/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:status/@value)
    :)
    $o
    