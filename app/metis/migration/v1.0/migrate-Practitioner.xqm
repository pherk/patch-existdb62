xquery version "3.0";
import module namespace practmigr  = "http://enahar.org/exist/apps/metis/practitioner-migration" at "../../FHIR/Practitioner/practitioner-migration.xqm";
declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/metisData/data/FHIR/Practitioners')

let $os := $oc/fhir:Practitioner[fhir:specialty]
for $o in $os
return
    practmigr:migrate-1.0-7($o) 
