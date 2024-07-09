xquery version "3.0";

import module namespace r-practrole      = "http://enahar.org/exist/restxq/metis/practrole"
                       at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
declare namespace fhir= "http://hl7.org/fhir";

let $ou := r-practrole:userByAlias("lombardol")
let $nu := r-practrole:userByAlias("kraemera")
let $oldref := $ou/fhir:practitioner/fhir:reference/@value/string()
let $newref := $nu/fhir:practitioner/fhir:reference/@value/string()
let $dateline := "2023-01-01"

let $osp := collection('/db/apps/nabuEncounter/data/planned')/fhir:Encounter[fhir:participant/fhir:actor[fhir:reference/@value=$oldref]]
for $o in $osp[fhir:period/fhir:start/@value>$dateline]
let $a := $o/fhir:participant/fhir:actor[fhir:reference/@value=$oldref]
return
        system:as-user("vdba", "kikl823!",
            (
                update value $a/fhir:reference/@value with $newref
          ))

