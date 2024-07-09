xquery version "3.0";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-contact = "http://enahar.org/exist/restxq/nabu/contact"  at "../contact/contact-routes.xqm";


declare function local:fill-contact-template($c, $ab) as item()
{
    let $gender := if ($c/KA_Anrede=('Herr','Herrn'))
        then 'm'
        else if ($c/KA_Anrede='Frau')
        then 'w'
        else ''
    let $type := if ($c/KA_Anrede=('Praxis','Firma'))
        then 'nonperson'
        else 'person'
    let $kianr := $c/KA_Nr/string()
    let $tags  := ( )
return
<contact>
    <id>c-{$kianr}</id>
    <version>0</version>
    <identifier>
        <use value="official"/>
        <type value="Paule"/>
        <system value="http://enahar.org/paule"/>
        <value value="{$kianr}"/>
    </identifier>
    <relation>adr-db</relation>
    <start/>
    <end/>
    <active>true</active>
    <deleted>false</deleted>
    <person>
        <type>{$type}</type>
        <n>
            <honorific-prefix>{$c/KA_Titel/string()}</honorific-prefix>
            <given-name>{$c/KA_Vorname/string()}</given-name>
            <additional-name/>
            <family-name>{$c/KA_Name/string()}</family-name>
        </n>
        <adr>
            <street-address>{$c/KA_Strasse/string()}</street-address>
            <extended-address/>
            <locality>{$c/KA_Ort/string()}</locality>
            <region>NW</region>
            <postal-code>{$c/KA_PLZ/string()}</postal-code>
            <country>DE</country>
        </adr>
        <tels>
            <tel type="home">{$c/KA_Telefon/string()}</tel>
            <tel type="mobil1"/>
            <tel type="mobil2"/>
            <tel type="fax">{$c/KA_Telefax/string()}</tel>
        </tels>
        <gender>{$gender}</gender>
        <email>{$c/KA_Email/string()}</email>
        <internet>{$c/KA_Internet/string()}</internet>
        <profession>{concat($c/KA_Funktion/string(), './.', $c/KA_Fachrichtung/string())}</profession>
        <note></note>
    </person>
    <note>{$c/KA_Bemerkungen/string()}</note>
    <tags>
        <super>{$ab[ID=$c/KA_Bereich]/Bereich/@super/string()}</super>
        <tag>{$ab[ID=$c/KA_Bereich]/Bereich/string()}, invalid</tag>
    </tags>
</contact>
};

let $contacts    := collection($config:nabu-patients)/dataroot/Arzt
let $adr-bereich := collection($config:nabu-patients)/dataroot/Adr_Bereiche
let $loguid := 'u-admin'
let $realm := 'kikl-spz'

for $pc in $contacts
let $contact := local:fill-contact-template($pc,$adr-bereich)
return
     r-contact:create-or-edit-contact(<contact>{$contact}</contact>, $realm, $loguid)

    