xquery version "3.0";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "/db/apps/metis/Practitioner/practitioner-routes.xqm";
import module namespace r-organization = "http://enahar.org/exist/restxq/metis/organizations"  at "/db/apps/metis/Organization/organization-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare function local:fill-template($realm as xs:string, $loguid as xs:string, $c as item())
{
    let $type  := $c//person/type/string()
    let $cid := if ($c//tags/KA_Nr)
        then $c//tags/KA_Nr/string()
        else substring($c/contact/@xml:id,3)
    let $title := $c//honorific-prefix/string()
    let $given := $c//given-name/string()
    let $family:= $c//family-name/string()
    let $street-address := $c//street-address/string()
    let $extended-address := $c//extended-address/string()
    let $locality := $c//locality/string()
    let $region := $c//region/string()
    let $postal-code := $c//postal-code/string/()
    let $tels  := $c//tels/tel
    let $email := $c//email/string()
    let $internet := $c//internet/string()
    let $gender := $c//gender/string()
    let $profession := $c//profession/string()
    let $super := $c//tags/super/string()
    let $note  := $c//note/string()
    let $tags  := $c//tags/tag/string()
    return
    if ($type='person')
    then
        let $contact :=
    <Practitioner xmlns="http://hl7.org/fhir" xml:id="c-{$cid}">
        <id value="c-{$cid}"/>
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
                <text value="{$super}, {$tags}"/>
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
        { for $t in $tels
            let $type := $t/@type
            let $nr := $t/string()
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
            r-practitioner:putPractitionerXML(<content>{$contact}</content>, $realm, $loguid)
    else
        let $contact :=
    <Organization xmlns="http://hl7.org/fhir" xml:id="c-{$cid}">
        <id value="c-{$cid}"/>
        <meta>
            <versionID value="0"/>
            <tag>
                <coding>
                    <system value="#metis-tag"/>
                    <code value="{$tags}"/>
                    <display value="{$tags}"/>
                </coding>
                <text value="{$tags}"/>
            </tag>
        </meta>
        <identifier>
            <use value="official"/>
            <type value="Nabu"/>
            <system value="#organization-id"/>
            <value value="{$cid}"/>
        </identifier>
        <name value="{$family}"/>
        <type>
            <coding>
                <system value="#organization-type"/>
                <code value="{$super}"/>
                <display value="{$super}"/>
            </coding>
            <text value="{$super}"/>
        </type>
        { for $t in $tels
            let $type := $t/@type
            let $nr := $t/string()
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
            <system value="url"/>
            <value value="{$internet}"/>
            <use value="work"/>
        </telecom>
        <address>
            <line value="{$street-address}"/>
            <line value="{$extended-address}"/>
            <city value="{$locality}"/>
            <state value="{$region}"/>
            <postalCode value="{$postal-code}"/>
            <country value="DEU"/>
        </address>
        <contact>
            <purpose>
                <coding>
                    <system value="http://hl7.org/fhir/vs/organization-purpose"/>
                    <code value=""/>
                    <display value="{$profession}"/>
                </coding>
                <text value="{$profession}"/></purpose>
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
            { for $t in $tels
                let $type := $t/@type
                let $nr := $t/string()
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
                <system value="url"/>
                <value value="{$internet}"/>
                <use value="work"/>
            </telecom>
            <address>
                <line value="{$street-address}"/>
                <line value="{$extended-address}"/>
                <city value="{$locality}"/>
                <state value="{$region}"/>
                <postalCode value="{$postal-code}"/>
                <country value="DEU"/>
            </address>
            <gender value="{$gender}"/>
        </contact>
        <active value="true"/>
    </Organization>
        return
            r-organization:putOrganizationXML(<content>{$contact}</content>, $realm, $loguid)
};

let $contacts    := collection($config:nabu-root)//contact
let $loguid := 'u-admin'
let $realm  := 'kikl-spz'
for $pc in $contacts
let $contact := local:fill-template($realm, $loguid, $pc)
return
   ()
    