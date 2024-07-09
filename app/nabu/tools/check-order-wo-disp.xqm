xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/*:Order[starts-with(*:extension//*:code/@value,"resolved")][*:meta/*:versionID/@value='1']
for $o in $os
order by $o/*:detail[1]/*:proposal/*:start/@value/string() descending
return
    (:
    concat($o/*:id/@value,'   ',$o/*:date/@value,' : ',$o/*:lastModified/@value,'   ', $o/*:extension//*:code/@value)
    :)
    if ($o/*:detail/*:actor[*:reference/@value!=''][*:display/@value=''])
    then
        $o
    else ()