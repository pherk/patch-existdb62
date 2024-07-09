xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:id[@value='p-18954']]
return
    if (count($ps)=1)
    then
        let $upd := system:as-user('admin', 'kikl968',
            update value $ps/fhir:active/@value with 'false'
            )
        return
            <done></done>
    else
        $ps