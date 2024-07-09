xquery version "3.0";


import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-encounter    = "http://enahar.org/exist/restxq/nabu/encounters"    at "../FHIR/Encounter/encounter-routes.xqm";
import module namespace r-appointment  = "http://enahar.org/exist/restxq/nabu/appointments"  at "../FHIR/Appointment/appointment-routes.xqm";
import module namespace r-patient      = "http://enahar.org/exist/restxq/nabu/patients"       at "../FHIR/Patient/patient-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "/db/apps/metis/FHIR/Practitioner/practitioner-routes.xqm";
import module namespace r-organization = "http://enahar.org/exist/restxq/metis/organizations"  at "/db/apps/metis/FHIR/Organization/organization-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

(: 
    <Termine>
        <I_Termin>5</I_Termin>
        <F_Datum>8</F_Datum>
        <F_Erbringer>1</F_Erbringer>
        <F_Patient>2548</F_Patient>
        <D_Anfang>1899-12-30T10:30:00</D_Anfang>
        <D_Ende>1899-12-30T11:00:00</D_Ende>
        <D_Kommentar>Botox WV</D_Kommentar>
        <D_Vorlage/>
        <D_Befund_Datei/>
        <D_AkteAbgeschlossen>0</D_AkteAbgeschlossen>
    </Termine>
    <Abk_Erbringer>
        <E_Nr>1</E_Nr>
        <E_Text>Jopp-Petzinna</E_Text>
        <E_Kommentar/>
        <E_Funktion>zur ärztlichen Untersuchung</E_Funktion>
        <F_Kennzahl>1</F_Kennzahl> <!-- 1:dr, 2:dipl, 3:amb, 4:uk 5:extern-->
        <E_Exit>9999</E_Exit>
        <E_Gruppe>Arzt</E_Gruppe>
        <E_Aktiv>1</E_Aktiv>
    </Abk_Erbringer>
    <Datum>
        <I_Datum>5</I_Datum>
        <D_Datum>2004-01-05T00:00:00</D_Datum>
        <D_Wochentag>MO</D_Wochentag>
    </Datum>
:)

declare function local:toGroup($egroup as xs:string) as xs:string
{
    switch($egroup)
    case 'Arzt'             return 'spz-arzt'
    case 'Psychologie'      return 'spz-psych'
    case 'Ergotherapie'     return 'spz-ergo'
    case 'Logopädie'        return 'spz-logo'
    case 'Krankengymnastik' return 'spz-physio'
    case 'Heilpädagogik'    return 'spz-heilp'
    case 'EEG'              return 'spz-eeg'
    case 'Evozi'            return 'spz-epnlg'
    case 'Sehscreening'     return 'spz-orthoptik'
    case 'Verwaltung'       return 'spz-ateam'
    case 'Psychosomatik'    return 'spz-psychsom'
    case 'Sozialarbeit'     return 'spz-sozial'
    default return ''
};

declare function local:fillEncounter($e,$date,$w,$pid,$pnam, $now) as item()*
{
let $wname     := $w/E_Text/string()
let $alias     := $w/E_Text/@alias/string()
let $uid       := $w/E_Text/@uid/string()
(: 
let $uid   := r-practitioner:practitionerByIdentifier(
                $alias,
                'kikl-spz', 'u-admin',
                'true'
                )/fhir:id/@value/string()
:)
let $uref      := if ($uid)
    then concat('metis/practitioners/',$uid)
    else ''
let $wgroup    := local:toGroup($w/E_Gruppe/string())
let $starttime := tokenize($e/D_Anfang,'T')[2]
let $endtime   := tokenize($e/D_Ende, 'T')[2]
let $start   := xs:dateTime(concat($date,'T',$starttime))
let $end     := xs:dateTime(concat($date,'T',$endtime))
let $summary := $e/D_Kommentar/string()
let $template:= $e/D_Vorlage/string()
let $report  := $e/D_Befund_Datei/string()
let $isOrtho := matches($summary, 'ortho') or $uid=('u-ruett','u-ortho')
let $sched   := switch($uid)
    case 'u-pmh' return if ($isOrtho) then 'amb-spz-ortho' else 'amb-spz-arzt' 
    case 'u-eeg' return 'fun-spz-eeg'
    case 'u-ep'  return 'fun-spz-epnlg'
    case 'u-bont' return 'amb-spz-bont'
    case 'u-nch' return 'amb-spz-nch'
    case 'u-mma' return 'amb-spz-adipos'
    case 'u-ruettj' return 'amb-spz-ortho'
    case 'u-ortho'  return 'amb-spz-ortho'
    default return 'amb-spz'
let $role := switch ($sched)
    case 'fun-spz-eeg' return 'spz-eeg'
    case 'fun-spz-epnlg' return 'spz-epnlg'
    case 'amb-spz-bont' return 'spz-bont'
    case 'amb-spz-nch'  return 'spz-nch'
    case 'amb-spz-ortho' return 'spz-ortho'
    default return $wgroup
return
<Encounter xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionID value="0"/>
    </meta>
    <status value="finished"/>
    <class value="ambulatory"/>
    <type>
        <coding>
            <system value="#encounter-type"/>
            <code value="{$sched}"/>
            <display value="{$sched}"/>
        </coding>
        <text value="{$sched}"/>
    </type>
    <subject>
        <reference value="nabu/patients/{$pid}"/>
        <display value="{$pnam}"/>
    </subject>
    <participant>
        <type>
            <coding>
                <system value="#encounter-role"/>
                <code value="{$role}"/>
                <display value="{$role}"/>
            </coding>
            <text value="{$role}"/>
        </type>
        <actor>
            <reference value="{$uref}"/>
            <display value="{$wname}"/>
        </actor>
    </participant>
    <appointment>
        <reference value=""/>
    </appointment>
    <period>
        <start value="{$start}"/>
        <end value="{$end}"/>
    </period>
    <length/>
    <reason>
        <coding>
            <system value="#encounter-reason"/>
            <code value="amb"/>
            <display value="Ambulanter Besuch"/>
        </coding>
        <text value="Ambulanter Besuch"/>
    </reason>
    <indication>
        <display value="{$summary}"/>
    </indication>
    <priority/>
    <serviceProvider>
        <reference value="metis/organizations/kikl-spz"/>
        <display value="SPZ Kinderklinik"/>
    </serviceProvider>
    <partOf>
        <reference value=""/>
        <display value=""/>
    </partOf>
</Encounter>
};

declare function local:fillAppointment($e,$date,$w,$pid,$pnam,$now) as item()*
{
let $wname := $w/E_Text/string()
let $alias := $w/E_Text/@alias/string()
let $uid   := $w/E_Text/@uid/string()
(: 
let $uid   := r-practitioner:practitionerByIdentifier(
                $alias,
                'kikl-spz', 'u-admin',
                'true'
                )/fhir:id/@value/string()
:)
let $uref      := if ($uid)
    then concat('metis/practitioners/',$uid)
    else ''
let $wgroup:= local:toGroup($w/E_Gruppe/string())
let $starttime := tokenize($e/D_Anfang,'T')[2]
let $endtime   := tokenize($e/D_Ende, 'T')[2]
let $start   := xs:dateTime(concat($date,'T',$starttime))
let $end     := xs:dateTime(concat($date,'T',$endtime))
let $summary := $e/D_Kommentar/string()
let $isOrtho := matches($summary, 'ortho')
let $sched   := switch($uid)
    case 'u-pmh' return if ($isOrtho) then 'amb-spz-ortho' else 'amb-spz-arzt' 
    case 'u-eeg' return 'fun-spz-eeg'
    case 'u-ep'  return 'fun-spz-epnlg'
    case 'u-bont' return 'amb-spz-bont'
    case 'u-nch' return 'amb-spz-nch'
    case 'u-mma' return 'amb-spz-adipos'
    case 'u-ruettj' return 'amb-spz-ortho'
    case 'u-ortho'  return 'amb-spz-ortho'
    default return 'amb-spz'
let $role := switch ($sched)
    case 'fun-spz-eeg' return 'spz-eeg'
    case 'fun-spz-epnlg' return 'spz-epnlg'
    case 'amb-spz-bont' return 'spz-bont'
    case 'amb-spz-nch'  return 'spz-nch'
    case 'amb-spz-ortho' return 'spz-ortho'
    default return $wgroup
    let $dur   := ($end - $start) div xs:dayTimeDuration('PT1M')
    let $now   := adjust-dateTime-to-timezone(current-dateTime(),())
return
<Appointment xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionID value="0"/>
    </meta>
    <priority value="0"/>
    <status value="booked"/>
    <type>
        <coding>
            <system value="#appointment-type"/>
            <code value="{$sched}"/>
            <display value="{$sched}"/>
        </coding>
        <text value="{$sched}"/>
    </type>
    <serviceCategory></serviceCategory>
    <serviceType></serviceType>
    <specialty></specialty>
    <appointmentType></appointmentType>
    <reason>
        <coding>
            <system value="#appointment-reason"/>
            <code value="appointment"/>
            <display value="Ambulanter Termin"/>
        </coding>
        <text value="Ambulanter Termin"/>
    </reason>
    <description value="{$summary}"/>
    <start value="{$start}"/>
    <end value="{$end}"/>
    <minutesDuration value="{$dur}"/>
    <created value="{$now}"/>
    <location>
        <reference value="metis/locations/kikl-spz"/>
        <display value="SPZ Kinderklinik"/>
    </location>
    <comment value=""/>
    <order>
        <reference value=""/>
    </order>
    <participant>
        <type>
            <coding>
                <system value="#appointment-role"/>
                <code value="patient"/>
                <display value="Patient"/>
            </coding>
            <text value="Patient"/>
        </type>
        <actor>
            <reference value="nabu/patients/{$pid}"/>
            <display value="{$pnam}"/>
        </actor>
        <required value="req"/>
        <status value="accepted"/>
    </participant>
    <participant>
        <type>
            <coding>
                <system value="#appointment-role"/>
                <code value="{$wgroup}"/>
                <display value="{$wgroup}"/>
            </coding>
            <text value="{$wgroup}"/>
        </type>
        <actor>
            <reference value="{$uref}"/>
            <display value="{$wname}"/>
        </actor>
        <required value="req"/>
        <status value="accepted"/>
    </participant>
</Appointment>
};
(: 
    <note>
    { if ($report ne '')
        then <report>
                <template>{$template}</template>
                <file>{$report}</file>
            </report>
        else ()
    }
    </note>
:)

let $dataroot  := collection($config:nabu-imports)/dataroot

let $loguid := 'u-admin'
let $realm := 'kikl-spz'
let $today := current-date()
let $now   := current-dateTime()

for $e in $dataroot/Termine

let $date := if ($e/F_Datum="0")
    then "2004-01-01"
    else $dataroot/Datum[I_Datum=xs:integer($e/F_Datum)]/D_Datum/string()
    
let $w    := $dataroot/Abk_Erbringer[E_Nr=$e/F_Erbringer]
let $d    := r-patient:patientByID(concat("p-",$e/F_Patient))
let $pid  := $d/fhir:id/@value/string()
let $log := if (empty($d))
    then util:log-system-out("import events: pat not found" || $e/F_Patient/string())
    else if (count($d) >1)
    then util:log-system-out("import events: duplicate id: " || $d[1]/fhir:id/@value/string())
    else ()
let $pnam := concat($d/fhir:name/fhir:family/@value,", ",$d/fhir:name/fhir:given/@value," *",$d/fhir:birthDate/@value)

return
    try {
        let $store := if ($w) then 
            if (xs:date($date) < $today) then
                let $enc := local:fillEncounter($e,$date,$w,$pid,$pnam, $now)
                let $store := r-encounter:putEncounter(<content>{$enc}</content>, $realm, $loguid, "admin")
                return ()
            else
                let $app := local:fillAppointment($e,$date,$w,$pid,$pnam, $now)
                let $store := r-appointment:putAppointment(<content>{$app}</content>, $realm, $loguid, "admin")
                return ()
                
            else $e
        return $store
    } catch * {
        $e
    }
