xquery version "3.0";
import module namespace eoc      = "http://enahar.org/exist/apps/nabu/eoc"  at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare.xqm";

declare namespace fhir= "http://hl7.org/fhir";

let $ocs := collection('/db/apps/nabuData/data/FHIR/Orders')
let $pcs := collection('/db/apps/nabuData/data/FHIR/Patients')
let $ecs := collection('/db/apps/nabuEncounter/data')
let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value='planned']]
for $o in $eocs
let $cid := substring-after($o/fhir:team/fhir:reference/@value,'nabu/careteams/')
let $ct := $cts/fhir:CareTeam[fhir:id[@value=$cid]]
let $start := $o/fhir:period/fhir:start/@value/string()
order by $o/fhir:period/fhir:start/@value/string() descending
return
    let $actors := $ct/fhir:participant
    let $cm := eoc:careManager($actors)
    return
        if ($actors)
        then
            let $updateEoC := system:as-user(
                      "vdba", "kikl823!",
                    (
                        update value $o/fhir:status/@value with "active"
                      , if ($cm)
                        then
                            (
                                update value $o/fhir:careManager/fhir:reference/@value with $cm/fhir:reference/@value/string()
                            ,   update value $o/fhir:careManager/fhir:display/@value with $cm/fhir:display/@value/string()
                            )
                        else ()
                    ))
            return  <upd>
                    {$o/fhir:subject}
                    </upd>
        else (: no active CT or active CT without participants :)
            let $es := $ecs/fhir:Encounter[fhir:subject[fhir:reference/@value=$o/fhir:subject/fhir:reference/@value]][fhir:status[@value='finished']][fhir:period/fhir:start/@value >= $start]
            return
                if (count($es)=0 and $o/fhir:period/fhir:start/@value < "2015-12-31") (: or start='' :)
                then
                    let $upd := system:as-user(
                            "vdba", "kikl823!", (
                              update value $o/fhir:status/@value with "cancelled"
                            , update value $ct/fhir:status/@value with "inactive"
                        ))
                    return ()
                else if (count($es)=0 and $o/fhir:period/fhir:start/@value >= "2015-12-31" and $o/fhir:period/fhir:start/@value < "2017-12-01") 
                then
                    let $os := $ocs/fhir:Order[fhir:subject[fhir:reference[@value=$o/fhir:subject/fhir:reference/@value]]]
                    return
                        if (count($os)=0 or count($os[fhir:status/@value='active'])>0)
                        then
                            <lost start="{$start}">
                                {$o/fhir:subject}
                                { $os }
                            </lost>
                        else
                            let $upd := system:as-user(
                                    "vdba", "kikl823!", (
                                      update value $o/fhir:status/@value with "cancelled"
                                    , update value $ct/fhir:status/@value with "inactive"
                                    ))
                            return ()
                            
                else if (count($es)=0 and $o/fhir:period/fhir:start/@value >= "2017-12-01") 
                then
                    if (count($ecs/fhir:Encounter[fhir:subject[fhir:reference/@value=$o/fhir:subject/fhir:reference/@value]][fhir:status[@value=('planned','tentative')]])=0)
                    then
                        let $os := $ocs/fhir:Order[fhir:subject[fhir:reference[@value=$o/fhir:subject/fhir:reference/@value]]]
                        return
                            <planning start="{$start}">
                                {$o/fhir:subject}
                                { $os }
                            </planning>
                    else ()
                else if ($ct/fhir:status/@value='active' and count($es)>0 ) (: Encounter not in CT/EoC :)
                then
                    let $ps :=  for $e in $es
                                return
                                    <participant xmlns="http://hl7.org/fhir">
                                        <role>
                                            { $e/fhir:type/fhir:* }
                                        </role>
                                        { $e/fhir:period }
                                        <member>
                                            { $e/fhir:participant/fhir:actor/fhir:reference }
                                            { $e/fhir:participant/fhir:actor/fhir:display }
                                            </member>
                                    </participant>
let $lll := util:log-app('TRACE','apps.nabu',$ps)
                    let $cm :=  eoc:careManager($ps)
let $lll := util:log-app('TRACE','apps.nabu',$cm)
                    let $updcm := system:as-user(
                                          "vdba", "kikl823!",
                                        (
                                            update value $o/fhir:status/@value with "active"
                                        , if ($cm)
                                            then
                                            (
                                                update value $o/fhir:careManager/fhir:reference/@value with $cm/fhir:reference/@value/string()
                                            ,   update value $o/fhir:careManager/fhir:display/@value with $cm/fhir:display/@value/string()
                                            )   
                                        else ()
                                        ))
                    let $updct := system:as-user('vdba', 'kikl823!',
                            (
                                for $p in $ps
                                return
                                    update insert $p
                                        following $ct/fhir:managingOrganization
                            , update value $ct/fhir:lastModifiedBy/fhir:reference/@value with 'metis/practitioners/u-admin'
                            , update value $ct/fhir:lastModifiedBy/fhir:display/@value with 'Admin'
                            , update value $ct/fhir:lastModified/@value with current-dateTime()
                            ))
                    return
                        <eoc-ct-upd start="{$start}">
                            {$o/fhir:subject}
                        </eoc-ct-upd>
                else
                    let $pid := substring-after($o/fhir:subject/fhir:reference/@value,'nabu/patients/')
                    let $pat := $pcs/fhir:Patient[fhir:id[@value=$pid]]
                    return
                        if ($pat and $pat/fhir:active/@value='false')
                        then
                            let $upd := system:as-user(
                                    "vdba", "kikl823!", (
                                      update value $o/fhir:status/@value with "cancelled"
                                    , update value $ct/fhir:status/@value with "inactive"
                                    ))
                            return ()
                        else
                            <fail start="{$start}">
                                {$pat/fhir:id}
                                {$o/fhir:subject}
                            </fail>