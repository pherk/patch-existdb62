
xquery version "3.0";


import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-appointment = "http://enahar.org/exist/restxq/nabu/appointments"  at "../FHIR/Appointment/appointment-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "/db/apps/metis/FHIR/Practitioner/practitioner-routes.xqm";
import module namespace r-organization = "http://enahar.org/exist/restxq/metis/organizations"  at "/db/apps/metis/FHIR/Organization/organization-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

(: check import of events :)
let $worker   := collection($config:nabu-imports)/dataroot/Abk_Erbringer
let $events   := collection($config:nabu-imports)/dataroot/Termine
let $patients := collection($config:nabu-imports)/dataroot/Patienten
let $wl       := collection($config:nabu-imports)/dataroot/T_WartelisteNeu
let $dates    := collection($config:nabu-imports)/dataroot/Datum
let $db-e := collection($config:nabu-encounters)
let $db-a := collection($config:nabu-appointments)
let $db-p := collection($config:nabu-patients)
let $db-o := collection($config:nabu-orders)
let $os := $db-o/fhir:Order[fhir:reason/fhir:coding/fhir:code/@value='appointment'][fhir:source/fhir:reference/@value="metis/practitioners/u-admin"][fhir:extension//fhir:code/@value/string() != 'assigned']
return
    count($os)
    