xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/*:Appointment[starts-with(*:start/@value,'2016-10-')]
for $o in $os

return
    (:
    concat($o/*:start/@value,' - ',$o/*:end/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
    :)
    if ($o/*:participant/*:actor/*:display/@value='')
    then
    $o
    else ()