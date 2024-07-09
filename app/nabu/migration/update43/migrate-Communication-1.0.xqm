xquery version "3.0";

import module namespace r-comm   = "http://enahar.org/exist/restxq/nabu/communications"        at "../../FHIR/Communication/communication-routes.xqm";
import module namespace commigr = "http://enahar.org/exist/apps/nabu/communication-migration" at "../../FHIR/Communication/communication-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

for $y in (2016 to 2026, 'invalid')
let $cc := collection('/db/apps/nabuCommunication/data/' || $y)
let $cs := $cc/fhir:Communication

let $realm := 'kikl-spz'
return
    for $c in $cs
    return
        commigr:update-1.0-0($c)