xquery version "3.0";

import module namespace ctmigr = "http://enahar.org/exist/apps/nabu/careteam-migration" at "../../FHIR/CareTeam/careteam-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $cc := collection('/db/apps/nabuCom/data/CareTeams')
let $cs := $cc/fhir:CareTeam

let $realm := 'kikl-spz'

for $c in $cs
return
    ctmigr:update-1.0-2($c)