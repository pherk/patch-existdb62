xquery version "3.0";

import module namespace ordermigr = "http://enahar.org/exist/apps/nabu/order-migration"     at "../FHIR/Order/order-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $arole := 'spz-psychsom'
(: let $aid := 'c-aac943f0-1079-463e-921b-ce5fce1ba4d7'  Dörwald :)
(: let $aid := 'c-b0c1f929-31b4-40dc-a0db-f0254fa6bb08'  Többens :)
(: let $aid := 'c-16b02c4f-a087-4eda-ab0b-529d077fbc4d'  Köther :)
(: let $aid := 'c-f6a73455-6047-4668-add9-c8b9fd2259de'  Kornmann :)
let $aid := 'c-f6a73455-6047-4668-add9-c8b9fd2259de'  (: Kornmann :)
let $narole := 'spz-psychsom'
let $naid := 'c-d29d4255-bd02-4474-81dd-fba512143824'
let $nadisp := 'Ruthe, Amelie'
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