xquery version "3.1";

declare namespace fhir   = "http://hl7.org/fhir";

let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:active[@value="true"]]
let $selected := $ps/fhir:identifier
let $orbisnr  := $ps/../fhir:Patient[fhir:identifier[fhir:value/@value!='']] (: $selected[fhir:value/@value!=''][fhir:system/@value="http://uk-koeln.de/#patient-orbis-pnr"]  :)
return
    <patients>
        <total>{count($ps)}</total>
        <w-identifier>{count($selected)}</w-identifier>
        <w-orbisnr>{count($orbisnr)}</w-orbisnr>
    </patients>