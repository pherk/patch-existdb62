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


let $aos2511 := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:reason/fhir:coding/fhir:code/@value='appointment'][matches(fhir:lastModified/@value,'2015-11-25T17')]

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
let $old := $aos2511[fhir:subject/fhir:reference/@value=concat('nabu/patients/', $pid)][fhir:detail/fhir:actor/fhir:role/@value=$wgroup][fhir:date/@value=$eintrag][fhir:detail/fhir:info/@value=$e/TerminKommentar]
return
    if (count($old)=1)
        then
            let $pnam := concat($pat/fhir:name/fhir:family/@value,", ",$pat/fhir:name/fhir:given/@value," *", $pat/fhir:birthDate/@value)
            let $walias := substring-after($worker[E_Nr=$e/TerminErbringer]/E_Text/@alias,'u-')
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
            let $prio    := switch($e/TerminPriorität/string())
                case '0' return 'high'
                case '10' return 'medium'
                default return 'medium'
            let $priotext := switch($prio)
                case '0' return 'dringend'
                case '10' return 'normal'
                default return 'normal'   
            let $obase := $old/fhir:*[not(self::fhir:detail) and not(self::fhir:when)]
            let $when  :=
                <when xmlns="http://hl7.org/fhir">
                    <code>
                        <coding>
                            <system value="#order-when"/>
                            <code value="{$prio}"/>
                            <display value="{$priotext}"/>
                        </coding>
                        <text value="{$priotext}"/>
                    </code>
                    <schedule>
                        <event value="{$wann}"/>
                    </schedule>
                </when>
            let $details := for $d in $old/fhir:detail
                      let $dbase := $d/fhir:*[not(self::fhir:search)][not(self::fhir:actor)]
                      return
                        <detail xmlns="http://hl7.org/fhir" id="{$d/@id/string()}">
                            { $dbase }
                            <actor>
                                <role value="{$wgroup}"/>
                                <reference value="{$aref}"/>
                                <display value="{$anam}"/>
                                <required value="true"/>
                            </actor>
                            <search>
                                <start value="{$wann}"/>
                                <end value=""/>
                            </search>
                        </detail>
            let $order :=
                <Order xmlns="http://hl7.org/fhir" xml:id="{$old/@xml:id/string()}">
                    { $obase }
                    { $when }
                    { $details }
                </Order>
            let $store := r-order:putOrder(<content>{$order}</content>, $realm, $loguid)
            return ()
    else
        concat($pid, ':', $e/ID)