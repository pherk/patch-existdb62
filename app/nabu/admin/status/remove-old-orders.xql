xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";
(:~
 : Achtung: !!!
 :
 :)
let $cs := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:status[@value="completed"]][fhir:lastModified[@value<'2020-01-01T00:00:00']]
for $c in $cs
let $cr := util:document-name($c)
return
    xmldb:remove('/db/apps/nabuData/data/FHIR/Orders',$cr)