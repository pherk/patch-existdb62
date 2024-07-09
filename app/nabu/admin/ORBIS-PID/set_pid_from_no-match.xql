xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $year := '2024Q1'
let $nomatches := doc("/db/apps/nabuORBIS/liste-" || $year || ".xml")/*:patients/*:tag/*:no-exact-match

let $pc := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:active[@value="true"]]
return
    <rest>
        {
for $no in $nomatches
return
    if (count($no/*:orbis)=1 and $no/@id)
    then
        let $p := $pc/../fhir:Patient[fhir:id[@value=$no/@id]]
        return
            if ($p/fhir:identifier[fhir:type/@value='ORBIS-PNR']/fhir:value/@value='')
            then
                system:as-user('vdba', 'kikl823!',
                    update value $p/fhir:identifier[fhir:type/@value='ORBIS-PNR']/fhir:value/@value
                    with tokenize($no/*:orbis,", ")[4]
                )
            else ()
    else $no
        }
        </rest>