xquery version "3.1";

import module namespace r-ct     = "http://enahar.org/exist/restxq/nabu/careteams"               at "/db/apps/nabu/FHIR/CareTeam/careteam-routes.xqm";
import module namespace ctt      = "http://enahar.org/exist/apps/nabu/ct-template"               at "/db/apps/nabu/FHIR/CareTeam/ct-template.xqm";

declare namespace fhir= "http://hl7.org/fhir";

let $now := current-dateTime()
let $realm := 'metis/organizations/kikl-spzn'
let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value=('planned','active')]]
let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')

for $eoc in xmldb:find-last-modified-since($eocs,xs:dateTime("2020-06-01T00:00:00"))
let $pref := $eoc/fhir:subject/fhir:reference/@value/string()
let $ct  := 
    let $cts0 := $cts/fhir:CareTeam[fhir:subject[fhir:reference/@value=$pref]][fhir:status[@value='active']]
    return
    if (count($cts0)=0)
    then (: create missing CareTeam :)
        let $pid := substring-after($pref,'nabu/patients/')
        let $p := $ps/fhir:Patient[fhir:id[@value=$pid]]
        let $ctp := ctt:fillCareTeam(
        (
          <status xmlns="http://hl7.org/fhir" value="active"/>
        , <period xmlns="http://hl7.org/fhir">
                <start value="{$now}"/>
                <end value=""/>
          </period>
        , <subject xmlns="http://hl7.org/fhir">
                <reference value="{$pref}"/>
                <display value="{$p/fhir:text/@value}"/>
          </subject>
        , <context xmlns="http://hl7.org/fhir">
            <reference value="{concat('nabu/episodeofcares/',$eoc/fhir:id/@value)}"/>
          </context>
        )
    ,   (
            ()
        ,   <note xmlns="http://hl7.org/fhir">
                <authorReference>
                    <reference value="metis/practitioners/u-admin"/>
                    <display value="migbot"/>                  
                </authorReference>
                <time value="{$now}"/>
                <text value="repair v0.9"/>
            </note>
        )
    )
    return
        r-ct:putCareTeamXML(document{$ctp}, $realm, 'u-admin', 'migbot')[2]
    else $cts0
order by $eoc/fhir:lastModified/@value/string()
return
    if ($eoc and $ct and count($eoc)=1 and count($ct)=1 and $eoc/fhir:team/fhir:reference/@value!='' and $ct/fhir:context/fhir:reference/@value!='')
    then ()
    else if (count($eoc)=1 and count($ct)=1)
    then
        let $pid := substring-after($pref,'nabu/patients/')
        let $p := $ps/fhir:Patient[fhir:id[@value=$pid]]
        return
        let $upd := system:as-user('vdba', 'kikl823!', 
            (
                if ($eoc/fhir:team and $eoc/fhir:team/fhir:reference/@value='')
                then
                    (
                        update value $eoc/fhir:team/fhir:reference/@value with concat('nabu/careteams/',$ct/fhir:id/@value)
                    ,   update value $eoc/fhir:team/fhir:display/@value with 'nSPZ'
                    )
                else ()
            ,   if ($ct/fhir:context/fhir:reference/@value='')
                then
                    (
                        update value $ct/fhir:context/fhir:reference/@value with concat('nabu/episodeofcares/',$eoc/fhir:id/@value)
                    )
                else ()
            ))
        return
        <repair id="{$pid}" name="{concat($p/fhir:name[fhir:use/@value='official']/fhir:family/@value,', ',$p/fhir:name[fhir:use/@value='official']/fhir:given/@value)}">
         {$ct}
        </repair>
    else
        let $pid := substring-after($pref,'nabu/patients/')
        let $p := $ps/fhir:Patient[fhir:id[@value=$pid]]
        return
        <norepair id="{$pid}" name="{concat($p/fhir:name[fhir:use/@value='official']/fhir:family/@value,', ',$p/fhir:name[fhir:use/@value='official']/fhir:given/@value)}">
            { $eoc }
            { $ct }
        </norepair>