xquery version "3.0";
import module namespace ordermigr  = "http://enahar.org/exist/apps/nabu/order-migration" at "../../FHIR/Order/order-migration.xqm";
declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $os := $oc/fhir:Order
for $o in $os
let $mig := ordermigr:update-0.9-5($o)
return
    ()
