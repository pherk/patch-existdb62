xquery version "3.0";


import module namespace devmigr = "http://enahar.org/exist/apps/metis/device-migration" at "/db/apps/metis/FHIR/Device/device-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $cc := collection('/db/apps/metisData/data/FHIR/Devices')
let $cs := $cc/fhir:Device

let $realm := 'kikl-spz'

for $c in $cs
return
    devmigr:update-0.9($c)