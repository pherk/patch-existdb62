xquery version "3.0";

import module namespace eocmigr = "http://enahar.org/exist/apps/nabu/episodeofcare-migration" at "../../FHIR/EpisodeOfCare/episodeofcare-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $cc := collection('/db/apps/nabuCom/data/EpisodeOfCares')

let $realm := 'kikl-spz'

for $c in $cc/fhir:EpisodeOfCare
return
    eocmigr:update-1.0-3($c)