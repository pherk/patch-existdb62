xquery version "3.0";

let $os := collection('/db/apps/metisData/data/FHIR/Leaves')/*:leave[starts-with(*:actor/*:display/@value,'Wunram')]
for $o in $os
order by $o/*:period/*:start/@value/string() descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:start/@value,' : ', string-join($o/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
    :)
    concat($o/@xml:id,', : ',$o/*:period/*:start/@value, ' : ', $o/*:period/*:end/@value)