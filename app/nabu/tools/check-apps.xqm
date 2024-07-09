xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/fhir:Appointment[fhir:start[starts-with(@value,'2017-03-08T13:30')]]
for $o in $os

return

    concat($o/*:start/@value,' - ',$o/*:end/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
