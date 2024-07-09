xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/metisData/data/FHIR/PractitionerRoles')/fhir:PractitionerRole[fhir:practitioner/fhir:display[starts-with(@value,'Emmel')]]
for $o in $os
return
 $o