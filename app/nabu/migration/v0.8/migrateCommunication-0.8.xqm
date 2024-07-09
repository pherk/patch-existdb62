xquery version "3.0";

import module namespace commigr = "http://enahar.org/exist/apps/nabu/communication-migration"     at "../../FHIR/Communication/communication-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $ec := collection('/db/apps/nabuCom/data/Communications')
let $es := $ec/fhir:Communication

let $realm := 'kikl-spz'

for $c in $es
return
    commigr:update-0.8($c)

