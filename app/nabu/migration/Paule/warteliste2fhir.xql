xquery version "3.0";


import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-order        = "http://enahar.org/exist/restxq/nabu/orders"         at "../FHIR/Order/order-routes.xqm";
import module namespace r-patient      = "http://enahar.org/exist/restxq/nabu/patients"       at "../FHIR/Patient/patient-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners" at "/db/apps/metis/Practitioner/practitioner-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

(: 
    <T_WartelisteNeu>
        <ID>15526</ID>
        <DatumEintrag>2014-05-09T00:00:00</DatumEintrag>
        <TerminPatient>23243</TerminPatient>
        <TerminArt>Logopädie</TerminArt>
        <TerminZeitraum/>
        <TerminPrioritaet>10</TerminPrioritaet>
        <TerminKommentar>Logo Bayley bitte vor Arzt 30.09.2014 SA</TerminKommentar>
        <TerminWV>0</TerminWV>
    </T_WartelisteNeu>
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

declare function local:fillOrder($e,$date,$pid,$pnam,$walias) as item()*
{

let $wgroup  := local:toGroup($e/TerminArt/string())
let $actor   := if ($walias)
        then let $a := r-practitioner:practitionerByIdentifier($walias, 'kikl-spz', 'u-admin','true')
            return
                if ($a/fhir:id/@value)
                then $a
                else util:log-app('DEBUG', 'nabu', $walias)
        else ()
let $aref    := 
        if ($actor/fhir:id/@value)
        then concat('metis/practitioners/', $actor/fhir:id/@value)
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
let $termin  := concat(substring($e/TerminZeitraum,1,4),'-',substring($e/TerminZeitraum,5,2),'-15')
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
        <display value="ImportBot"/>
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


let $dates   := collection($config:nabu-imports)/dataroot/Datum
let $worker  := collection($config:nabu-imports)/dataroot/Abk_Erbringer
let $events  := collection($config:nabu-imports)/dataroot/T_WartelisteNeu

let $loguid := 'u-admin'
let $realm := 'kikl-spz'
let $today := current-date()
let $now   := current-dateTime()

for $e in $events[ID='19560']
let $date := if ($e/TerminZeitraum="")
    then "2015-01-01"
    else concat(substring($e/TerminZeitraum,1,4),'-',substring($e/TerminZeitraum,5,2),'-01')
let $pid := concat("p-",$e/TerminPatient)
let $d    := r-patient:patientByID($pid)
let $log := if (not($d/fhir:id))
    then util:log-app('INFO', 'nabu', "import orders: pat not found: " || $pid)
    else
        let $pnam := concat($d/fhir:name/fhir:family/@value,", ",$d/fhir:name/fhir:given/@value," *", $d/fhir:birthDate/@value)
        let $walias := substring-after($worker[E_Nr=$e/TerminErbringer]/E_Text/@alias,'u-')
        let $order := local:fillOrder($e,$date,$pid,$pnam,$walias)
        let $store := r-order:putOrder(<content>{$order}</content>, $realm, $loguid, "admin")
        return $order
return
    $log

