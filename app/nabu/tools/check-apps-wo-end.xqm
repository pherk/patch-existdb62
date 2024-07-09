xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/*:Appointment[*:start/@value>'2016-01-01T08:00:00']
for $o in $os
order by $o/*:start/@value/string()
return
    (:
    concat($o/*:start/@value,' - ',$o/*:end/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
    :)
    $o/@xml:id/string()