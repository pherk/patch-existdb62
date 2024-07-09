xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";
(:~
 : dauert eine Minuten pro 1.000
 :)
let $cs := collection('/db/apps/nabuCommunication/data/2018')/fhir:Communication
for $c in $cs
let $cr := util:document-name($c)
return
    xmldb:remove('/db/apps/nabuCommunication/data/2018',$cr)