xquery version "3.0";

import module namespace consmigr = "http://enahar.org/exist/apps/nabu/consent-migration" at "../../FHIR/Consent/consent-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $cc := collection('/db/apps/nabuCom/data/Consents')
let $cs := $cc/fhir:Consent

let $realm := 'kikl-spz'

for $c in $cs
return
    consmigr:update-1.0-1($c)