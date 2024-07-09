xquery version "3.0";

import module namespace patmigr = "http://enahar.org/exist/apps/nabu/patient-migration"     at "../../FHIR/Patient/patient-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $ec := collection('/db/apps/nabuData/data/FHIR/Patients')
let $es := $ec/fhir:Patient

let $realm := 'kikl-spz'

for $patient in $es
return
    patmigr:update-0.8($patient) 