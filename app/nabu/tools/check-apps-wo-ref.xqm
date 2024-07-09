xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/*:Appointment[starts-with(*:start/@value,'2016-11')]
for $o in $os

return
        if ($o//*:actor[*:reference/@value=''])
    then
    concat($o/*:start/@value,' - ',$o/*:end/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
    else ()
    