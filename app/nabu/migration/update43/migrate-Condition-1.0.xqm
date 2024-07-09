xquery version "3.0";
import module namespace condmigr  = "http://enahar.org/exist/apps/nabu/condition-migration" at "../../FHIR/Condition/condition-migration.xqm";
declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuCom/data/Conditions')/fhir:Condition


for $o in $oc/../fhir:Condition
let $mig := condmigr:migrate-1.0-7($o)
return
    ()

    