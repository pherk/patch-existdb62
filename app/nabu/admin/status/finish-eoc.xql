xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";


let $ids := (
      <id value="c-a501077b-8185-4b79-b66f-ec5c02b4e7e2"/>
  
    )
    
let $psc := collection('/db/apps/nabuCom/data/EpisodeOfCares')

for $id in $ids/@value/string()
let $ps := $psc/fhir:EpisodeOfCare[fhir:id[@value=$id]]
return
    if (count($ps)=1)
    then
        let $upd := system:as-user('admin', 'kikl968',
            update value $ps/fhir:status/@value with 'finished'
            )
        return
            <done></done>
    else
        $id