xquery version "3.0";


import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients"  at "../FHIR/Patient/patient-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "/db/apps/metis/Practitioner/practitioner-routes.xqm";
import module namespace r-organization = "http://enahar.org/exist/restxq/metis/organizations"  at "/db/apps/metis/Organization/organization-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";


declare function local:fill-demographics-template($realm, $loguid, $p) as item()
{
let $pnr := $p/P_Nr/string()
let $knr := $p/KA_Nr/string()
let $kia := if ($knr ne '0')
    then let $c := r-practitioner:practitionerByID(concat('c-',$knr), $realm, $loguid, 'true')
        let $res := if ($c/fhir:Patient)
            then let $name := concat($c//fhir:name/fhir:given/@value,' ',$c//fhir:name/fhir:family/@value)
                let $cid := $c//fhir:id/@value/string()
                return
                    <careProvider xmlns="http://hl7.org/fhir">
                        <reference value="metis/practitioners/{$cid}"/>
                        <display value="{$name}"/>
                        <period>
                            <start value=""/>
                            <end value=""/>
                        </period>
                    </careProvider>
            else ()
        return $res
    else ()
let $status := if ($p/P_Privat='1')
    then 'pkv'
    else 'gkv'
let $oe := if(matches($p/P_Name,'(P)'))
    then '0739'
    else '0734'
let $fname := if(matches($p/P_Name,'(P)'))
    then replace($p/P_Name, '\(P\)', '')
    else $p/P_Name/string()
let $vname := $p/P_Vorname/string()
let $gender := if ($p/P_Geschlecht='m') then 'male' else if ($p/P_Geschlecht='w') then 'female' else 'unknown'
let $gebdat := tokenize($p/P_Geb_Dat,'T')[1]
let $verstorben := if (matches($p/P_Aus_Grund,'verstorb'))
      then let $ausGrund := $p/P_Aus_Grund/string()
        return  (
                  <deceasedBoolean  xmlns="http://hl7.org/fhir" value="true"/>
                , <deceasedDateTime xmlns="http://hl7.org/fhir" value="{$ausGrund}"/>
                )
        else    <deceasedBoolean  xmlns="http://hl7.org/fhir" value="false"/>
let $strasse := $p/P_Strasse/string()
let $ort     := $p/P_Ort/string()
let $plz     := $p/P_PLZ/string()
let $first   := $p/P_Erstkontaktdatum/string()
let $grund   := $p/P_Vorstellungsgrund/string()
let $kasse   := $p/P_Krankenkesse/string()
let $tel     := $p/P_Telefon/string()
let $active  :=  if ($p/P_Ausgeschierden='1') then 'false' else 'true'
return
<Patient xmlns="http://hl7.org/fhir" xml:id="p-{$pnr}">
    <id value="p-{$pnr}"/>
    <meta>
        <versionID value="0"/>
    </meta>
    <identifier>
        <use value="usual"/>
        <type value="ORBIS-PNR"/>
        <system value="http://uk-koeln.de/#patient-orbis-pnr"/>
        <value value=""/>
        <assigner>
            <reference value="metis/organizations/ukk"/>
            <display value="Unikliniken Köln"/>
        </assigner>
    </identifier>
    <name>
        <use value="official" />
        <family value="{$fname}" />
        <given value="{$vname}"/>
    </name>
    <gender value="{$gender}"/>
    <birthDate value="{$gebdat}"/>
    { $verstorben }
    <address>
        <use value="home"/>
        <line value="{$strasse}"/>
        <city value="{$ort}"/>
        <state value="NW"/>
        <postalCode value="{$plz}"/>
        <country value="DEU"/>
        <period>
            <start value="{$first}"/>
            <end value=""/>
        </period>
        <preferred value="true"/>
    </address>
    <telecom>
        <use value="home"/>
        <system value="phone"/>
        <value value="{$tel}"/>
        <preferred value="true"/>
    </telecom>
    <communication>
        <coding>
            <system value="urn:ietf:bcp:47"/>
            <!--   IETF language tag   -->
            <code value="de"/>
            <display value="Deutsch"/>
        </coding>
        <text value="Deutsch"/>
    </communication>
    <extension url="#patient-presenting-problem">
        <presenting-problem value="{$grund}"/>
    </extension>
    {local:contact($p) }
    <extension  url="#patient-insurance">
        <medical-insurance>
            <type value="{$status}"/>
            <name value="{$kasse}"/>
        </medical-insurance>
    </extension>
    {$kia}
    <managingOrganization>
        <reference value="metis/organizations/ukk-oe{$oe}"/>
        <display value="SPZ OE{$oe}"/>
    </managingOrganization>
    <active value="{$active}"/>
</Patient>
};
(: 
    <preterm>
        <gba>keine</gba>
        <weight/>
        <gestationalAgeAtBirth>
            <week/>
            <day/>
        </gestationalAgeAtBirth>
    </preterm>
    <additional-infos>
        <migration>
            <father></father>
            <mother></mother>
        </migration>
        <ethnicity/>
        <note>{$p/P_Aus-Grund/string()}</note>
    </additional-infos>
:)

declare function local:contact($p) as item()*
{
    if (not($p/V_Name=''))
    then 
        let $family-name := $p/V_Name/string()
        let $given-name  := $p/V_Vorname/string()
        return
        <contact  xmlns="http://hl7.org/fhir">
            <relationship>
                <coding>
                    <system value="http://hl7.org/fhir/vs/patient-contact-relationship"/>
                    <code value=""/>
                    <display value="???"/>
                </coding>
                <text value="???"/>
            </relationship>
            <extension url="confidentiality">
                    <coding>
                        <system value="#nabu-confidentiality"/>
                        <code value="auth"/>
                        <display value="SPE liegt vor"/>
                    </coding>
            </extension>
            <preferred value="true"/>
            <period>
                <start value=""/>
                <end value=""/>
            </period>
            <gender value="unknown"/>
            <name>
                <use value="official" />
                <given value="{$given-name}"/>
                <family value="{$family-name}"/>
            </name>
            <extension url="#contact-note">
                <note value=""/>
            </extension>
        </contact>
    else ()
};

let $import-patients    :=  collection($config:nabu-root)/dataroot/Patienten 

(: 
KiGGS 2003–2006

Als Kinder und Jugendliche mit beidseitigem Migrationshintergrund werden daraus abgeleitet
Kinder und Jugendliche definiert,
die selbst aus einem anderen Land zugewandert sind
und
von denen mindestens ein Elternteil
nicht in Deutschland geboren ist,
oder
von denen beide Eltern zugewandert und/oder
nichtdeutscher Staatsangehörigkeit sind 
Import vom 28-05-2014 #23157-23
:)
let $loguid := 'u-admin'
let $realm := 'kikl-spz'
let $last-imported-pnr := 24120 (: Malla, Calogero *2010-05-22 :)
for $pat in $import-patients
let $demo  := local:fill-demographics-template($realm, $loguid, $pat)
let $store := r-patient:putPatientXML(<content>{$demo}</content>, $realm, $loguid)
return ()
