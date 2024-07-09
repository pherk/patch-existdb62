xquery version "3.0";

import module namespace r-encounter  = "http://enahar.org/exist/restxq/nabu/encounters"       at "../../FHIR/Encounter/encounter-routes.xqm";
import module namespace encmigr      = "http://enahar.org/exist/apps/nabu/encounter-migration"     at "../../FHIR/Encounter/encounter-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";


declare function local:substring-after-if
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string? {

   if (contains($arg,$delim))
   then substring-after($arg,$delim)
   else $arg
 } ;
 
let $ec := collection('/db/apps/nabuData/data/FHIR/Appointments')
let $es := $ec/fhir:Appointment[fhir:status[@value!='fulfilled']]

let $realm := 'kikl-spz'

for $e in $es

let $new    := encmigr:a2e($e)
let $loguid := local:substring-after-if(local:substring-after-if($e/fhir:lastModifiedBy/fhir:reference/@value,'metis/practitioners/'),'metis/practitioners/')
let $lognam := $e/fhir:lastModifiedBy/fhir:display/@value/string()

let $store  := r-encounter:putEncounter(<content>{$new}</content>, $realm, $loguid, $lognam)

return
    ()

