xquery version "3.1";

(:~
 : checked alle aktiven Eoc, ob ein passendes CareTeam vorhanden ist und ob die Links gesetzt sind
 : 
 :)
declare namespace fhir= "http://hl7.org/fhir";

let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value=('planned','active')]]
let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')
for $eoc in xmldb:find-last-modified-since($eocs,xs:dateTime("2020-01-01T00:00:00"))
let $pref := $eoc/fhir:patient/fhir:reference/@value/string()
let $cta  := $cts/fhir:CareTeam[fhir:subject[fhir:reference/@value=$pref]][fhir:status[@value=('active')]]
order by $eoc/fhir:lastModified/@value/string()
return
    if ($eoc and $cta and count($eoc)=1 and count($cta)=1 and $eoc/fhir:team/fhir:reference/@value!='')
    then ()
    else
        let $pid := substring-after($pref,'nabu/patients/')
        let $p := $ps/fhir:Patient[fhir:id[@value=$pid]]
        return
    <patient id="{$pid}" name="{concat($p/fhir:name[fhir:use/@value='official']/fhir:family/@value,', ',$p/fhir:name[fhir:use/@value='official']/fhir:given/@value)}">
      <eoc id="{$eoc/fhir:id/@value/string()}">
        { $eoc/fhir:team }
      </eoc>
    </patient>