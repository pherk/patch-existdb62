xquery version "3.0";

import module namespace r-task     = "http://enahar.org/exist/restxq/nabu/tasks" at "../../FHIR/Task/task-routes.xqm";
import module namespace taskmigr   = "http://enahar.org/exist/apps/nabu/task-migration"    at "../../FHIR/Task/task-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";



 
let $ots := collection('/db/apps/nabuCom/data/Tasks')/fhir:Task[fhir:note/fhir:time[starts-with(@value,'adjust')]]

let $realm := 'kikl-spz'

for $o in $ots

let $new    := taskmigr:repair-0.9($o)

return
    ()
