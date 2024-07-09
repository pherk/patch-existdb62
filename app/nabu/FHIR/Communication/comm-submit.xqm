xquery version "3.1";
module namespace commsub = "http://enahar.org/exist/apps/nabu/comm-submit";


import module namespace r-comm = "http://enahar.org/exist/restxq/nabu/communications" at "/db/apps/nabu/FHIR/Communication/communication-routes.xqm";
import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients"    at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";

import module namespace letter = "http://enahar.org/exist/apps/nabu/letter"           at "/db/apps/nabu/FHIR/Communication/letter.xqm";

declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";

declare variable $commsub:infos := collection('/db/apps/nabu/FHIR/Communication')/fhir:Communication; 
(:~
 : submitInfoLetter
 : submit appointment letter to family
 : called by appointment-routes.xqm
 :
 : @param $realm
 : @param $loguid
 : @param $order
 : @param $oldapps
 : @param $newapps

 : 
 : @return ()
 :)
declare function commsub:submitInfoLetter(
      $realm as xs:string
    , $loguid as xs:string
    , $lognam as xs:string
    , $action as xs:string
    , $pid as xs:string
    , $oldapps as element(encounters)
    , $newapps as element(fhir:Encounter)*
    , $status as xs:string
    )
{
let $lll := util:log-app('TRACE','apps.nabu',concat('InfoLetter: ',$loguid,':',$lognam))
    let $patient := r-patient:patientByIDXML($pid, $realm, $loguid, $lognam)
    let $pnam := r-patient:formatFHIRName($patient)
let $lll := util:log-app('TRACE','apps.nabu',$pnam)
let $lll := util:log-app('TRACE','apps.nabu',$action)
let $lll := util:log-app('TRACE','apps.nabu',count($oldapps/fhir:Encounter))
let $lll := util:log-app('TRACE','apps.nabu',count($newapps))
    let $contacts := if ($patient//fhir:contact[./fhir:extension[@url='#patient-contact-preferred']/fhir:valueBoolean/@value='true'])
        then $patient//fhir:contact
        else $patient
    let $groups := commsub:splitEncounters($newapps, $oldapps/fhir:Encounter)
let $lll := util:log-app('TRACE','apps.nabu',$contacts)
let $lll := util:log-app('TRACE','apps.nabu',$groups)
    let $sender :=
            <sender xmlns="http://hl7.org/fhir">
                <reference value="{concat('metis/practitioners/',$loguid)}"/>
                <display value="{$lognam}"/>
            </sender>
    let $subject :=
            <subject xmlns="http://hl7.org/fhir">
                <reference value="{concat('nabu/patients/',$pid)}"/>
                <display value="{$pnam}"/>
            </subject>
    let $ret := for $contact in $contacts
        let $address := letter:infoAddress($contact, $patient)
        let $salute  := letter:salute($contact)
        let $recipient :=
            <recipient xmlns="http://hl7.org/fhir">
                <reference value="{concat('nabu/patients/',$pid)}"/>
                <display value="{$pnam}"/>
            </recipient>
        return
            for $group in $groups
            let $letter  := letter:content($group, $address, $pnam, $salute)
            let $note := ""
            let $content := commsub:fillTemplate($letter, $action, $sender, $recipient, $subject, $status, $note)
            let $lll := util:log-app('TRACE','apps.nabu',$content)
            return
                r-comm:putCommunicationXML(document {$content}, $realm, $loguid, $lognam)
    return
        ()
};

declare function commsub:splitEncounters(
          $new as element(fhir:Encounter)*
        , $old as element(fhir:Encounter)*
        ) as item()*
{
    let $types := for $c in distinct-values(
                (
                    $new/fhir:type/fhir:coding[fhir:system/@value="#encounter-type"]/fhir:code/@value
                ,   $old/fhir:type/fhir:coding[fhir:system/@value="#encounter-type"]/fhir:code/@value
                ))
        return
            switch($c)
            case 'amb-spz-ortho-qr' return <letter type="{$c}"><code>{$c}</code></letter>
            case 'amb-spz-eeg' return <letter type="default"><code>{$c}</code></letter>
            case 'reorder' return <letter type="default"><code>{$c}</code></letter>
            default return <letter type="default"><code>{$c}</code></letter>
    let $letters := for $t in distinct-values($types/@type)
            return
                <codes type="{$t}">
                {
                  for $c in distinct-values($types[@type=$t]/code)
                  return
                    <code>{$c}</code>
                , if ($t='default' and not('default' = $types[@type=$t]/code)) then <code>default</code> else ()
                }
                </codes>
    let $lll := util:log-app('TRACE','apps.nabu',$letters)
    for $letter in $letters
    return
        <letterinfo>
            <info>
                { commsub:info($letter) }
            </info>
            <old>
                { $old[fhir:type/fhir:coding[fhir:system/@value="#encounter-type"]/fhir:code/@value=$letter/code] }
            </old>
            <new>
                { $new[fhir:type/fhir:coding[fhir:system/@value="#encounter-type"]/fhir:code/@value=$letter/code] }
            </new>
        </letterinfo>
};

declare %private function commsub:info(
          $letter as element(codes)
        ) as element(tei:div)
{
    <div xmlns="http://www.tei-c.org/ns/1.0" type="info">
    {
    for $code in $letter/*:code/string()
    return
        switch($code)
        case 'fun-spz-eeg' return 
        $commsub:infos[fhir:category/fhir:coding[fhir:system/@value='#nabu-communication-encounter-type']/fhir:code/@value=$code]/fhir:payload/fhir:contentTEI/tei:div/*
        case 'reorder' return 
        $commsub:infos[fhir:category/fhir:coding[fhir:system/@value='#nabu-communication-encounter-type']/fhir:code/@value=$code]/fhir:payload/fhir:contentTEI/tei:div/*
        case 'amb-spz-ortho-qr' return 
        $commsub:infos[fhir:category/fhir:coding[fhir:system/@value='#nabu-communication-encounter-type']/fhir:code/@value=$code]/fhir:payload/fhir:contentTEI/tei:div/*
        case 'default' return  
        $commsub:infos[fhir:category/fhir:coding[fhir:system/@value='#nabu-communication-encounter-type']/fhir:code/@value='default']/fhir:payload/fhir:contentTEI/tei:div/*
        default return ()
    }
    </div>
};

(:~
 : fillTemplate
 : makes Communication resource
 :  
 : @param $payload TEI
 : @param $action  reference
 : @param $sender
 : @param $recipient
 : @param $subject 
 : @param $sstatus string
 : @param $note    string
 : 
 : @return Communication
 :) 
declare function commsub:fillTemplate(
          $payload as item()
        , $action as xs:string
        , $sender as item()
        , $recipient as item()
        , $subject as item()
        , $status as xs:string
        , $note as xs:string
        ) as item()
{
<Communication xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionId value="0"/>
    </meta>
    <identifier/>
    <category>
        <coding>
            <system value="#nabu-communication"/>
            <code value="info-app"/>
            <display value="Info Appointment"/>
        </coding>
        <text value="Info Appointment"/>
    </category>
    { $sender }
    { $recipient }
    { $subject }
    <about>
        <reference value="{$action}"/>
    </about>
    <payload>
        { $payload }
    </payload>
    <medium>
        <coding>
            <system value="#nabu-medium"/>
            <code value="byletter"/>
            <display value="Post"/>
        </coding>
    </medium>
    <status value="{$status}"/>
    <sent value="{adjust-dateTime-to-timezone(current-dateTime())}"/>
    <received value=""/>
    <reasonCode>
        <coding>
            <system value="#nabu-reason"/>
            <code value="info"/>
            <display value="Info"/>
        </coding>
        <text value="Info"/>
    </reasonCode>
    <note>
        <text value="{$note}"/>
    </note>
</Communication>
};
