xquery version "3.0";

import module namespace ordermigr = "http://enahar.org/exist/apps/nabu/order-migration"     at "../../FHIR/Order/order-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $os := $oc/fhir:Order
let $ec := collection('/db/apps/nabuEncounter/data')
let $realm := 'kikl-spz'

for $o in $os
let $eps := $ec/fhir:Encounter[fhir:appointment[fhir:reference[starts-with(@value,concat('nabu/orders/',$o/@id/@value))]]]
return
    ordermigr:update-0.8-26($o, $eps)
    
