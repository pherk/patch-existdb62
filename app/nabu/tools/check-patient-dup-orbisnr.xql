xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:identifier[fhir:value/@value!='']][fhir:active[@value="true"]]
let $ids :=  distinct-values($os/fhir:identifier/fhir:value/@value)

let $list := 
  <patients>
  {
         
    for $id in $ids
    let $ps := $os/../fhir:Patient[fhir:identifier[fhir:value/@value=$id]]
order by $id
return
    if (count($ps)>1)
    then <id id="{$ps/../fhir:Patient[1]/fhir:identifier/fhir:value/@value/string()}">
        {
            for $p in $ps
            return
                <p>{$p/fhir:text/*:div/*:div/string()}</p>
        }
        </id>
    else ()
  }
  </patients>
    
return
    system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabuORBIS","dup-pid.xml",$list))