xquery version "3.1";

import module namespace patmigr  = "http://enahar.org/exist/apps/nabu/patient-migration"         at "../../FHIR/Patient/patient-migration.xqm";
import module namespace patutils = "http://enahar.org/exist/apps/nabu/patutils"                  at "../../FHIR/Patient/patutils.xqm";
import module namespace r-respon = "http://enahar.org/exist/restxq/nabu/patient-responsibility"  at "../../FHIR/Patient/responsibility-routes.xqm";
import module namespace r-ct     = "http://enahar.org/exist/restxq/nabu/careteams"               at "../../FHIR/CareTeam/careteam-routes.xqm";
import module namespace r-eoc    = "http://enahar.org/exist/restxq/nabu/eocs"                    at "../../FHIR/EpisodeOfCare/episodeofcare-routes.xqm";
import module namespace ctt      = "http://enahar.org/exist/apps/nabu/ct-template"               at "../../FHIR/CareTeam/ct-template.xqm";
import module namespace eoct     = "http://enahar.org/exist/apps/nabu/eoc-template"              at "../../FHIR/EpisodeOfCare/eoc-template.xqm";
import module namespace eoc      = "http://enahar.org/exist/apps/nabu/eoc"                       at "../../FHIR/EpisodeOfCare/episodeofcare.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare function local:lastEncounter($ps as element(fhir:participant)*) as xs:dateTime?
{
    if ($ps)
    then max(for $p in $ps return xs:dateTime($p/fhir:period/fhir:end/@value/string()))
    else ()
};

declare function local:firstEncounter($ps as element(fhir:participant)*) as xs:dateTime?
{
    if ($ps)
    then min(for $p in $ps return xs:dateTime($p/fhir:period/fhir:start/@value/string()))  
    else ()
};

let $ec := collection('/db/apps/nabuData/data/FHIR/Patients')
let $es := $ec/fhir:Patient[fhir:id[@value="p-5476"]]

let $realm := 'kikl-spz'
let $now := current-dateTime()
for $patient in $es

let $mig := patmigr:update-0.9-00($patient)
return
    ()