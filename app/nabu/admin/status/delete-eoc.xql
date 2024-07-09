xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";


let $ids := (
      <id value="c-1f8eda34-58b2-4fc8-9943-5c66fb0665ea"/>
  
    )
    
let $psc := collection('/db/apps/nabuCom/data/EpisodeOfCares')

for $id in $ids/@value/string()
let $ps := $psc/fhir:EpisodeOfCare[fhir:id[@value=$id]]
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