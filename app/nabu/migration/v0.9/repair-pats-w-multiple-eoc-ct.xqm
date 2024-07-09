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
    else if (count($eoc)>1 and count($ct)=1) (: remove bogus EoC :)
    then
        let $upd := if ($ct/fhir:context/fhir:reference/@value!='')
            then let $found := $eoc[fhir:id/@value=substring-after($ct/fhir:context/fhir:reference/@value,'nabu/episodeofcares/')]
                return
                    if ($found)
                    then
                        let $upd1 :=
                            system:as-user('vdba','kikl823!',
                            (
                                for $e in $eoc[fhir:id/@value!=$found/fhir:id/@value]
                                return
                                    xmldb:remove('/db/apps/nabuCom/data/EpisodeOfCares',concat($e/fhir:id/@value,'.xml'))
                            ))
                        return
                            concat(count($eoc)-1,' EoC removed')
                    else "no corresponding EoC found"
            else
                "context in CT empty"
        return
            <patient id="{$pid}" name="{concat($o/fhir:name[fhir:use/@value='official']/fhir:family/@value,', ',$o/fhir:name[fhir:use/@value='official']/fhir:given/@value)}">
                { $upd }
            </patient>
    else if ($eoc and $ct and count($eoc[fhir:status/@value=('finished')])>0 and count($ct[fhir:status/@value='inactive'])>0)
    then () (: patient has been finished :)
    else
    <norepair id="{$pid}" name="{concat($o/fhir:name[fhir:use/@value='official']/fhir:family/@value,', ',$o/fhir:name[fhir:use/@value='official']/fhir:given/@value)}">
        { $eoc }
        { $ct }
    </norepair>