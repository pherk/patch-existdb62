xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/*:Order[*:extension//*:code/@value/string() = 'resolved'][*:detail/*:proposal/*:acq/@value/string() = 'open']
for $o in $os
order by $o/*:subject/*:display/@value/string() 
return
    string-join(($o/*:id/@value,$o/*:date/@value,$o/*:lastModified/@value,$o/*:subject/*:display/@value,$o/*:detail/*:actor/*:display/@value),' : ')