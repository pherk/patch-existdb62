xquery version "3.0";

import module namespace r-task     = "http://enahar.org/exist/restxq/nabu/tasks" at "../../FHIR/Task/task-routes.xqm";
import module namespace taskmigr   = "http://enahar.org/exist/apps/nabu/task-migration"    at "../../FHIR/Task/task-migration.xqm";

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
 
let $ots := collection('/db/apps/nabuData/data')/fhir:Order[*:reason/*:coding/*:code/@value='task']

let $realm := 'kikl-spz'

for $o in $ots

let $new    := taskmigr:order2task($o)
let $loguid := local:substring-after-if(local:substring-after-if($o/fhir:lastModifiedBy/fhir:reference/@value,'metis/practitioners/'),'metis/practitioners/')
let $lognam := $o/fhir:lastModifiedBy/fhir:display/@value/string()

let $store  := r-task:putTask(<content>{$new}</content>, $realm, $loguid, $lognam)
return
    ()
