xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";


let $ids := (
      <id value="c-8e85a29e-eb2b-4426-a6bd-3ba86fe92797"/>
  
    )
    
let $psc := collection('/db/apps/nabuCom/data/CareTeams')

for $id in $ids/@value/string()
let $ps := $psc/fhir:CareTeam[fhir:id[@value=$id]]
return
    if (count($ps)=1)
    then
        let $upd := system:as-user('admin', 'kikl968',
            update value $ps/fhir:status/@value with 'inactive'
            )
        return
            <done></done>
    else
        $id