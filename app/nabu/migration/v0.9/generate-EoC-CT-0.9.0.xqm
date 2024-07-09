xquery version "3.1";

import module namespace patmigr  = "http://enahar.org/exist/apps/nabu/patient-migration"         at "../../FHIR/Patient/patient-migration.xqm";
import module namespace patutils = "http://enahar.org/exist/apps/nabu/patutils"                  at "../../FHIR/Patient/patutils.xqm";
import module namespace r-respon = "http://enahar.org/exist/restxq/nabu/patient-responsibility"  at "../../FHIR/Patient/responsibility-routes.xqm";
import module namespace r-ct     = "http://enahar.org/exist/restxq/nabu/careteams"               at "../../FHIR/CareTeam/careteam-routes.xqm";
import module namespace r-eoc    = "http://enahar.org/exist/restxq/nabu/eocs"                    at "../../FHIR/EpisodeOfCare/episodeofcare-routes.xqm";
import module namespace ctt      = "http://enahar.org/exist/apps/nabu/ct-template"               at "../../FHIR/CareTeam/ct-template.xqm";
import module namespace eoct     = "http://enahar.org/exist/apps/nabu/eoc-template"              at "../../FHIR/EpisodeOfCare/eoc-template.xqm";
import module namespace eoc      = "http://enahar.org/exist/apps/nabu/eoc"                       at "../../FHIR/EpisodeOfCare/episodeofcare.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare function local:lastEncounter($ps as element(fhir:participant)*) as xs:dateTime?
{
    if ($ps)
    then max(for $p in $ps return xs:dateTime($p/fhir:period/fhir:end/@value/string()))
    else ()
};

declare function local:firstEncounter($ps as element(fhir:participant)*) as xs:dateTime?
{
    if ($ps)
    then min(for $p in $ps return xs:dateTime($p/fhir:period/fhir:start/@value/string()))  
    else ()
};

let $ec := collection('/db/apps/nabuData/data/FHIR/Patients')
let $es := $ec/fhir:Patient[fhir:id[@value='p-5476']]

let $realm := 'kikl-spz'
let $now := current-dateTime()
for $patient in $es
let $ps  := r-respon:computeCareTeam($patient/fhir:id/@value,())
let $firstContact := $patient/fhir:address/fhir:period/fhir:start/@value/string()
let $firstEnc := local:firstEncounter($ps)
let $lastEnc  := local:lastEncounter($ps)
let $eocstatus := if (count($ps)=0)
    then 'planned'
    else if ($lastEnc > ($now - xs:dayTimeDuration('P1000D')))
    then 'active'
    else 'finished'
let $ctstatus := switch($eocstatus)
    case 'finished' return 'inactive'
    default return 'active'
(: step 1 :)
let $eoc := eoct:fillEpisodeOfCare(
        (
            <status  xmlns="http://hl7.org/fhir" value="{$eocstatus}"/>
        ,   <period xmlns="http://hl7.org/fhir">
                <start value="{if ($firstContact!='') then $firstContact else $firstEnc}"/>
                <end value="{if ($eocstatus='finished') then $lastEnc else ""}"/>
            </period>
        ,   <subject xmlns="http://hl7.org/fhir">
                <reference value="{concat('nabu/patients/',$patient/fhir:id/@value)}"/>
                <display value="{patutils:formatFHIRname($patient)}"/>
            </subject>
        )
    ,   (
            <statusHistory xmlns="http://hl7.org/fhir">
                <status value="planned"/>
                <extension url="#eoc-workflow-change">
                    <valueCodeableConcept>
                        <coding>
                            <system value="#eoc-workflow-change-reason"/>
                            <code value="first-contact"/>
                            <display value="Erstkontakt"/>
                        </coding>
                        <text value="{$patient/fhir:extension[@url='#patient-presenting-problem']/fhir:valueAnnotation/fhir:text/@value}"/>
                    </valueCodeableConcept>
                </extension>
                <extension url="#eoc-workflow-change-author">
                    <valueReference>
                        <reference value="metis/practitioners/u-admin"/>
                        <display value="migbot"/>
                    </valueReference>
                </extension>
                <period>
                    <start value="{if ($firstContact!='') then $firstContact else $firstEnc}"/>
                    <end value="{if ($eocstatus='finished') then $now else ""}"/>
                </period>
            </statusHistory>
        ,   if ($eocstatus='finished')
            then 
                <statusHistory xmlns="http://hl7.org/fhir">
                    <status value="finished"/>
                    <extension url="#eoc-workflow-change">
                        <valueCodeableConcept>
                            <coding>
                                <system value="#eoc-workflow-change-reason"/>
                                <code value="revision"/>
                                <display value="Revision"/>
                            </coding>
                            <text value="auto finished (lastEnc > 1000d)"/>
                    </valueCodeableConcept>
                </extension>
                <extension url="#eoc-workflow-change-author">
                    <valueReference>
                        <reference value="metis/practitioners/u-admin"/>
                        <display value="migbot"/>
                    </valueReference>
                </extension>
                <period>
                    <start value="{$now}"/>
                    <end value=""/>
                </period>
            </statusHistory>
            else ()
        ,   <team xmlns="http://hl7.org/fhir">
                <reference value=""/>
                <display value=""/>
            </team>
        )
    )
let $eocs := r-eoc:putEpisodeOfCareXML(document {$eoc}, $realm, 'u-admin', 'migbot')[2]
(:  step 2 CareTeam :)
let $ct := ctt:fillCareTeam(
        (
          <status xmlns="http://hl7.org/fhir" value="{$ctstatus}"/>
        , <period xmlns="http://hl7.org/fhir">
                <start value="{if ($firstContact!='') then $firstContact else $firstEnc}"/>
                <end value="{$lastEnc}"/>
          </period>
        , <subject xmlns="http://hl7.org/fhir">
                <reference value="{concat('nabu/patients/',$patient/fhir:id/@value)}"/>
                <display value="{patutils:formatFHIRname($patient)}"/>
          </subject>
        , <context xmlns="http://hl7.org/fhir">
            <reference value="{concat('nabu/episodeofcares/',$eocs/fhir:id/@value)}"/>
          </context>
        )
    ,   (
            $ps
        ,   <note xmlns="http://hl7.org/fhir">
                <authorReference>
                    <reference value="metis/practitioners/u-admin"/>
                    <display value="migbot"/>                  
                </authorReference>
                <time value="{$now}"/>
                <text value="Migration v0.9"/>
            </note>
        )
    )
let $cts := r-ct:putCareTeamXML(document {$ct}, $realm, 'u-admin', 'migbot')[2]
(: update careManager and team context :)
let $cm := eoc:careManager($ps)
let $update := r-eoc:updateCMandTeam($realm, 'u-admin', 'migbot'
        , $eocs/fhir:id/@value/string()
        , $cm/fhir:reference/@value/string(), $cm/fhir:display/@value/string()
        , concat('nabu/careteams/',$cts/fhir:id/@value), $cts/fhir:name/@value/string())

return
    ()