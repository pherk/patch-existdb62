xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $id := ''
let $os := collection('/db/apps/nabuCom/data/Tasks')/fhir:Task[fhir:id[@value=$id]]
for $o in $os
return
    (:
    concat($o/*:id/@value,'   ',$o/*:date/@value,' : ',$o/*:lastUpdated/@value,'   ', $o/*:extension//*:code/@value)
    :)
    $o