xquery version "3.0";


declare namespace fhir= "http://hl7.org/fhir";

let $prs := collection('/db/apps/metisData/data/FHIR/PractitionerRoles')
let $os  := collection('/db/apps/metisData/data/FHIR/Leaves')/*:leave[*:actor/*:display[@value='']] 
for $o in $os
let $id := substring-after($o/actor/reference/@value,'metis/practitioners/')
let $pref := $prs/fhir:PractitionerRole[fhir:id[@value=$id]]/fhir:practitioner/fhir:reference/@value/string()
let $pdis := $prs/fhir:PractitionerRole[fhir:id[@value=$id]]/fhir:practitioner/fhir:display/@value/string()
return
    if ($pref)
    then
        system:as-user("vdba", "kikl823!",
            (
                update value $o/lastModifiedBy/reference/@text with $pref
            ,   update value $o/lastModifiedBy/display/@text with $pdis
            ,   update value $o/actor/reference/@value with $pref
            ,   update value $o/actor/display/@value with $pdis
            ))
    else $id