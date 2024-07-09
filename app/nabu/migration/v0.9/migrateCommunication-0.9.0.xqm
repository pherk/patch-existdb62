xquery version "3.0";

import module namespace r-comm   = "http://enahar.org/exist/restxq/nabu/communications"        at "../../FHIR/Communication/communication-routes.xqm";
import module namespace commigr = "http://enahar.org/exist/apps/nabu/communication-migration" at "../../FHIR/Communication/communication-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $cc := collection('/db/apps/nabuCom/data/Communications')
let $cs := $cc/fhir:Communication

let $realm := 'kikl-spz'

for $c in $cs
return
    commigr:update-0.9($c)