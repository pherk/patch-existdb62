xquery version "3.0";
import module namespace patmigr  = "http://enahar.org/exist/apps/nabu/patient-migration" at "../../FHIR/Patient/patient-migration.xqm";
declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuData/data/FHIR/Patients')
let $os := $oc/fhir:Patient
for $o in $os
let $mig := patmigr:update-1.0-1($o)
return
    ()
