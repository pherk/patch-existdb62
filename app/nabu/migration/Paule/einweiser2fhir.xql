xquery version "3.0";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "/db/apps/metis/FHIR/Practitioner/practitioner-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare function local:fill-template($realm as xs:string, $loguid as xs:string, $c as item())
{
    let $cid   := concat("c-", util:uuid())
    let $title := if (normalize-space($c/td[2]/p/string()) = ("Dr. med.","Dr.med."))
        then "drmed"
        else ()
    let $name := tokenize($c/td[3]/p,',')
    let $given := $name[2]
    let $family:= $name[1]
    let $street-address := $c/td[4]/p/string()
    let $extended-address := ""
    let $locality := $c/td[6]/p/string()
    let $region := ""
    let $postal-code := $c/td[5]/p/string()
    let $tel  := $c/td[7]/p/string()
    let $fax  := $c/td[8]/p/string()
    let $email := ""
    let $internet := ""
    let $gender := "unknown"
    let $profession := "arzt"
    let $super := ()
    let $note  := "importiert von Einweiserliste"
    let $tags  := "arzt"
    let $contact :=
    <Practitioner xmlns="http://hl7.org/fhir" xml:id="{$cid}">
        <id value="{$cid}"/>
        <meta>
            <versionID value="0"/>
            <tag>
                <coding>
                    <system value="#metis-tag"/>
                    <code value="{$tags}"/>
                    <display value="{$tags}"/>
                </coding>
                <coding>
                    <system value="#metis-tag"/>
                    <code value="{$super}"/>
                    <display value="{$super}"/>
                </coding>
                <text value="{string-join(($super,$tags),', ')}"/>
            </tag>
        </meta>
        <identifier>
            <use value="official"/>
            <type value="Nabu"/>
            <system value="#practitioner-id"/>
            <value value="{$cid}"/>
        </identifier>
        <name>
            <use value="official"/>
            <prefix value="{$title}">
                <extension url="http://hl7.org/fhir/ExtensionDefinition/iso21090-EN-qualifier">
                    <valueCode value="AC"/>
                </extension>
            </prefix>
            <given value="{$given}"/>
            <family value="{$family}"/>
        </name>
        <address>
            <line value="{$street-address}"/>
            <line value="{$extended-address}"/>
            <city value="{$locality}"/>
            <state value="{$region}"/>
            <postalCode value="{$postal-code}"/>
            <country value="DEU"/>
        </address>
        { 
            let $type := "phone"
            let $nr := $tel
            return
                if ($nr!='')
                then 
                    <telecom>
                        <system value="{$type}" />
                        <value value="{$nr}" />
                        <use value="work" />
                    </telecom>
                else ()
        }
        { 
            let $type := "fax"
            let $nr := $fax
            return
                if ($nr!='')
                then 
                    <telecom>
                        <system value="{$type}" />
                        <value value="{$nr}" />
                        <use value="work" />
                    </telecom>
                else ()
        }
        <telecom>
            <system value="email"/>
            <value value="{$email}"/>
            <use value="work"/>
        </telecom>
        <telecom>
            <system value="internet"/>
            <value value="{$internet}"/>
            <use value="work"/>
        </telecom>
        <gender value="{$gender}"/>
        <organization>
            <reference value=""/>
            <display value=""/>
        </organization>
        <specialty>
            <coding>
                <system value="http://hl7.org/fhir/vs/practitioner-specialty"/>
                <code value="{$profession}"/>
                <display value="{$profession}"/>
            </coding>
            <text value="{$profession}"/>
        </specialty>
        <communication>
            <coding>
                <system value="urn:ietf:bcp:47"/>
                <!--   IETF language tag   -->
                <code value="de"/>
                <display value="Deutsch"/>
            </coding>
            <text value="Deutsch"/>
        </communication>
        <extension url="#practitioner-note">
            <note value="{$note}"/>
        </extension>
        <active value="true"/>
    </Practitioner>
        return
            r-practitioner:putPractitionerXML(<content>{$contact}</content>,$realm, $loguid, "import-bot")
};

let $contacts    := doc("/db/apps/nabudocs/import/Einweiser2016-08-18.xml")
let $loguid := 'u-admin'
let $realm  := 'kikl-spz'
for $pc in subsequence($contacts//tr,2)
let $name := tokenize($pc/td[3]/p,',')[1]
let $plz  := $pc/td[5]/p/string()
let $ps   := r-practitioner:practitioners(
              "1", "*"
            , $name
            , $plz
            , ""
            , ""
            , ""
            , ""
            , "true"
            )
return
    if (count($ps/fhir:Practitioner)<1)
    then 
        let $contact := local:fill-template($realm, $loguid, $pc)
        return
            ()
    else
        ()