xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:status[@value=('active')]]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
    (:
    system:as-user('vdba', 'kikl823!',
    (
        update value $o/fhir:status/@value with 'completed'
    ))
    :)
    <ok/>
