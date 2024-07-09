xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $id := 'p-a8bf9da0-d4ef-463f-9296-3663b66e2a33'
let $date := '2018-09-06'
let $status := 'cancelled'
let $es := collection('/db/apps/nabuEncounter/data')/fhir:Encounter[fhir:subject[fhir:reference/@value='nabu/patients/' || $id]]
let $e := $es[starts-with(fhir:period/fhir:start/@value,$date)]
return
    if (count($e)=1)
    then
        let $upd := system:as-user('admin', 'kikl968',
            update value $e/fhir:status/@value with $status
            )
        return
            <done></done>
    else
        $e