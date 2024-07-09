xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/metisData/data/FHIR/Practitioners')/fhir:Practitioner[fhir:role/fhir:coding/fhir:code[@value='kikl-spz']]
for $o in $os
return
    (:
    concat($o/*:id/@value,'   ',$o/*:start/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
    :)
    if ($o/fhir:name[fhir:use/@value='official'])
    then ()
    else
        $o/fhir:name/fhir:family/@value/string() 