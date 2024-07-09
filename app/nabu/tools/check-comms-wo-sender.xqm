xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $pref := 'metis/practitioners/u-admin'
let $pdis := 'admin'
let $os := collection('/db/apps/nabuCommunication/data/2020')/fhir:Communication[fhir:sender[fhir:reference/@value='metis/practitioners/']]
for $o in $os
return
    (:
    system:as-user("vdba", "kikl823!",
            (
                update value $o/fhir:lastModifiedBy/fhir:reference/@text with $pref
            ,   update value $o/fhir:lastModifiedBy/fhir:display/@text with $pdis
            ,   update value $o/fhir:sender/fhir:reference/@value with $pref
            ,   update value $o/fhir:sender/fhir:display/@value with $pdis
            ))
:)
$o/fhir:subject