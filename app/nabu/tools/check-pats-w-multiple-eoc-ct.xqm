xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";

let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $os := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient
for $o in xmldb:find-last-modified-since($os,xs:dateTime("2018-05-28T15:00:00"))
let $pid := $o/fhir:id/@value/string()
let $eoc := $eocs/fhir:EpisodeOfCare[fhir:subject[fhir:reference/@value=concat('nabu/patients/',$pid)]]
let $ct  := $cts/fhir:CareTeam[fhir:subject[fhir:reference/@value=concat('nabu/patients/',$pid)]]
order by $o/*:date/@value/string()
return
    if ($eoc and $ct and count($eoc[fhir:status/@value=('planned','active')])=1 and count($ct[fhir:status/@value='active'])=1)
    then ()
    else
    <patient id="{$pid}" name="{concat($o/fhir:name[fhir:use/@value='official']/fhir:family/@value,', ',$o/fhir:name[fhir:use/@value='official']/fhir:given/@value)}">
        { $eoc }
        { $ct }
    </patient>