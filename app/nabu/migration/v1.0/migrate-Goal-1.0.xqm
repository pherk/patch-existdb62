xquery version "3.0";
import module namespace goalmigr  = "http://enahar.org/exist/apps/nabu/goal-migration" at "../../FHIR/Goal/goal-migration.xqm";
declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuCom/data/Goals')
let $os := $oc/fhir:Goal
for $o in $os
let $mig := goalmigr:update-1.0-5($o)
return
    ()
