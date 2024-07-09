xquery version "3.0";

import module namespace calmigr = "http://enahar.org/exist/apps/eNahar/cal-migration"     at "../../cal/cal-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $ec := collection('/db/apps/eNaharData/data/calendars')
let $es := $ec/cal

let $realm := 'kikl-spz'

for $o in $es
return
    calmigr:update-0.9-specialamb($o)
