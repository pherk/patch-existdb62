xquery version "3.0";

module namespace practitioner ="http://enahar.org/exist/apps/metis/practitioner";

import module namespace config = "http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";

import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"   at "../PractitionerRole/practitionerrole-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "../Practitioner/practitioner-routes.xqm";

declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

declare variable $practitioner:restxq-api := "/exist/restxq/metis/practitioners";
declare variable $practitioner:restxq-pdf-api := "/exist/restxq/metis/practitioners2pdf";
declare variable $practitioner:restxq-organizations := "/exist/restxq/metis/organizations";
declare variable $practitioner:restxq-practitionerrole := "/exist/restxq/metis/PractitionerRole";
declare variable $practitioner:restxq-groups := "/exist/restxq/metis/groups";

declare function practitioner:showFunctions()
{
    <div>
        <h3>Kontakte/Adressen:</h3>
        <ul>
            <li>
                <a href="index.html?action=listContacts">Personen</a>
            </li>
            <li>
                <a href="index.html?action=listOrganizations">Nicht-Personen (Behörden, Firmen usw.)</a>
            </li>
            <li>
                <a href="index.html?action=listUsers">Mitarbeiter</a>
            </li>
        </ul>
    </div>
};

declare function practitioner:listContacts()
{
    let $logu := r-practrole:userByAlias(xdb:get-current-user())
    let $prid   := $logu/fhir:id/@value/string()
    let $uref   := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid    := substring-after($uref,'metis/practitioners/')
    let $unam   := $logu/fhir:practitioner/fhir:display/@value/string()
    let $header := "Kontakte/Adressen"
    let $realm := "metis/organizations/kikl-spzn"
    let $itsme := $uid = ('u-admin','u-enahar-admin')
    return
(<div style="display:none;">
    <xf:model>
        <xf:instance   id="default">
            <contacts xmlns="">
                <start>1</start>
                <length>0</length>
                <count>0</count>
            </contacts>
        </xf:instance>
        <xf:submission id="s-submit-contact-data"
                				   ref="instance('default')/*:Practitioner[index('r-contacts-id')]"
								   method="put"
								   replace="none"
								   resource="{$practitioner:restxq-api}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{$uid}</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>lognam</xf:name>
                <xf:value>{$unam}</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message  level="ephemeral">Contact submitted. Reload list.</xf:message>
                <xf:send submission="s-search"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">Submit error (Practitioners). Server down?</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>15</length>
                <tag/>
                <city/>
                <name/>
                <role/>
                <specialty/>
                <active>true</active>
            </parameters>
        </xf:instance>
        
        <xf:submission id="s-search"
                resource="{$practitioner:restxq-api}" 
                method="get" 
                ref="instance('i-search')" 
                instance="default" 
                replace="instance">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{$uid}</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:toggle case="t-ContactList"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Search error (Practitioners). Server down?</xf:message>
        </xf:submission>
        <xf:submission id="s-pdf"
                resource="{$practitioner:restxq-pdf-api}" 
                method="get" 
                ref="instance('i-search')" 
                instance="default" 
                replace="none">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{$uid}</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:toggle case="t-ContactList"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Search error (Practitioners). Server down?</xf:message>
        </xf:submission>
         
        <xf:instance xmlns="" id="i-organizations">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-organizations"
                				   ref="instance('i-organizations')"
								   method="get"
								   replace="instance">
			<xf:resource value="'{$practitioner:restxq-organizations}?partOf=ukk-kikl&amp;partOf=ukk-hno&amp;partOf=ukk'"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $uid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get organizations! Server down!</xf:message>
        </xf:submission>
         
        <xf:instance xmlns="" id="i-org">
            <data/>
        </xf:instance>
        <xf:submission id="s-submit-org"
                				   ref="instance('i-org')/*:Organization[1]"
								   method="put"
								   replace="none"
								   resource="{$practitioner:restxq-organizations}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{$uid}</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message  level="ephemeral">Organization submitted.</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">Submit error (Organizations). Server down?</xf:message>
        </xf:submission>
        <xf:instance xmlns="" id="i-groups">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-groups"
                				   ref="instance('i-groups')"
								   method="get"
								   replace="instance"
								   resource="{$practitioner:restxq-groups}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $uid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get groups! Server down!</xf:message>
        </xf:submission> 

        
        <xf:instance id="i-otemplate" xmlns="" src="/exist/apps/metisData/data/templates/organization.xml"/>
        <xf:instance id="i-pinfos"    xmlns="" src="/exist/apps/metis/FHIR/Practitioner/practitioner-infos.xml"/>
        <xf:instance id="i-prinfos"   xmlns="" src="/exist/apps/metis/FHIR/PractitionerRole/practitionerrole-infos.xml"/>
        <xf:instance id="i-iso3166-1" xmlns="" src="/exist/apps/metis/resources/iso3166-1.xml"/>
        <xf:instance id="i-iso3166-2" xmlns="" src="/exist/apps/metis/resources/iso3166-2.xml"/>

        <xf:instance xmlns="" id="i-pr">
            <data xmlns=""/>
        </xf:instance>
        <xf:submission id="s-submit-pr"
                				   ref="instance('i-pr')/*:PractitionerRole[1]"
								   method="put"
								   replace="none">
			<xf:resource value="'{$practitioner:restxq-practitionerrole}?loguid=u-admin&amp;lognam=admin&amp;realm=ukk-kikl-spz'"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message  level="ephemeral">PractitionerRole submitted.</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">Submit error (PractitionerRole). Server down?</xf:message>
        </xf:submission>
        <xf:instance xmlns="" id="views">
            <data>
                <ListActive/>
                <ListInactive/>
                <ListNotEmpty/>
                <ListTooLong/>
                <NotDeleted/>
                <Deleted/>
                <TriggerPrevActive/>
                <TriggerNextActive/>
                <TriggerSaveActive/>
            </data>
        </xf:instance>
        <xf:instance id="i-login" xmlns="">
            <data>
                <loguid>{$uid}</loguid>
                <lognam>{$unam}</lognam>
                <realm>{$realm}</realm>
            </data>
        </xf:instance>
        
        <xf:bind id="ListActive"
            ref="instance('views')/*:ListActive"
            relevant="instance('i-search')/*:active = 'true'"/>
        <xf:bind id="ListActive"
            ref="instance('views')/*:ListInactive"
            relevant="instance('i-search')/*:active = 'false'"/>
        <xf:bind id="ListNotEmpty"
            ref="instance('views')/*:ListNotEmpty"
            readonly="count(instance('default')/*:Practitioner) &lt; 1"/>
        <xf:bind id="ListTooLong"
            ref="instance('views')/*:ListTooLong"
            readonly="instance('default')/*:length &gt; instance('default')/*:count"/>
        <xf:bind id="NotDeleted"
            ref="instance('views')/*:NotDeleted"
            relevant="instance('default')/*:Practitioner[index('r-contacts-id')]/*:active/@value = 'true'"/>
        <xf:bind id="Deleted"
            ref="instance('views')/*:Deleted"
            relevant="instance('default')/*:Practitioner[index('r-contacts-id')]/*:active/@value = 'false'"/>
        <xf:bind id="Stored"
            ref="instance('views')/*:Stored"
            relevant="instance('default')/*:Practitioner[index('r-contacts-id')]/*:active/@value = 'true'"/>

        <xf:bind id="TriggerPrevActive"
            ref="instance('views')/*:TriggerPrevActive"
            readonly="(instance('default')/*:start &lt; 2) or (instance('default')/*:length &gt; instance('default')/*:start)"/>
        <xf:bind id="TriggerNextActive"
            ref="instance('views')/*:TriggerNextActive"
            readonly="instance('default')/*:start &gt; (instance('default')/*:count - instance('default')/*:length)"/>
<!--
         <xf:bind id="TriggerSaveActive"
            ref="instance('views')/TriggerSaveActive"
            readonly="instance('default')/contact[index('r-contacts-id')]/@xml:id"/>
-->     

        <xf:action ev:event="xforms-ready">
            <xf:setvalue ref="instance('i-search')/*:name" value="''"/>
            <xf:setvalue ref="instance('i-search')/*:city" value="''"/>
            <xf:setvalue ref="instance('i-search')/*:tag" value="''"/>
            <xf:send submission="s-get-organizations"/>
            <xf:send submission="s-get-groups"/>
        </xf:action>        
    </xf:model>
    <xf:input id="org-ref" ref="instance('default')/*:Practitioner[index('r-contacts-id')]/*:organization/*:reference/@value"/>
    <xf:input id="org-display"  ref="instance('default')/*:Practitioner[index('r-contacts-id')]/*:organization/*:display/@value"/>   
</div>,
<div id="xforms">
    <h2>{$header}</h2>
        <xf:switch>
        <xf:case id="t-ContactList" selected="true">
            <table class="svTriggerGroup">
                <tr><td colspan="2">
                    <xf:trigger class="svSaveTrigger" ref="instance('views')/*:ListNotEmpty">
                        <xf:label>Details</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:toggle case="t-ContactDetails"/>
                        </xf:action>
                    </xf:trigger>
                </td><td colspan="2">
                    <xf:trigger class="svAddTrigger">
                        <xf:label>Neuer Kontakt</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert
                                ref="instance('default')/*:Practitioner"
                                context="instance('default')"
                                origin="instance('i-pinfos')/*:bricks/*:Practitioner"/>
                            <xf:insert
                                ref="instance('default')/*:Practitioner/*:identifier"
                                context="instance('default')/*:Practitioner"
                                origin="instance('i-pinfos')/*:bricks/*:identifier[*:system/@value='http://eNahar.org/nabu/system#ukk-bsnr']"/>                                
                        </xf:action>
                    </xf:trigger>
                </td><td colspan="2">
                    <xf:trigger class="svSaveTrigger" ref="instance('views')/*:ListNotEmpty" >
                        <xf:label>Bearbeiten</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:toggle case="t-ContactEdit"/>
                        </xf:action>
                    </xf:trigger>
                </td></tr>
                <tr>
                    <td colspan="6"><div class="divider"></div></td>
                </tr>
                <tr><td>
                    <xf:input class="search-short" ref="instance('i-search')/*:name" incremental="true">
                    <xf:label>Name:</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:input>
                </td><td>
                    <xf:input class="search-short" ref="instance('i-search')/*:city" incremental="true">
                    <xf:label>PLZ o. Ort:</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:input>
                </td><td>
                    <xf:input class="search-short" ref="instance('i-search')/*:tag" incremental="true">
                    <xf:label>Tags:</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:input>
                </td><td>
                    <xf:select1 class="search-short" ref="instance('i-search')/*:specialty" incremental="true">
                    <xf:label>Beruf:</xf:label>
                    <xf:itemset nodeset="instance('i-pinfos')/profs/prof">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                        </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:select1>
                </td><td colspan="2">
                    <xf:trigger class="svSaveTrigger">
                    <xf:label>Reset</xf:label>
                    <xf:action>
                        <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                        <xf:setvalue ref="instance('i-search')/*:name" value="''"/>
                        <xf:setvalue ref="instance('i-search')/*:city" value="''"/>
                        <xf:setvalue ref="instance('i-search')/*:tag" value="''"/>
                        <xf:setvalue ref="instance('i-search')/*:specialty" value="''"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:trigger>
                </td></tr>
            </table>
            <xf:group id="contacts" class="svFullGroup">
                <xf:repeat id="r-contacts-id" nodeset="instance('default')/*:Practitioner" appearance="compact" class="svRepeat">
                    <xf:output value="concat(./*:name/*:family/@value,', ',./*:name/*:given/@value)">
                        <xf:label class="svListHeader">Name:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:address/*:postalCode/@value">
                        <xf:label class="svListHeader">PLZ:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:address/*:city/@value">
                        <xf:label class="svListHeader">Ort:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:address/*:line/@value">
                        <xf:label class="svListHeader">Straße:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:telecom[*:use/@value='work']/*:value/@value">
                        <xf:label class="svListHeader">Telefon:</xf:label>
                    </xf:output>
                </xf:repeat>
            </xf:group>
            <div class="divider"></div>
            <xf:group ref="instance('views')/*:ListTooLong">
                <xf:trigger ref="instance('views')/*:TriggerPrevActive">
                    <xf:label>&lt;&lt;</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start - instance('i-search')/*:length"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance()/*:start &gt; instance()/*:count),instance()/*:count,instance()/*:start)"/>-
                <xf:output value="choose((instance()/*:start + instance()/*:length &gt; instance()/*:count),instance()/*:count,instance()/*:start + instance()/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance()/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/*:TriggerNextActive">
                    <xf:label>&gt;&gt;</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start + instance('i-search')/*:length"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                </xf:trigger>
            {
                if ($itsme)
                then
                (
                    <xf:trigger ref="instance('views')/*:ListInactive">
                        <xf:label>Aktive anzeigen</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('i-search')/*:active" value="'true'"/>
                            <xf:send submission="s-search"/>
                        </xf:action>
                    </xf:trigger> 
                ,   <xf:trigger ref="instance('views')/*:ListActive">
                        <xf:label>Inaktive anzeigen</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('i-search')/*:active" value="'false'"/>
                            <xf:send submission="s-search"/>
                        </xf:action>
                    </xf:trigger>
                ,   <xf:trigger>
                        <xf:label>-> Role</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert
                                nodeset="instance('i-pr')/*:PractitionerRole"
                                context="instance('i-pr')"
                                origin="instance('i-prinfos')/*:bricks/*:PractitionerRole"/>
                            <xf:setvalue ref="instance('i-pr')/*:PractitionerRole[1]/*:id/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:id/@value"/>
                            <xf:setvalue ref="instance('i-pr')/*:PractitionerRole[1]/*:identifier[*:system/@value='http://eNahar.org/nabu/system#metis-account']/*:value/@value"
                                    value="lower-case(concat(instance('default')/*:Practitioner[index('r-contacts-id')]/*:name/*:family/@value,substring(instance('default')/*:Practitioner[index('r-contacts-id')]/*:name/*:given/@value,1,1)))"/>
                            <xf:setvalue ref="instance('i-pr')/*:PractitionerRole[1]/*:practitioner/*:reference/@value"
                                    value="concat('metis/practitioners/',instance('default')/*:Practitioner[index('r-contacts-id')]/*:id/@value)"/>
                            <xf:setvalue ref="instance('i-pr')/*:PractitionerRole[1]/*:practitioner/*:display/@value"
                                    value="concat(instance('default')/*:Practitioner[index('r-contacts-id')]/*:name/*:family/@value,', ',instance('default')/*:Practitioner[index('r-contacts-id')]/*:name/*:given/@value)"/>
                            <xf:setvalue ref="instance('i-pr')/*:PractitionerRole[1]/*:period/*:start/@value"
                                    value="current-dateTime()"/>
                            <xf:setvalue ref="instance('i-pr')/*:PractitionerRole[1]/*:specialty/*:text/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification/*:code[*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']]/*:text/@value"/>
                            <xf:setvalue ref="instance('i-pr')/*:PractitionerRole[1]/*:specialty/*:coding/*:code/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification/*:code/*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/*:code/@value"/>
                            <xf:setvalue ref="instance('i-pr')/*:PractitionerRole[1]/*:specialty/*:coding/*:display/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification/*:code/*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/*:display/@value"/>
                            <xf:message level="modal">Anlegen als Erbringer sollte geklappt haben. Eintrag in Existdb nicht vergessen ;-)</xf:message>
                            <xf:send submission="s-submit-pr"/>

                        </xf:action>
                    </xf:trigger>
                ,   <div><strong>Achtung: kein Schutz vor Duplikaten (->Org, ->Role)</strong></div>
                )
                else ()
            }
            </xf:group>
        </xf:case>
        <xf:case id="t-ContactDetails">
            <table class="svTriggerGroup">
                <tr><td colspan="2">
                    <xf:trigger class="svAddTrigger">
                        <xf:label>&#8756;Liste</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:toggle case="t-ContactList"/>
                        </xf:action>
                    </xf:trigger>
                </td><td>
                    <xf:trigger class="svAddTrigger">
                        <xf:label>Bearbeiten</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:toggle case="t-ContactEdit"/>
                        </xf:action>
                    </xf:trigger>
                </td></tr>
            </table>            <div class="divider"></div>
			<xf:group ref="instance('default')/*:Practitioner[index('r-contacts-id')]" class="vcard">
					<section class="profile">
						<header class="n" title="Name">
							<span class="fn" itemprop="name">
    							<span class="honorific-prefix">
                                    <xf:output ref="instance('i-pinfos')/honorific-prefix[@value=instance('default')/*:Practitioner[index('r-contacts-id')]/*:name[*:use/@value='official']/*:prefix/@value]/@label"></xf:output>
                                </span>
								<span class="given-name"><xf:output ref="./*:name[*:use/@value='official']/*:given/@value"></xf:output></span>
								<span class="family-name"><xf:output ref="./*:name[*:use/@value='official']/*:family/@value"></xf:output></span>
							</span>
						</header>
						<address class="adr" itemprop="address" title="Location">
							<span class="street-address">
							    <xf:repeat ref="./*:address/*:line" appearance="compact" class="">
							        <xf:output ref="./@value"></xf:output>
						        </xf:repeat>
							</span>
    						<abbr class="postal-code"><xf:output ref="./*:address/*:postalCode/@value"></xf:output></abbr>
							<span class="city"><xf:output ref="./*:address/*:city/@value"></xf:output></span>,
							<abbr class="region"><xf:output ref="./*:address/*:region/@value"></xf:output></abbr>
							<abbr class="country-name"><xf:output ref="./*:address/*:country/@value"></xf:output></abbr>
						</address>
                        <div class="profession"><xf:output ref="./*:qualification/*:code[*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']]/*:text/@value"></xf:output></div>
                        <xf:group  class="svFullGroup bordered">
                            <xf:label>Work</xf:label>
                            <xf:repeat ref="./*:telecom[*:use/@value='work']" appearance="compact" class="svRepeat">
                                <xf:output ref="./*:value/@value"/>
    					    </xf:repeat>
    					</xf:group>
                        <xf:group  class="svFullGroup bordered">
                            <xf:label>Privat</xf:label>
                            <xf:repeat ref="./*:telecom[*:use/@value='home']" appearance="compact" class="svRepeat">
                                <xf:output ref="./*:value/@value"/>
    					    </xf:repeat>
    					</xf:group>
                <!--
						<a href="mailto:email" class="email"><xf:output ref="./[*:system/@value='email']/*:value/@value"></xf:output></a>
						<ul>
							<li class="tel">Telefon: <xf:output ref="person/tels/tel[@type='home']"></xf:output></li>
							<li class="tel">Mobil1: <xf:output ref="person/tels/tel[@type='mobil1']"></xf:output></li>
							<li class="tel">Mobil2: <xf:output ref="person/tels/tel[@type='mobil2']"></xf:output></li>
							<li class="tel">Fax: <xf:output ref="person/tels/tel[@type='fax']"></xf:output></li>
						</ul>
    					<span class="internet"><xf:output ref="person/internet"></xf:output></span>
    			-->
					</section>
					<section class="note">
						<span><xf:output ref="*:extension/*:note/@value"></xf:output></span>
					</section>
            </xf:group>
            <div class="divider"></div>
        </xf:case>
        <xf:case id="t-ContactEdit">
            <table class="svTriggerGroup">
                <tr><td colspan="2">
                    <xf:trigger class="svAddTrigger">
                        <xf:label>Cancel&#8756;Liste</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-search"/>
                        </xf:action>
                    </xf:trigger>
                </td><td colspan="2">
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Speichern</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-submit-contact-data"/>
                        </xf:action>
                    </xf:trigger>
                    <xf:group ref="instance('views')/*:Stored">
                        <xf:label>Gespeichert!</xf:label>
                    </xf:group>
                </td><td colspan="2">
                    <xf:trigger class="svSaveTrigger" ref="instance('views')/*:NotDeleted">
                        <xf:label>Löschen</xf:label>
                        <xf:action ev:event="DOMActivate" if="count(instance('default')/*:Practitioner[index('r-contacts-id')]/*:meta/*:tag/*:text[matches(@value,'team')])=0">
                            <xf:setvalue ref="instance('default')/*:Practitioner[index('r-contacts-id')]/*:active/@value" value="'false'"/>
                            <xf:send submission="s-submit-contact-data"/>
                        </xf:action>
                        <xf:action ev:event="DOMActivate" if="count(instance('default')/*:Practitioner[index('r-contacts-id')]/*:meta/*:tag/*:text[matches(@value,'team')])&gt;0">
                            <xf:message level="modal">Person gehört zum Team; Löschen nicht zulässig</xf:message>
                        </xf:action>
                    </xf:trigger>
                { if ($itsme)
                then
                    <xf:trigger class="svSaveTrigger" ref="instance('views')/*:Deleted">
                        <xf:label>ReActivate</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('default')/*:Practitioner[index('r-contacts-id')]/*:active/@value" value="'true'"/>
                            <xf:send submission="s-submit-contact-data"/>
                        </xf:action>
                    </xf:trigger>
                else
                    <xf:group ref="instance('views')/*:Deleted">
                        <xf:label>Gelöscht!</xf:label>
                    </xf:group>
                }
                </td>
                <td>
                    <xf:trigger if="not(./*:organization)" class="svAddTrigger">
                        <xf:label>Organization</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert
                                nodeset="instance('default')/*:Practitioner[index('r-contacts-id')]/*:organization"
                                context="instance('default')/*:Practitioner[index('r-contacts-id')]"
                                origin="instance('i-pinfos')/*:bricks/*:organization"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                </tr>
            </table>
            <xf:group  ref="instance('default')/*:Practitioner[index('r-contacts-id')]" class="svFullGroup bordered">
                    <xf:label>Name</xf:label>
                    <div>
                        <xf:select1 id="tce-prefix" ref="./*:name/*:prefix/@value" class="short-input">
                            <xf:label>Titel:</xf:label>
                            <xf:itemset nodeset="instance('i-pinfos')/honorific-prefix">
                                <xf:label ref="./@label"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                        </xf:select1>
                        <xf:select1 id="tce-gender" ref="./*:gender/@value" class="medium-input">
                            <xf:label>Geschlecht</xf:label>
                            <xf:itemset nodeset="instance('i-pinfos')/gender">
                                <xf:label ref="./@label"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                        </xf:select1>
                        <xf:input id="tce-bsnr" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#ukk-bsnr']/*:value/@value" class="medium-input">
                            <xf:label>BSNR</xf:label>
                        </xf:input>
                    </div>
                        <div>
                        <xf:input id="tce-vorname" ref="./*:name/*:given/@value" class="medium-input">
                            <xf:label>Vorname-Name</xf:label>
                        </xf:input>
                        <xf:input id="tce-name" ref="./*:name/*:family/@value" class="long-input">
                        </xf:input>
                        </div>
                    <div>
                        {
                        if ($itsme)
                        then
                        <xf:input id="tce-bd" ref="./*:birthDate/@value" class="medium-input">
                            <xf:label>Geburtstag</xf:label>
                        </xf:input>
                        else ()
                        }
                    </div>
                        <xf:select1 id="tce-org" ref="./*:organization/*:reference/@value" class="">
                            <xf:label>Organization</xf:label>
                            <xf:itemset nodeset="instance('i-organizations')/*:Organization">
                                <xf:label ref="./*:name/@value"/>
                                <xf:value ref="./*:identifier/*:value/@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:setvalue ref="instance('default')/*:Practitioner[index('r-contacts-id')]/*:organization/*:display/@value"
                                    value="instance('i-organizations')/*:Organization[./*:identifier/*:value/@value=instance('default')/*:Practitioner[index('r-contacts-id')]/*:organization/*:reference/@value]/*:name/@value"/>
                            </xf:action>
                        </xf:select1>
                    <!--
                        <xf:group ref="./*:organization/*:reference/@value">
                            <label for="org-ref-hack" class="xfLabel aDefault xfEnabled">Organisation:</label>
                            <select class="org-select" name="org-ref-hack" type="text" placeholder=""/>
                            <script type="text/javascript" defer="defer" src="../metis/Organization/org.js"/>
                        </xf:group>
                    -->
                    </xf:group>
                    { practitioner:mkAddressGroup() }
                    { practitioner:mkTelecomGroup() }
                    <xf:group ref="instance('default')/*:Practitioner[index('r-contacts-id')]" class="svFullGroup bordered">
                    <xf:label>Details</xf:label><br/>
                        <xf:select1 id="tce-specialty" ref="./*:qualification/*:code/*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/*:code/@value" class="short-input">
                            <xf:label>Beruf</xf:label>
                            <xf:itemset nodeset="instance('i-pinfos')/profs/prof">
                                <xf:label ref="./@label"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:setvalue ref="instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification/*:code/*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/*:display/@value"
                                    value="instance('i-pinfos')/profs/prof[./@value=instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification/*:code/*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/*:code/@value]/@label"/>
                                <xf:setvalue ref="instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification/*:code[*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']]/*:text/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification/*:code/*:coding[*:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/*:display/@value"/>
                            </xf:action>
                        </xf:select1>
                        <xf:input id="tce-tag" ref="*:meta/*:tag/*:text/@value">
                            <xf:label>Tags:</xf:label>
                        </xf:input>
                        {
                        if ($itsme)
                        then
                            practitioner:mkQualificationGroup()
                        else
                            practitioner:mkQualificationGroupRO()
                        }
                        <xf:textarea id="tce-note" ref="./*:extension/*:note/@value" class="fullareashort">
                            <xf:label>Notiz:</xf:label>
                        </xf:textarea>
                    </xf:group>
        </xf:case>
    </xf:switch>
</div>
)
};

declare %private function practitioner:mkAddressGroup()
{
    <xf:group  ref="instance('default')/*:Practitioner[index('r-contacts-id')]" class="svFullGroup bordered">
        <xf:label>Adresse</xf:label>
        <div>
        <xf:select1 ref="./*:address/*:use/@value">
            <xf:label>Art:</xf:label>
            <xf:itemset nodeset="instance('i-pinfos')/address/use">
                <xf:label ref="./@label"/>
                <xf:value ref="./@value"/>
            </xf:itemset>
        </xf:select1>
        </div>
        <xf:repeat ref="./*:address/*:line" appearance="compact" class="svRepeat">
            <xf:label class="svRepeatHeader">Zeile:</xf:label>
            <xf:input id="tce-line" ref="./@value" class="">
                <xf:label class="svRepeatHeader">Zeile:</xf:label>
            </xf:input>
        </xf:repeat>
        <xf:group>
            <xf:input id="tce-plz" ref="./*:address/*:postalCode/@value" class="short-input">
                <xf:label>PLZ:Ort:</xf:label>
            </xf:input>:
            <xf:input id="tce-city" ref="./*:address/*:city/@value">
            </xf:input>
        </xf:group>
        <xf:group>
            <xf:select1 id="tce-region" ref="./*:address/*:region/@value">
                <xf:label>Region:</xf:label>
                <xf:itemset nodeset="instance('i-iso3166-2')/de/region">
                    <xf:label ref="./@label"/>
                    <xf:value ref="./@value"/>
                </xf:itemset>
            </xf:select1>
            <xf:select1 id="tce-staat" ref="./*:address/*:country/@value"  class="medium-input">
                <xf:label>Land:</xf:label>
                <xf:itemset nodeset="instance('i-iso3166-1')/country">
                    <xf:label ref="./@label"/>
                    <xf:value ref="./@value"/>
                </xf:itemset>
            </xf:select1>
        </xf:group>
    </xf:group>
};

declare %private function practitioner:mkTelecomGroup()
{
    <xf:group  ref="instance('default')/*:Practitioner[index('r-contacts-id')]" class="svFullGroup bordered">
        <xf:label>Telecom</xf:label>
        <table>
            <thead>
                <td>
                    <xf:label>Work </xf:label>
                    <xf:trigger>
                        <xf:label>+</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert
                                nodeset="instance()/*:Practitioner[index('r-contacts-id')]/*:telecom[*:use/@value='work']"
                                context="instance()/*:Practitioner[index('r-contacts-id')]"
                                origin="instance('i-pinfos')/*:bricks/*:telecom[*:use/@value='work']"/>
                        </xf:action>
                    </xf:trigger>
                    <xf:trigger>
                        <xf:label>-</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:delete
                                nodeset="instance()/*:Practitioner[index('r-contacts-id')]/*:telecom[*:use/@value='work']"
                                at="index('tce-work-id')"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                    <xf:label>Home </xf:label>
                    <xf:trigger>
                        <xf:label>+</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert
                                nodeset="instance()/*:Practitioner[index('r-contacts-id')]/*:telecom[*:use/@value='home']"
                                context="instance()/*:Practitioner[index('r-contacts-id')]"
                                origin="instance('i-pinfos')/*:bricks/*:telecom[*:use/@value='home']"/>
                            </xf:action>
                    </xf:trigger>
                    <xf:trigger>
                        <xf:label>-</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:delete 
                                nodeset="instance()/*:Practitioner[index('r-contacts-id')]/*:telecom[*:use/@value='home']"
                                at="index('tce-home-id')"/>
                        </xf:action>
                    </xf:trigger>
                </td>
            </thead>
            <tbody>
                <tr><td>
                    <xf:repeat id="tce-work-id"
                            ref="./*:telecom[*:use/@value='work']" appearance="compact" class="svRepeatHalf">
                        <xf:select1 ref="./*:system/@value" class="short-input">
                            <xf:label class="svRepeatheader">System</xf:label>
                            <xf:itemset nodeset="instance('i-pinfos')/telecom/system">
                                <xf:label ref="./@label"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                        </xf:select1>
                        <xf:input ref="./*:value/@value">
                            <xf:label class="svRepeatHeader">Nr:</xf:label>
                        </xf:input>
                    </xf:repeat>
                </td>
                <td>
                    <xf:repeat id="tce-home-id"
                            ref="./*:telecom[*:use/@value='home']" appearance="compact" class="svRepeatHalf">
                        <xf:select1 ref="./*:system/@value" class="short-input">
                            <xf:label class="svRepeatheader">System</xf:label>
                            <xf:itemset nodeset="instance('i-pinfos')/telecom/system">
                                <xf:label ref="./@label"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                        </xf:select1>
                        <xf:input ref="./*:value/@value">
                            <xf:label class="svRepeatHeader">Nr:</xf:label>
                        </xf:input>
                    </xf:repeat>
                </td></tr>
            </tbody>
        </table>
    </xf:group>
};

declare %private function practitioner:mkQualificationGroup()
{
    <xf:group ref="instance('default')/*:Practitioner[index('r-contacts-id')]" class="svFullGroup bordered">
        <xf:label>Qualifikationen</xf:label>
        <xf:repeat id="r-qualis-id" ref="./*:qualification" appearance="compact" class="svRepeat">
            <xf:select1 ref="./*:code/*:coding/*:code/@value" class="">
                <xf:label class="svListHeader">Bezeichnung</xf:label>
                <xf:itemset nodeset="instance('i-groups')/*:Group[./*:meta/*:tag/*:text/@value=('certified', 'edu', 'contract')]">
                    <xf:label ref="./*:name/@value"/>
                    <xf:value ref="./*:code/*:text/@value"/>
                </xf:itemset>
            </xf:select1>
            <xf:input ref="./*:period/*:start/@value" appearance="bf:iso8601"
                    data-bf-params="date:'dd.MM.yyyy'" incremental="true" class="medium-input">
                <xf:label class="svListHeader">Seit</xf:label>
            </xf:input>
            <xf:input ref="./*:period/*:end/@value" appearance="bf:iso8601"
                    data-bf-params="date:'dd.MM.yyyy'" incremental="true" class="medium-input">
                <xf:label class="svListHeader">Bis</xf:label>
            </xf:input>
            <xf:input ref="./*:issuer/*:display/@value" class="medium-input">
                <xf:label class="svListHeader">Zertifizierer</xf:label>
            </xf:input>
        </xf:repeat>
        <xf:group appearance="minimal" class="svTriggerGroup">
            <table>
                <tr>
                    <td>
                        <xf:trigger class="svAddTrigger">
                            <xf:label>Neu</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:insert position="after"
                                    nodeset="instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification"
                                    context="instance('default')/*:Practitioner[index('r-contacts-id')]"
                                    origin="instance('i-bricks')/*:qualification"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref="instance('i-views')/delete-qual" class="svDelTrigger">
                            <xf:label>Löschen</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:delete 
                                    nodeset="instance('default')/*:Practitioner[index('r-contacts-id')]/*:qualification"
                                    at="index('r-qualis-id')"/>
                                </xf:action>
                        </xf:trigger>
                    </td>
                </tr>
            </table>
        </xf:group>
    </xf:group>
};
declare %private function practitioner:mkQualificationGroupRO()
{
    <xf:group ref="instance('default')/*:Practitioner[index('r-contacts-id')]" class="svFullGroup bordered">
        <xf:label>Qualifikationen</xf:label>
        <xf:repeat id="r-qualis-id" ref="./*:qualification[*:code/*:coding/*:code/@value!='contract']" appearance="compact" class="svRepeat">
            <xf:output ref="./*:code/*:coding/*:code/@value" class="">
                <xf:label class="svListHeader">Bezeichnung</xf:label>
            </xf:output>
            <xf:output ref="./*:period/*:start/@value" appearance="bf:iso8601"
                    data-bf-params="date:'dd.MM.yyyy'" incremental="true" class="medium-input">
                <xf:label class="svListHeader">Seit</xf:label>
            </xf:output>
            <xf:output ref="./*:period/*:end/@value" appearance="bf:iso8601"
                    data-bf-params="date:'dd.MM.yyyy'" incremental="true" class="medium-input">
                <xf:label class="svListHeader">Bis</xf:label>
            </xf:output>
            <xf:output ref="./*:issuer/*:display/@value" class="medium-input">
                <xf:label class="svListHeader">Zertifizierer</xf:label>
            </xf:output>
        </xf:repeat>
    </xf:group>
};
(: 
                ,   <xf:trigger>
                        <xf:label>-> PDF</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-pdf"/>
                        </xf:action>
                    </xf:trigger>    
                ,   <xf:trigger>
                        <xf:label>-> Org</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert
                                nodeset="instance('i-org')/*:Organization"
                                context="instance('i-org')"
                                origin="instance('i-otemplate')"/>
                            <xf:setvalue ref="instance('i-org')/*:Organization[1]/*:name/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:name/*:family/@value"/>
                            <xf:setvalue ref="instance('i-org')/*:Organization[1]/*:address/*:line[1]/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:address/*:line[1]/@value"/>
                            <xf:setvalue ref="instance('i-org')/*:Organization[1]/*:address/*:line[2]/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:address/*:line[2]/@value"/>
                            <xf:setvalue ref="instance('i-org')/*:Organization[1]/*:address/*:city/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:address/*:city/@value"/>
                            <xf:setvalue ref="instance('i-org')/*:Organization[1]/*:address/*:postalCode/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:address/*:postalCode/@value"/>
                            <xf:setvalue ref="instance('i-org')/*:Organization[1]/*:id/@value"
                                    value="concat('org-',instance('default')/*:Practitioner[index('r-contacts-id')]/*:identifier/*:value/@value)"/>
                            <xf:setvalue ref="instance('i-org')/*:Organization[1]/*:identifier/*:value/@value"
                                    value="concat('org-',instance('default')/*:Practitioner[index('r-contacts-id')]/*:identifier/*:value/@value)"/>
                            <xf:setvalue ref="instance('i-org')/*:Organization[1]/*:meta/*:tag/*:text/@value"
                                    value="instance('default')/*:Practitioner[index('r-contacts-id')]/*:meta/*:tag/*:text/@value"/>
                            <xf:insert
                                nodeset="instance('i-org')/*:Organization/*:telecom"
                                context="instance('i-org')/*:Organization"
                                origin="instance('default')/*:Practitioner[index('r-contacts-id')]/*:telecom"/>
                            <xf:send submission="s-submit-org"/>
                        </xf:action>
                    </xf:trigger>
:)