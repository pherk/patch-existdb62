xquery version "3.0";

import module namespace r-practrole      = "http://enahar.org/exist/restxq/metis/practrole"
                       at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
declare namespace fhir= "http://hl7.org/fhir";

let $u := r-practrole:userByAlias("newelingf")
let $oldref := concat('metis/practitioners/',$u/fhir:id/@value)
let $newref := $u/fhir:practitioner/fhir:reference/@value/string()

let $os := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:careManager[fhir:reference/@value=$oldref]]

for $o in $os
let $m := $o/fhir:careManager[fhir:reference/@value=$oldref]
return
    $o
    (:
        system:as-user("vdba", "kikl823!",
            (
                update value $m/fhir:reference/@value with $newref
          ))
    :)

