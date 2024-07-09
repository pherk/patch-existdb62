xquery version "3.0";

import module namespace ordermigr = "http://enahar.org/exist/apps/nabu/order-migration"     at "../FHIR/Order/order-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $arole := 'spz-arzt'
let $aid := 'c-9470196f-5c17-416c-9a21-db8530cf6cfd'  (: Fazeli :)
let $narole := 'spz-arzt'
let $naid := ''
let $nadisp := ''
let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $os := $oc/fhir:Order[fhir:detail[fhir:status[@value="active"]][fhir:actor[fhir:reference[@value=concat('metis/practitioners/',$aid)]]]]

let $realm := 'kikl-spz'
 
for $o in $os
return
 
    ordermigr:update-actor($o,$arole,$aid,$narole,$naid,$nadisp)
(: 
return
 distinct-values($os/fhir:detail[fhir:status[@value="active"]]/fhir:actor[fhir:reference[@value=concat('metis/practitioners/',$aid)]]/fhir:role/@value)
:)