xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $pref := concat('nabu/patients/', 'p-b64c292d-471c-4e81-a38f-39f474179a25')
let $os := collection('/db/apps/nabuCom/data/Goals')/fhir:Goal[fhir:subject/fhir:reference[@value=$pref]]
for $o in $os
return
    (:
    concat($o/*:id/@value,'   ',$o/*:date/@value,' : ',$o/*:lastUpdated/@value,'   ', $o/*:extension//*:code/@value)
    :)
    $o