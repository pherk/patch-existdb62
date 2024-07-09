xquery version "3.0";

import module namespace encmigr = "http://enahar.org/exist/apps/nabu/encounter-migration" at "../../FHIR/Encounter/encounter-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

for $y in ('invalid', 'planned', 1994 to 2025)
let $ec := collection('/db/apps/nabuEncounter/data/' || $y)
let $es := $ec/fhir:Encounter

let $realm := 'kikl-spz'
return
    for $e in $es
    return
        encmigr:update-1.0-0($e)