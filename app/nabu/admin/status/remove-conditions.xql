xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";
(:~
 : Achtung: legt ohne Index den Server lahm!!!
 : mit Index eine Minute pro 10.000
 :)
let $cs := collection('/db/apps/nabuCom/data/Conditions')/fhir:Condition[fhir:verificationStatus[@value='entered-in-error']]
for $c in $cs
let $cr := util:document-name($c)
return
    xmldb:remove('/db/apps/nabuCom/data/Conditions',$cr)