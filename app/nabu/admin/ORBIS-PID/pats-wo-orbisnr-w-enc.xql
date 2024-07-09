xquery version "3.1";

declare namespace fhir   = "http://hl7.org/fhir";

let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:active[@value="true"]]
let $ec := collection('/db/apps/nabuEncounter/data/')/fhir:Encounter[fhir:status[@value='finished']]

let $wo  := $ps/../fhir:Patient[fhir:identifier[fhir:value/@value='']]
let $list :=
    <patients>
        <w-orbisnr>{count($wo)}</w-orbisnr>
        {
        for $p in $wo
        let $pref := concat('nabu/patients/',$p/fhir:id/@value)
        let $es := $ec/../fhir:Encounter[fhir:subject[fhir:reference/@value=$pref]]
        return
            if (count($es)=0)
            then ()
            else
                <p ref="{$p/fhir:id/@value/string()}" text="{$p/fhir:text/*:div/*:div/string()}"></p>
        }
    </patients>
return
    system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabuORBIS","no-pid-we.xml",$list))