xquery version "3.0";


let $cs := collection('/db/apps/nabuData/data/FHIR/Communications')
let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/*:Appointment[starts-with(*:start/@value,'2016-09')]
for $a in $os
let $mcs := $cs/*:Communication[*:subject/*:reference/@value=$a/*:participant[*:type/*:coding/*:code/@value='patient']/*:actor/*:reference/@value]
let $dcs := $mcs[starts-with(*:payload//*:item,format-dateTime($a/*:start/@value, "[FNn], [D].[M01].[Y] um ", "de", (), ()))]
return
    if (count($dcs)>0)
    then
        ()
    else
                    concat(
                        $a/*:order/*:reference/@value,
                        ' : ',$a/*:start/@value,' - ',$a/*:end/@value,' : ',
                        string-join($a/*:participant/*:actor/*:display/@value,','), ' ', $a/*:lastModified/@value,'   ', $a/*:status/@value)