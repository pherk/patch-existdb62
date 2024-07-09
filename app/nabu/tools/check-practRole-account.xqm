xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/metisData/data/FHIR/PractitionerRoles')/fhir:PractitionerRole[fhir:identifier[fhir:value/@value='']][fhir:code/fhir:coding/fhir:code[@value='kikl-spz']][fhir:active/@value='false']
for $o in $os
return
 $o