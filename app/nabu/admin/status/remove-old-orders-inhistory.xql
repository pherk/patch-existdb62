xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";
(:~
 : Achtung: !!!
 :
 :)
let $cs := collection('/db/apps/nabuHistory/data/Orders')/fhir:Order[fhir:lastModified[@value<'2021-01-01T00:00:00']]
for $c in $cs
let $cr := util:document-name($c)
return
    xmldb:remove('/db/apps/nabuHistory/data/Orders',$cr)