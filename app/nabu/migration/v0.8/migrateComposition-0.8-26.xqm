xquery version "3.0";

import module namespace compmigr = "http://enahar.org/exist/apps/nabu/composition-migration"     at "../../FHIR/Composition/composition-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $ec := collection('/db/apps/nabuCom/data/Compositions')
let $es := $ec/fhir:Composition

let $realm := 'kikl-spz'

for $c in $es
return
    compmigr:update-0.8-26($c)
