xquery version "3.0";


declare namespace fhir= "http://hl7.org/fhir";

let $aref := 'metis/practitioners/c-7708e93b-b251-4c7c-9fe5-fd50e084c131'

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[.//fhir:reference[@value=$aref]][starts-with(fhir:lastModified/@value,'2023-06-13')][fhir:status/@value='cancelled'] 
return
    <results>{
for $o in $os
order by $o/*:date/@value/string()
return
    (:
    concat($o/*:id/@value,'   ',$o/*:date/@value,' : ',$o/*:lastModified/@value,'   ', $o/*:extension//*:code/@value)
    :)

    $o/fhir:subject/fhir:display
    }
</results>