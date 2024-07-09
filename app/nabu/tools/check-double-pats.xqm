xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "application/xml";

let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')

return
<html>
    <body>
    {
for $p in $ps
let $dups := $ps/fhir:Patient[fhir:birthDate/@value = $p/fhir:Patient/fhir:birthDate/@value][fhir:name/fhir:family/@value = $p/fhir:Patient/fhir:name/fhir:family/@value]
return
    if (count($dups)>1)
    then
        for $d in $dups
        return
            let $dg := $d/fhir:name/fhir:given/@value/string()
            let $pg := $p/fhir:Patient/fhir:name/fhir:given/@value /string()
            return
                if (starts-with($dg,$pg) or starts-with($pg,$dg))
                then
                    <p>{
                    concat($d/*:name/*:family/@value, ', ', $d/*:name/*:given/@value, ', *', $d/*:birthDate/@value,'   ', $d/*:extension//*:code/@value)
                    }</p>
                else ()
    else ()
    }
    </body>
</html>