xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:id[@value="o-b4bf8226-5d3d-4d7d-866e-95d3e0e601a5"]]
for $o in $os

return
    (:
    concat($o/*:id/@value,'   ',$o/*:date/@value,' : ',$o/*:lastModified/@value,'   ', $o/*:extension//*:code/@value)
    :)
    $o