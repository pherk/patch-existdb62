xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $pid := concat('nabu/patients/','p-0546cd05-3f03-48ba-a95f-c66761bd3273')

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:lastModified/@value>"2020-08-09"][fhir:meta/fhir:versionId/@value="0"]
return
 $os[1]