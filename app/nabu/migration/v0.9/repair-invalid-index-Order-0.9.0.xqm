xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
(: 
 : 
let $os := $oc/fhir:Order[fhir:lastModifiedBy/fhir:reference[@value='metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:lastModifiedBy/fhir:reference/@value with ""
   )
 
let $os := $oc/fhir:Order[fhir:source/fhir:reference[@value='metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:source/fhir:reference/@value with ""
   )

let $os := $oc/fhir:Order[fhir:detail/fhir:actor/fhir:reference[@value='metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:detail/fhir:actor/fhir:reference/@value with ""
   )


let $os := $oc/fhir:Order[fhir:detail/fhir:actor/fhir:reference[starts-with(@value,'metis/practitioners/metis/practitioners/')]]
for $o in $os
let $val := substring-after($o/fhir:detail/fhir:actor/fhir:reference/@value,'metis/practitioners/')
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:detail/fhir:actor/fhir:reference[starts-with(@value,'metis/practitioners/metis/practitioners/')]/@value with $val
   )

let $os := $oc/fhir:Order[fhir:lastModifiedBy/fhir:reference[starts-with(@value,'c-')]]
for $o in $os
let $val := concat('metis/practitioners/',$o/fhir:lastModifiedBy/fhir:reference/@value)
order by $o/fhir:lastModified/@value/string() descending
return
 
   system:as-user('vdba','kikl823!',
        update value $o/fhir:lastModifiedBy/fhir:reference/@value with $val
   )

let $os := $oc/fhir:Order[fhir:detail/fhir:schedule/fhir:reference[@value='enahar/schedules/']]
for $o in $os

order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:detail/fhir:schedule/fhir:reference[@value='enahar/schedules/']/@value with ""
   )
:)

let $os := $oc/fhir:Order[fhir:detail/fhir:schedule/fhir:reference[@value='enahar/schedules/am-spz-gbafg']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:detail/fhir:schedule/fhir:reference[@value='enahar/schedules/am-spz-gbafg']/@value with "amb-spz-gbafg"
   )  