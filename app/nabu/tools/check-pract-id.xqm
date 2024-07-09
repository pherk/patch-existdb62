xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/metisData/data/FHIR/PractitionerRoles')/fhir:PractitionerRole[fhir:id[@value="c-1cc82a28-bb71-45ff-aacb-07370f39da0c"]]
for $o in $os
return
 $o