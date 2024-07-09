xquery version "3.0";
import module namespace r-practrole      = "http://enahar.org/exist/restxq/metis/practrole"
                       at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
declare namespace fhir= "http://hl7.org/fhir";

let $id := r-practrole:userByAlias("lombardol")/fhir:id/@value/string()

let $pid := concat('metis/practitioners/',$id)

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:detail[fhir:actor[fhir:reference[@value=$pid]]][fhir:status[@value="active"]]]
return
    <results id="{$id}">{
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
 $o
 }
 </results>