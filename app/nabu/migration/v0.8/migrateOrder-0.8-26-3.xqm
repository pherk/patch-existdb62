xquery version "3.0";

import module namespace ordermigr = "http://enahar.org/exist/apps/nabu/order-migration"     at "../../FHIR/Order/order-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $os := $oc/fhir:Order

let $realm := 'kikl-spz'

for $o in $os
return
    ordermigr:update-0.8-26-3($o)