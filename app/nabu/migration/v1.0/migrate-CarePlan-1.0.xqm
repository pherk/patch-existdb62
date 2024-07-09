xquery version "3.0";

import module namespace cpmigr = "http://enahar.org/exist/apps/nabu/careplan-migration" at "../../FHIR/CarePlan/careplan-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $cc := collection('/db/apps/nabuCom/data/CarePlans')
let $cs := $cc/fhir:CarePlan

let $realm := 'kikl-spz'

for $c in $cs
return
    cpmigr:update-1.0-1($c)