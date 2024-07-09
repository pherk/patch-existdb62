xquery version "3.0";


import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-encounter    = "http://enahar.org/exist/restxq/nabu/encounters"    at "../FHIR/Encounter/encounter-routes.xqm";
import module namespace r-appointment  = "http://enahar.org/exist/restxq/nabu/appointments"  at "../FHIR/Appointment/appointment-routes.xqm";
import module namespace r-patient      = "http://enahar.org/exist/restxq/nabu/patients"       at "../FHIR/Patient/patient-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";


let $apps := r-appointment:appointmentsXML(
        "","",
        "1","*",
        "","","",
        "",
        "2016-01-01","2016-01-31",
        "fulfilled",
        "date:asc")
for $a in $apps/fhir:Appointment
let $enc := collection('db/apps/nabuData/data/FHIR/Encounter')/fhir:Encounter[fhir:appointment/fhir:reference/@value=$a/fhir:id/@value]
return
    if ($enc)
    then 'ok'
    else 
        let $enc := r-encounter:fillEncounterTemplate($a)
        return
            r-encounter:putEncounterXML(document {$enc},"kikl-spz","u-admin","admin")





