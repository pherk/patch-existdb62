xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuCommunication/data/2020')/fhir:Communication[fhir:lastModified/@value > '2020-09-23T14:00:00'][fhir:lastModified/@value < '2020-09-23T15:00:00']
for $o in $os
let $s := $o/fhir:status/@value/string()
return
    if ($s='printed')
    then
          system:as-user("vdba", "kikl823!",
            (
                update value $o/fhir:status/@value with 'printing'
            ))
    else ()