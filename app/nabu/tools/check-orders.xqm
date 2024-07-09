xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $pid := concat('nabu/patients/','p-6c7f1f25-f9bd-4205-b268-4dcb84cc2cc2')

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:subject[fhir:reference[@value=$pid]]][fhir:status/@value='active']
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
 $o