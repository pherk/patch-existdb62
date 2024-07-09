xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $oid := 'o-93be2a80-eb49-4175-9130-ac8c30433c2e'

let $o := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:id[@value=$oid]]
let $upd := system:as-user('admin', 'kikl968',
            update value $o/fhir:status/@value with 'active'
            )
return
    <done></done>