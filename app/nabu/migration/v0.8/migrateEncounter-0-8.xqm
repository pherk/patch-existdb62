xquery version "3.0";

import module namespace r-encounter  = "http://enahar.org/exist/restxq/nabu/encounters"       at "../../FHIR/Encounter/encounter-routes.xqm";
import module namespace encmigr      = "http://enahar.org/exist/apps/nabu/encounter-migration"     at "../../FHIR/Encounter/encounter-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $ec := collection('/db/apps/nabuData/data/FHIR/Encounters')
let $es := $ec/fhir:Encounter

let $realm := 'kikl-spz'

for $o in $es
return
    encmigr:update-0.8($o)