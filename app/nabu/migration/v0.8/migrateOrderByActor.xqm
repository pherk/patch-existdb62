xquery version "3.0";

import module namespace ordermigr = "http://enahar.org/exist/apps/nabu/order-migration"     at "../../FHIR/Order/order-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $arole := 'spz-psychsom'
let $aref := concat('metis/practitioners/','c-aac943f0-1079-463e-921b-ce5fce1ba4d7')
let $narole := 'spz-psychsom'
let $naref := ''
let $nadisp := ''
let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $os := $oc/fhir:Order[fhir:detail/fhir:actor[fhir:reference[@value=$aref]]]

let $realm := 'kikl-spz'

for $o in $os[1]
return
    ordermigr:update-actor($o,$arole,$aref,$narole,$naref,$nadisp)