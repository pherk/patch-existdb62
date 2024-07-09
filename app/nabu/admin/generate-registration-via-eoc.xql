xquery version "3.0";


import module namespace r-goal = "http://enahar.org/exist/restxq/nabu/goals" at "/db/apps/nabu/FHIR/Goal/goal-routes.xqm";
import module namespace r-eoc  = "http://enahar.org/exist/restxq/nabu/eocs" at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare-routes.xqm";

declare namespace fhir= "http://hl7.org/fhir";

declare function local:putGoal(
      $sref as xs:string
    , $eoc as element(fhir:EpisodeOfCare)
    , $os as element(fhir:Order)*
    , $es as element(fhir:Encounter)*
    , $today as xs:string
    ) as xs:string
{
    let $snam  := $eoc/fhir:subject/fhir:display/@value/string()
    let $start := substring($eoc/fhir:period/fhir:start/@value,1,10)
    let $due   := xs:date($start) + xs:dayTimeDuration("P180D")
    let $eoca  : = $eoc/../fhir:EpisodeOfCare[fhir:status[@value=('planned','active','waitlist','on-hold')]]
    let $eocc  : = $eoc/../fhir:EpisodeOfCare[fhir:status[@value=('cancelled','finished')]]
    let $rstatus := if ($eocc  and count($eoca)=0)
        then if ($es and count($es/../fhir:Encounter[fhir:status[@value='finished']]) > 0)
            then 'achieved'
            else $eocc[1]/../fhir:EpisodeOfCare/fhir:status/@value/string()
        else if ($es and count($es/../fhir:Encounter[fhir:status[@value='finished']]) > 0)
        then 'achieved'
        else if ($es and count($es/../fhir:Encounter[fhir:status[@value='planned']]) > 0)
        then 'planned'
        else if ($os and count($os/../fhir:Order[fhir:status[@value!='cancelled']]) > 0)
        then 'order'
        else if ($eoca and ($eoca/fhir:statusHistory/fhir:extension[@url='#eoc-workflow-change']/fhir:valueCodeableConcept/fhir:coding[fhir:code/@value='registration-form'])>0)
        then 'infos'
        else 'new'
    let $lcs := switch($rstatus)
        case 'new' return 'proposed'
        case 'infos' return 'accepted'
        case 'order' return 'active'
        case 'planned' return 'active'
        case 'achieved' return 'completed'
        default return 'proposed'
    let $as := switch($rstatus)
        case 'new' return 'in-progress'
        case 'infos' return 'in-progress'
        case 'order' return 'improving'
        case 'planned' return 'achieved'
        case 'achieved' return 'sustaining'
        default return 'in-progress'
    let $asd := switch($rstatus)
        case 'new' return 'in Arbeit'
        case 'infos' return 'in Arbeit'
        case 'order' return 'Besserung'
        case 'planned' return 'erreicht'
        case 'achieved' return 'nachhaltig erreicht'
        default return 'in Arbeit'
    let $sd := switch($rstatus)
        case 'new' return $start
(: 
        case 'infos' return min(for $e in $eoca/../fhir:EpisodeOfCare[fhir:statusHistory/fhir:extension[@url='#eoc-workflow-change']/fhir:valueCodeableConcept/fhir:coding[fhir:code/@value='registration-form']]
                                return
                                    substring($e/fhir:period/fhir:start/@value,1,10))
:)
        case 'order' return min(for $o in $os/../fhir:Order[fhir:status[@value!='cancelled']]
                                return
                                    substring($o/fhir:date/@value,1,10))

        case 'planned' return min(for $e in $es/../fhir:Encounter[fhir:status[@value='planned']]
                                return
                                    substring($e/fhir:period/fhir:start/@value,1,10))
        case 'achieved' return min(for $e in $es/../fhir:Encounter[fhir:status[@value='finished']]
                                return
                                    substring($e/fhir:period/fhir:start/@value,1,10))
        default return $today
    let $data := 
        <Goal xmlns="http://hl7.org/fhir">
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <lifecycleStatus value="{$lcs}"/>
            <achievementStatus>
                <coding>
                    <system value="http://hl7.org/fhir/ValueSet/goal-achievement"/>
                    <code value="{$as}"/>
                    <display value="{$asd}"/>
                </coding>
                <text value="{$asd}"/>
            </achievementStatus>
            <category>
                <coding> 
                    <system value="http://hl7.org/fhir/ValueSet/goal-category"/> 
                    <code value="registration"/> 
                    <display value="Anmeldung"/>
                </coding>  
                <text value="Anmeldung"/>
            </category>
            <priority>
                <coding> 
                    <system value="http://hl7.org/fhir/ValueSet/goal-priority"/> 
                    <code value="medium-priority"/> 
                    <display value="mittel"/> 
                </coding> 
                <text value="mittel"/>                
            </priority>
            <description>
                <coding>
                    <system value="http://eNahar.org/nabu/extension#nabu-finding"/>
                    <version value="2017"/>
                    <code value=""/>
                    <display value=""/>
                </coding>
                <text value=""/>
            </description>
            <subject>
                <reference value="{$sref}"/>
                <display value="{$snam}"/>
            </subject>
            <startDate value="{$start}"/>
            <target>
                <measure>
                    <coding>
                        <system value="http://hl7.org/fhir/ValueSet/observation-codes"/>
                        <code value=""/>
                        <display value=""/>
                    </coding>
                    <text value=""/>                    
                </measure>
                <dueDate value="{$due}"/>
            </target>
            <outcomeCode>
                <coding>
                    <system value="http://hl7.org/fhir/ValueSet/clinical-findings"/>
                    <code value=""/>
                    <display value=""/>
                </coding>
                <text value=""/>
            </outcomeCode>
            <statusDate value="{$sd}"/>
            <statusReason value="{$asd}"/>
            <expressedBy>
                <reference value=""/>
                <display value=""/>
            </expressedBy>
        </Goal>
    let $lll := util:log-app("TRACE","apps.nabu",$data)
    let $upd := r-goal:putGoalXML(document{$data},'kikl-spzn','u-admin','admin')
    return
        $rstatus
};


let $ecs  := collection('/db/apps/nabuEncounter/data')
let $gcs  := collection('/db/apps/nabuCom/data/Goals')
let $ocs  := collection('/db/apps/nabuData/data/FHIR/Orders')
(: Alle Patienten ohne Termin finished :)
let $eocp := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value='planned']]

for $eoc in $eocp
let $sref := $eoc/fhir:subject/fhir:reference/@value/string()
let $gs := count($gcs/fhir:Goal[fhir:subject[fhir:reference/@value=$sref]]) > 0
let $hasActiveRegGoal := count($gs/../fhir:Goal[fhir:lifecycleStatus[@value=('proposed','accepted','active')]][fhir:category/fhir:coding[fhir:code/@value="registration"]]) > 0
let $os := $ocs/fhir:Order[fhir:subject/fhir:reference[@value=$sref]]
let $es := $ecs/fhir:Encounter[fhir:subject[fhir:reference/@value=$sref]]
let $today := adjust-date-to-timezone(current-date(),())
return
    if ($hasActiveRegGoal)
    then ()
    else local:putGoal($sref,$eoc,$os,$es,$today)

