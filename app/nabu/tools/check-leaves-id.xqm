xquery version "3.0";

declare namespace fhir="http://hl7.org/fhir";

let $id := 'l-f01632a9-0200-4003-bd0d-ed68fa48625e'

let $os := collection('/db/apps/metisData/data/FHIR/Leaves')/*:leave[*:id[@value=$id]]
for $o in $os

return
    $o