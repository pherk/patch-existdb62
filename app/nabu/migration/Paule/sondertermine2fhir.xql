xquery version "3.0";


import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-appointment = "http://enahar.org/exist/restxq/nabu/appointments"    at "../FHIR/Appointment/appointment-routes.xqm";

(: 
    <Sondertermine>
        <I_Sondertermin>46953</I_Sondertermin>
        <F_Datum>3803</F_Datum>
        <F_Erbringer>95</F_Erbringer>
        <D_Anfang>1899-12-30T14:00:00</D_Anfang>
        <D_Ende>1899-12-30T15:00:00</D_Ende>
        <D_Inhalt>Team fällt heute aus!!!</D_Inhalt>
    </Sondertermine>
:)

declare function local:fillAppointment($e,$date,$w) as item()*
{
let $wname := $w/E_Text/string()
let $alias := $w/E_Text/@alias/string()
let $wgroup:= lower-case($w/E_Gruppe/string())

let $starttime := tokenize($e/D_Anfang,'T')[2]
let $endtime   := tokenize($e/D_Ende, 'T')[2]
let $start   := xs:dateTime(concat($date,'T',$starttime))
let $end     := xs:dateTime(concat($date,'T',$endtime))
let $summary := $e/D_Kommentar/string()
return
<Appointment xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionID value="0"/>
    </meta>
    <priority value="0"/>
    <status value="active"/>
    <type>
        <coding>
            <system value="#appoinment-type"/>
            <code value="sonder"/>
            <display value="Sondertermin"/>
        </coding>
        <text value="Sondertermin"/>
    </type>
    <reason>
        <coding>
            <system value="#appointment-reason"/>
            <code value="sonder"/>
            <display value="Sondertermin"/>
        </coding>
        <text value="Sondertermin"/>
    </reason>
    <description value="{$summary}"/>
    <start value="{$start}"/>
    <end value="{$end}"/>
    <location>
        <reference value="metis/organizations/kikl-spz"/>
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
                <code value="{$wgroup}"/>
                <display value="{$wgroup}"/>
            </coding>
            <text value="{$wgroup}"/>
        </type>
        <actor>
            <reference value="metis/practitioners/{$alias}"/>
            <display text="{$wname}"/>
        </actor>
        <required value="req"/>
        <status value="accepted"/>
    </participant>
</Appointment>
};


let $dates   := collection($config:nabu-patients)/dataroot/Datum
let $worker  := collection($config:nabu-patients)/dataroot/Abk_Erbringer
let $events  := collection($config:nabu-patients)/dataroot/Sondertermine

let $loguid := 'u-admin'
let $realm := 'kikl-spz'
let $today := current-date()
let $now   := current-dateTime()
for $e in $events
let $date := if ($e/F_Datum="0")
    then "2014-01-01"
    else $dates[I_Datum=$e/F_Datum]/D_Datum/string()
let $w    := $worker[E_Nr=$e/F_Erbringer]

let $app := local:fillAppointment($e,$date,$w)
(: let $store := r-appointmentr:create-or-edit-appointment(<content>{$app}</content>, $realm, $loguid) :)
return $app

