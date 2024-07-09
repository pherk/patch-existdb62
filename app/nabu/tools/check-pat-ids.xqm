xquery version "3.0";

import module namespace r-patient      = "http://enahar.org/exist/restxq/nabu/patients"       at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";
declare namespace fhir= "http://hl7.org/fhir";

let $ps := r-patient:patients("kikl-spz", "u-admin", "1","*", 'Witt',  "Levin", "", "", "true")//fhir:Patient
for $p in $ps
let $id    := $p/fhir:id/@value
let $name  := $p/fhir:name/fhir:family/@value
let $given := $p/fhir:name/fhir:given/@value
let $bd    := $p/fhir:birthDate/@value
return
    string-join(($id,$name,$given,$bd),':')

