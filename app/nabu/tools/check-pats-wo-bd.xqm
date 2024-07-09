xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:birthDate[@value='']][fhir:active[@value='true']]
let $list :=
    <patients>
    {
    for $p in $os
    return
        <p text="{$p/fhir:text/*:div/*:div/string()}"></p>
    }
    </patients>
return

    system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabuORBIS","pat-wo-bd.xml",$list))
