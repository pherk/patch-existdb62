xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuEncounter/data/')/fhir:Encounter[fhir:id[@value='e-4d0442f9-ef1d-4f9f-8d17-5f4172b68c33']]
for $o in $os
order by $o/fhir:lastModified/@value/string()
return
    (:
    concat($o/*:lastModified/@value,' - ',$o/*:period/*:start/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:status/@value)
    :)
    util:collection-name($o)
    