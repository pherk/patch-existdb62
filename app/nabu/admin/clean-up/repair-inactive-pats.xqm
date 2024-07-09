xquery version "3.1";



declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $eocp := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value='planned']]
let $ctp  := collection('/db/apps/nabuCom/data/CareTeams')/fhir:CareTeam[fhir:status[@value='active']]
let $ec := collection('/db/apps/nabuData/data/FHIR/Patients')
let $es := $ec/fhir:Patient[fhir:active[@value='false']]

let $realm := 'kikl-spz'
let $now := current-dateTime()

for $patient in $es
let $pref := concat('nabu/patients/',$patient/fhir:id/@value)
let $eoc := $eocp/../fhir:EpisodeOfCare[fhir:subject[fhir:reference/@value=$pref]]
let $ct  := $ctp/../fhir:CareTeam[fhir:subject[fhir:reference/@value=$pref]]
return
    if ($eoc and $ct)
    then
        let $upd := system:as-user("vdba", "kikl823!",
            (
                update value $eoc/fhir:status/@value with "cancelled"
            ,   update value $ct/fhir:status/@value with "inactive"
            ))
        return
            <upd/>
    else if ($eoc)
    then 
        let $upd := system:as-user("vdba", "kikl823!",
            (
                update value $eoc/fhir:status/@value with "cancelled"
            ))
        return
            <eoc/>
    else if ($ct)
    then 
        let $upd := system:as-user("vdba", "kikl823!",
            (
               update value $ct/fhir:status/@value with "inactive"
            ))
        return
            <ct/>
    else ()
