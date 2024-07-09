xquery version "3.1";

(: ~
 :  regenerate CareTeam 
 : 
 : 
 : 
 : 
 :)
import module namespace r-ct     = "http://enahar.org/exist/restxq/nabu/careteams"               at "/db/apps/nabu/FHIR/CareTeam/careteam-routes.xqm";


declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare function local:computeCareTeam(
          $ebs as element(fhir:Encounter)*
        ) as element(fhir:participant)*
{
    let $mrefs := distinct-values($ebs/fhir:participant/fhir:actor/fhir:reference/@value)
    for $mref in $mrefs
    let $ebsm  := $ebs/../fhir:Encounter[fhir:participant/fhir:actor/fhir:reference[@value=$mref]]
    let $first := min($ebsm/fhir:period/fhir:start/@value/string())
    let $last  := max($ebsm/fhir:period/fhir:start/@value/string())
    let $laste := $ebsm[fhir:period/fhir:start[@value=$last]][1] (: should be only one :)
    let $role  := $laste/fhir:participant/fhir:type/fhir:coding/fhir:code/@value/string()
    order by $role, $last descending
    return
        <participant xmlns="http://hl7.org/fhir">
            <role>
                <coding>
                    <system value="http://eNahar.org/nabu/system#careteam-participant-role"/>
                    <code value="{$role}"/>
                </coding>
                <text value="{$laste/fhir:participant/fhir:type/fhir:text/@value/string()}"/>
            </role>
            <member>
                <reference value="{$laste/fhir:participant/fhir:actor/fhir:reference/@value/string()}"/>
                <display value="{$laste/fhir:participant/fhir:actor/fhir:display/@value/string()}"/>
            </member>
            <period>
                <start value="{$first}"/>
                <end value="{$last}"/>
            </period>
        </participant>
};

let $es := collection('/db/apps/nabuEncounter/data')

let $realm := 'kikl-spz'
let $now := current-dateTime()
let $cts := collection('/db/apps/nabuCom/data/CareTeams')
for $ct in $cts/fhir:CareTeam[fhir:status[@value='active']]
let $encs := $es/fhir:Encounter[fhir:subject[fhir:reference/@value=$ct/fhir:subject/fhir:reference/@value]][fhir:status[@value='finished']]
let $ps  := local:computeCareTeam($encs)
let $meta := $ct/fhir:meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
let $nct :=  <CareTeam xmlns="http://hl7.org/fhir" xml:id="{$ct/@xml:id}">
                            {$ct/fhir:id}
                            <meta>
                                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                                    <valueReference>
                                        <reference value="metis/practitioners/u-admin"/>
                                        <display value="migbot"/>
                                    </valueReference>
                                </extension>
                                {$ct/fhir:meta/fhir:versionId}
                                <lastUpdated value="{current-dateTime()}"/>
                                {$meta}
                            </meta>
                            {$ct/fhir:identifier}
                            {$ct/fhir:status}
                            {$ct/fhir:category}
                            {$ct/fhir:name}
                            {$ct/fhir:subject}
                            {$ct/fhir:context}
                            <period>
                                {$ct/fhir:period/fhir:start}
                                <end value="{current-dateTime()}"/>
                            </period>
                            {$ps}
                            {$ct/fhir:managingOrganization}
                            {$ct/fhir:note}
                        </CareTeam>

let $ncts := r-ct:putCareTeamXML(document {$nct}, $realm, 'u-admin', 'migbot')
return
    ()