xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/*:Appointment[*:id/@value="a-ac9f8ecc-34bb-4729-a8db-3d9b8f0fd41c"]
for $o in $os
return
    
    $o