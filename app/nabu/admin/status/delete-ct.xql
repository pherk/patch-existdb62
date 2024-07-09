xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";


let $ids := (
      <id value="c-37d4987b-8497-42ba-be58-2f263cf55483"/>
  
    )
    
let $psc := collection('/db/apps/nabuCom/data/CareTeams')

for $id in $ids/@value/string()
let $ps := $psc/fhir:CareTeam[fhir:id[@value=$id]]
return
    if (count($ps)=1)
    then
        let $upd := system:as-user('admin', 'kikl968',
            update value $ps/fhir:status/@value with 'entered-in-error'
            )
        return
            <done></done>
    else
        $id