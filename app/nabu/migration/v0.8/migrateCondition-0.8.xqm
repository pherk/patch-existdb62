xquery version "3.0";

import module namespace condmigr = "http://enahar.org/exist/apps/nabu/condition-migration"     at "../../FHIR/Condition/condition-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $ec := collection('/db/apps/nabuCom/data/Conditions')
let $es := $ec/fhir:Condition

let $realm := 'kikl-spz'

for $c in $es
return
    condmigr:update-0.8($c)

