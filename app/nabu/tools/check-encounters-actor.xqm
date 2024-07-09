xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";


let $id := 'c-decb9a50-6244-4a77-9c1d-979d14284dc4'
let $id := 'c-b033454e-bb1d-4000-a8d6-13c75b5dd5cd'
let $uref := concat('metis/practitioners/',$id)
let $os := collection('/db/apps/nabuEncounter/data/planned')/fhir:Encounter[fhir:participant/fhir:actor[fhir:reference/@value=$uref]]
for $o in $os
order by $o/fhir:lastModified/@value/string()
return
    (:
    concat($o/*:lastModified/@value,' - ',$o/*:period/*:start/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:status/@value)
    :)
    $o
