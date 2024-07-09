xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuData/data/FHIR/Patients')
(: 
 : 
let $os := $oc/fhir:Patient[fhir:lastModifiedBy/fhir:reference[@value='metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:lastModifiedBy/fhir:reference/@value with ""
   )

let $os := $oc/fhir:Patient[fhir:lastModifiedBy/fhir:reference[@value='metis/practitioners/metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:lastModifiedBy/fhir:reference/@value with ""
   )

let $os := $oc/fhir:Patient[fhir:lastModifiedBy/fhir:reference[starts-with(@value,'metis/practitioners/metis/practitioners/')]]
for $o in $os
let $val := substring-after($o/fhir:lastModifiedBy/fhir:reference/@value,'metis/practitioners/')
order by $o/fhir:lastModified/@value/string() descending
return

       system:as-user('vdba','kikl823!',
        update value $o/fhir:lastModifiedBy/fhir:reference/@value with $val
   )
:)

let $os := $oc/fhir:Patient[fhir:careProvider//fhir:reference[starts-with(@value,'c-')]]
for $o in $os
let $val := concat('metis/practitioners/',$o/fhir:careProvider//fhir:reference/@value)
order by $o/fhir:lastModified/@value/string() descending
return

   system:as-user('vdba','kikl823!',
        update value $o/fhir:careProvider//fhir:reference/@value with $val
   )
 