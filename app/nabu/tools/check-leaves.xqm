xquery version "3.0";

declare namespace fhir="http://hl7.org/fhir";

let $os := collection('/db/apps/metisData/data/FHIR/Leaves')/leave[actor/reference[@value='metis/practitioners/u-vkr']]
for $o in $os
order by $o/period/start/@value/string() descending

return
    (:
    concat($o/*:id/@value,'   ',$o/*:start/@value,' : ', string-join($o/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
    
    concat($o/@xml:id,$o/*:period/*:start/@value, ' : ', $o/*:period/*:end/@value)
    :)
    $o