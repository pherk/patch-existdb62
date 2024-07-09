xquery version "3.0";
import module namespace prmigr  = "http://enahar.org/exist/apps/metis/pr-migration" at "../../FHIR/PractitionerRole/practitionerrole-migration.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole" at "../../FHIR/PractitionerRole/practitionerrole-routes.xqm";
declare namespace fhir= "http://hl7.org/fhir";


let $ps := collection('/db/apps/metisData/data/FHIR/Practitioners')
let $prs := collection('/db/apps/metisData/data/FHIR/PractitionerRoles')

 
for $pr in $prs/fhir:PractitionerRole
let $pid := substring-after($pr/fhir:practitioner/fhir:reference/@value,'metis/practitioners/')

let $mig := prmigr:update-1.0-2($pr,$pid)
return
    $mig




