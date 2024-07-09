xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/*:Appointment[not(*:id/@value)]
for $o in $os
order by $o/*:lastModified/@value/string()
return
    
    concat($o/*:lastModified/@value,' - ',$o/*:start/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
    