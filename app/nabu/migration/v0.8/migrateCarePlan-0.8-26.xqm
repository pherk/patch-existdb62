xquery version "3.0";

import module namespace cpmigr = "http://enahar.org/exist/apps/nabu/careplan-migration"     at "../../FHIR/CarePlan/careplan-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $cpc := collection('/db/apps/nabuCom/data/CarePlans')
let $cps := $cpc/fhir:CarePlan

let $realm := 'kikl-spz'

for $cp in $cps

return
    cpmigr:update-0.8-26($cp)