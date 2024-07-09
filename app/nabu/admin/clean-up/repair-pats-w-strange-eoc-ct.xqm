xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";

declare function local:link($eoc,$ct)
{
        let $eref := concat('nabu/episodeofcares/',$eoc/fhir:id/@value)
        let $cref := concat('nabu/careteams/',$ct/fhir:id/@value)
        let $updt1 := if ($eoc/fhir:team/fhir:reference/@value=$cref)
            then ()
            else 
                let $upd1 :=
                    system:as-user('vdba','kikl823!',
                        (
                          update value $eoc/fhir:team/fhir:reference/@value with $cref
                        ))
                        
                return
                    'EoC team ref updated'
        return $updt1
};

let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:active[@value='true']]
let $ddd :=
    <data>
        {
    for $o in $ps
    let $pid := $o/fhir:id/@value/string()
    let $eoc := $eocs/fhir:EpisodeOfCare[fhir:subject[fhir:reference/@value=concat('nabu/patients/',$pid)]]
    let $ct  := $cts/fhir:CareTeam[fhir:subject[fhir:reference/@value=concat('nabu/patients/',$pid)]]
    order by $o/fhir:date/@value/string()
    return
    if ($eoc and $ct and count($eoc)>1 and count($ct)=1) (: remove bogus EoC :)
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
                                    xmldb:remove('/db/apps/nabuCom/data/EpisodeOfCares',concat($e/@xml:id,'.xml'))
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
    else if ($eoc and $ct and count($eoc) = 1 and count($ct) = 1)
    then local:link($eoc,$ct)
    else if ($eoc and $ct and count($eoc[fhir:status[@value=('planned','active')]]) = 1 and count($ct[fhir:status[@value='active']]) = 1)
    then local:link($eoc[fhir:status[@value=('planned','active')]],$ct[fhir:status[@value='active']])
    else if ($eoc and $ct and count($eoc) = count($ct))
    then ()
    else
    <norepair id="{$pid}" name="{concat($o/fhir:name[fhir:use/@value='official']/fhir:family/@value,', ',$o/fhir:name[fhir:use/@value='official']/fhir:given/@value)}">
        { $eoc }
        { $ct }
    </norepair>
    }
</data>
let $file := concat('pat-eoc-ct-repair-',tokenize(current-date(),'\+')[1],'.xml')
return
    system:as-user("admin","kikl968", (
            xmldb:store("/db/apps/nabu/admin/clean-up", $file, $ddd)
            , sm:chmod(xs:anyURI("/db/apps/admin/clean-up" || '/' || $file), "rwxrw-r--")
            , sm:chgrp(xs:anyURI("/db/apps/nabu/admin/clean-up" || '/' || $file), "spz")
            )
    )
