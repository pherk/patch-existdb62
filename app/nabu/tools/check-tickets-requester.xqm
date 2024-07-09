xquery version "3.0";
import module namespace r-practrole      = "http://enahar.org/exist/restxq/metis/practrole"
                       at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
declare namespace fhir= "http://hl7.org/fhir";

let $u := r-practrole:userByAlias("newelingf")
let $oldref := concat('metis/practitioners/',$u/fhir:id/@value)
let $newref := $u/fhir:practitioner/fhir:reference/@value/string()

let $os := collection('/db/apps/nabuCom/data/Tasks')/fhir:Task[fhir:requester/fhir:agent[fhir:reference/@value=$oldref]]
for $o in $os
order by $o/fhir:meta/fhir:lastUpdated/@value/string() descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:date/@value,' : ',$o/fhir:meta/fhir:lastUpdated/@value,'   ', $o/*:extension//*:code/@value)
    :)
    $o