xquery version "3.0";


import module namespace locmigr = "http://enahar.org/exist/apps/metis/location-migration" at "/db/apps/metis/FHIR/Location/location-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $cc := collection('/db/apps/metisData/data/FHIR/Locations')
let $cs := $cc/fhir:Device

let $realm := 'kikl-spz'

for $c in $cs
return
    locmigr:update-0.9($c)