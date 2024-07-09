xquery version "3.0";

import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-order        = "http://enahar.org/exist/restxq/nabu/orders"         at "../FHIR/Order/order-routes.xqm";
import module namespace r-patient      = "http://enahar.org/exist/restxq/nabu/patients"       at "../FHIR/Patient/patient-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners" at "/db/apps/metis/Practitioner/practitioner-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

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

declare function local:fillOrder($e,$pid,$pnam,$auid) as item()*
{

let $wgroup  := local:toGroup($e/TerminArt/string())
let $actor   := if ($auid != '')
        then let $a := r-practitioner:practitionerByID($auid, 'kikl-spz', 'u-admin','true')
            return
                if ($a/fhir:id/@value)
                then $a
                else util:log-app('DEBUG', 'nabu', concat('Actor not found: ',$auid))
        else ()
let $aref    := 
        if ($auid != '')
        then concat('metis/practitioners/', $auid)
        else ''
let $anam    := string-join(
             ( $actor/fhir:name/fhir:family/@value
             , $actor/fhir:name/fhir:given/@value
             ), ', ')
let $prio    := $e/TerminPriorität/string()
let $priotext := switch($prio)
    case '0' return 'dringend'
    case '10' return 'normal'
    default return 'normal'
let $eintrag := $e/DatumEintrag/string()
let $summary := $e/TerminKommentar/string()
let $termin  := if ($e/TerminZeitraum="")
        then "2016-01-01"
        else concat(substring($e/TerminZeitraum,1,4),'-',substring($e/TerminZeitraum,5,2),'-15')
return
<Order xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionID value="0"/>
    </meta>
    <identifier/>
    <date value="{$eintrag}"/>
    <subject>
        <reference value="{concat('nabu/patients/',$pid)}"/>
        <display value="{$pnam}"/>
    </subject>
    <source>
        <reference value="metis/practitioners/u-admin"/>
        <display value="reload-wl"/>
    </source>
    <target>
        <role value="spz-ateam"/>
        <reference value=""/>
        <display value=""/>
    </target>
    <reason>
        <coding>
            <system value="#encounter-reason"/>
            <code value="appointment"/>
            <display value="Ambulanter Besuch"/>
        </coding>
        <text value="Ambulanter Besuch"/>
    </reason>
    <authority>
        <reference value="metis/organizations/kikl-spz"/>
        <display value="SPZ Kinderklinik"/>
    </authority>
    <when>
        <code>
            <coding>
                <system value="#order-when"/>
                <code value="{$prio}"/>
                <display value="{$priotext}"/>
            </coding>
            <text value="{$priotext}"/>
        </code>
        <schedule>
            <event value="{$termin}"/>
        </schedule>
    </when>
    <detail id="1">
        <process value="true"/>
        <info value="{$summary}"/>
        <actor>
            <role value="{$wgroup}"/>
            <reference value="{$aref}"/>
            <display value="{$anam}"/>
            <required value="true"/>
        </actor>
        <schedule>
            <reference value=""/>
            <display value=""/>
        </schedule>
        <search>
            <start value="{$termin}"/>
            <end value=""/>
        </search>
        <duration value="60"/>
        <proposal>
            <display value=""/>
            <acq value="open"/>
        </proposal>
    </detail>
    <extension url="#order-status">
        <status>
            <coding>
                <system value="#order-status"/>
                <code value="assigned"/>
                <display value="zugewiesen"/>
            </coding>
            <text value="zugewiesen"/>
        </status>
    </extension>
</Order>
};


let $osrc := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:reason/fhir:coding/fhir:code/@value='appointment'][fhir:extension//fhir:code/@value/string() != 'assigned']

let $dates   := collection($config:nabu-imports)/dataroot/Datum
let $worker  := collection($config:nabu-imports)/dataroot/Abk_Erbringer
let $events  := collection($config:nabu-imports)/dataroot/T_WartelisteNeu

let $loguid:= 'u-admin'
let $realm := 'kikl-spz'
let $today := current-date()
let $now   := current-dateTime()


for $e in $events
let $pid := concat("p-",$e/TerminPatient)
let $pat := r-patient:patientByID($pid)
let $wgroup  := local:toGroup($e/TerminArt/string())
let $eintrag := $e/DatumEintrag/string()
let $wann:= concat(substring($e/TerminZeitraum,1,4),'-',substring($e/TerminZeitraum,5,2),'-15')
let $old := $osrc[fhir:subject/fhir:reference/@value=concat('nabu/patients/', $pid)][fhir:date/@value=$eintrag]
return
    if (count($old)>0)
        then
            ()
        else
            let $pnam := if ($pat/fhir:id/@value)
                then concat($pat/fhir:name/fhir:family/@value,", ",$pat/fhir:name/fhir:given/@value," *", $pat/fhir:birthDate/@value)
                else util:log-app('DEBUG', 'nabu', concat('Patient not found: ', $pid))
            let $auid := $worker[E_Nr = $e/TerminErbringer]/E_Text/@uid
            let $order := local:fillOrder($e,$pid,$pnam,$auid)
            let $store :=  if ($pat/fhir:id/@value)
                then r-order:putOrder(<content>{$order}</content>, $realm, $loguid)
                else util:log-app('DEBUG', 'nabu', 'Order not stored')
            return
                ()