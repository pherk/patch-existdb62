xquery version "3.0";

module namespace organization ="http://enahar.org/exist/apps/metis/organization";

import module namespace config = "http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";

import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"
                    at "../../FHIR/PractitionerRole/practitionerrole-routes.xqm";
import module namespace r-organization = "http://enahar.org/exist/restxq/metis/organizations"  at "../Organization/organization-routes.xqm";

declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";


declare variable $organization:restxq-organizations := "/exist/restxq/metis/organizations";

declare function organization:listOrganizations()
{
    let $now := adjust-dateTime-to-timezone(current-dateTime(), ())
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $header := "Organization-Behörde-Firma"
    let $realm := "metis/organizations/kikl-spzn"
    return
(<div style="display:none;">
    <xf:model>
        <xf:instance xmlns="" xmlns:fhir="http://hl7.org/fhir" id="default">
            <orgs>
                <start>1</start>
                <length>0</length>
                <count>0</count>
            </orgs>
        </xf:instance>

        <xf:submission id="s-submit-contact-data"
                				   ref="instance()/*:Organization[index('r-orgs-id')]"
								   method="put"
								   replace="none"
								   resource="{$organization:restxq-organizations}">
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
                <xf:message  level="ephemeral">Contact submitted. Reload list.</xf:message>
                <xf:send submission="s-search"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">Submit error (Organizations). Server down?</xf:message>
        </xf:submission>
        
        <xf:instance  id="i-search">
            <parameters xmlns="">
                <start>1</start>
                <length>15</length>
                <tag/>
                <city/>
                <name/>
                <type/>
                <partOf/>
            </parameters>
        </xf:instance>
        
        <xf:submission id="s-search"
                resource="{$organization:restxq-organizations}" 
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
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Search error (Organizations). Server down?</xf:message>
        </xf:submission>
        
         <xf:instance xmlns="" id="i-organizations">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-organizations"
                				   ref="instance('i-organizations')"
								   method="get"
								   replace="instance"
								   resource="{$organization:restxq-organizations}">
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
       
        <xf:instance id="i-oinfos"    xmlns="" src="/exist/apps/metis/FHIR/Organization/organization-infos.xml"/>
        <xf:instance id="i-iso3166-1" xmlns="" src="/exist/apps/metis/resources/iso3166-1.xml"/>
        <xf:instance id="i-iso3166-2" xmlns="" src="/exist/apps/metis/resources/iso3166-2.xml"/>

        <xf:instance id="views">
            <data xmlns="">
                <ListNotEmpty/>
                <ListTooLong/>
                <NotDeleted/>
                <Deleted/>
                <TriggerPrevActive/>
                <TriggerNextActive/>
                <TriggerSaveActive/>
            </data>
        </xf:instance>

         <xf:bind id="ListNotEmpty"
            ref="instance('views')/ListNotEmpty"
            readonly="count(instance('default')/*:Organization) &lt; 1"/>
        <xf:bind id="ListTooLong"
            ref="instance('views')/ListTooLong"
            readonly="instance('default')/*:length &gt; instance('default')/*:count"/>
        <xf:bind id="NotDeleted"
            ref="instance('views')/NotDeleted"
            relevant="instance('default')/*:Organization[index('r-orgs-id')]/*:active/@value = 'true'"/>
        <xf:bind id="Deleted"
            ref="instance('views')/Deleted"
            relevant="instance('default')/*:Organization[index('r-orgs-id')]/*:active/@value = 'false'"/>
        <xf:bind id="Stored"
            ref="instance('views')/Stored"
            relevant="instance('default')/*:Organization[index('r-orgs-id')]/*:active/@value = 'true'"/>
-->
        <xf:bind id="TriggerPrevActive"
            ref="instance('views')/TriggerPrevActive"
            readonly="instance('default')/length &gt; instance('default')/start"/>
        <xf:bind id="TriggerNextActive"
            ref="instance('views')/TriggerNextActive"
            readonly="instance('default')/start &gt; (instance('default')/count - instance('default')/length)"/>
<!--
         <xf:bind id="TriggerSaveActive"
            ref="instance('views')/TriggerSaveActive"
            readonly="instance('default')/contact[index('r-orgs-id')]/@xml:id"/>
-->     

        <xf:action ev:event="xforms-ready">
            <xf:setvalue ref="instance('i-search')/name" value="''"/>
            <xf:setvalue ref="instance('i-search')/city" value="''"/>
            <xf:setvalue ref="instance('i-search')/tag" value="''"/>
            <xf:setvalue ref="instance('i-search')/type" value="''"/>
            <xf:setvalue ref="instance('i-search')/typeOf" value="''"/>
            <xf:send submission="s-get-organizations"/>
        </xf:action>        
    </xf:model>
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
                                nodeset="instance('default')/*:Organization"
                                context="instance('default')"
                                origin="instance('i-oinfos')/*:bricks/*:Organization"/>
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
                        <xf:setvalue ref="instance('i-search')/start" value="'1'"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:input>
                </td><td>
                    <xf:input class="search-short" ref="instance('i-search')/*:city" incremental="true">
                    <xf:label>PLZ o. Ort:</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/start" value="'1'"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:input>
                </td><td>
                    <xf:input class="search-short" ref="instance('i-search')/*:tag" incremental="true">
                    <xf:label>Tags:</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/start" value="'1'"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:input>
                </td><td>
                    <xf:select1 class="search-short" ref="instance('i-search')/*:type" incremental="true">
                    <xf:label>Typ:</xf:label>
                    <xf:itemset nodeset="instance('i-oinfos')/type/item">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                        </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/start" value="'1'"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:select1>
                </td><td colspan="2">
                    <xf:trigger class="svSaveTrigger">
                    <xf:label>Reset</xf:label>
                    <xf:action>
                        <xf:setvalue ref="instance('i-search')/start" value="'1'"/>
                        <xf:setvalue ref="instance('i-search')/name" value="''"/>
                        <xf:setvalue ref="instance('i-search')/city" value="''"/>
                        <xf:setvalue ref="instance('i-search')/tag" value="''"/>
                        <xf:setvalue ref="instance('i-search')/type" value="''"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                    </xf:trigger>
                </td></tr>
            </table>
            <xf:group id="orgs" class="svFullGroup">
                <xf:repeat id="r-orgs-id" ref="instance('default')/*:Organization" appearance="compact" class="svRepeat">
                    <xf:output ref="./*:name/@value">
                        <xf:label class="svRepeatHeader">Name:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:address/*:postalCode/@value">
                        <xf:label class="svRepeatHeader">PLZ:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:address/*:city/@value">
                        <xf:label class="svRepeatHeader">Ort:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:address/*:line/@value">
                        <xf:label class="svRepeatHeader">Straße:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:telecom[*:use/@value='work']/*:value/@value">
                        <xf:label class="svRepeatHeader">Telefon:</xf:label>
                    </xf:output>
                </xf:repeat>
            </xf:group>
            <div class="divider"></div>
            <xf:group ref="instance('views')/ListTooLong">
                <xf:trigger ref="instance('views')/TriggerPrevActive">
                <xf:label>&lt;&lt;</xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('i-search')/start" value="instance('i-search')/start - instance('i-search')/length"/>
                    <xf:send submission="s-search"/>
                </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance()/start &gt; instance()/count),instance()/count,instance()/start)"/>-
                <xf:output value="choose((instance()/start + instance()/length &gt; instance()/count),instance()/count,instance()/start + instance()/length - 1)"></xf:output>
                <xf:output value="concat('(',instance()/count,')')"></xf:output>
                <xf:trigger ref="instance('views')/TriggerNextActive">
                <xf:label>&gt;&gt;</xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('i-search')/start" value="instance('i-search')/start + instance('i-search')/length"/>
                    <xf:send submission="s-search"/>
                </xf:action>
                </xf:trigger>
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
			<xf:group ref="instance('default')/*:Organization[index('r-orgs-id')]" class="vcard">
					<section class="profile">
						<header class="n" title="Name">
							<span class="fn" itemprop="name">
								<span class="family-name"><xf:output ref="./*:name/@value"></xf:output></span>
							</span>
						</header>
						<address class="adr" itemprop="address" title="Location">
							<span class="street-address"><xf:output ref="./*:address/*:line/@value"></xf:output></span>
    						<abbr class="postal-code"><xf:output ref="./*:address/*:postalCode/@value"></xf:output></abbr>
							<span class="city"><xf:output ref="./*:address/*:city/@value"></xf:output></span>,
							<abbr class="region"><xf:output ref="./*:address/*:region/@value"></xf:output></abbr>
							<abbr class="country-name"><xf:output ref="./*:address/*:country/@value"></xf:output></abbr>
						</address>
                        <div class="profession"><xf:output ref="./*:type/*:text/@value"></xf:output></div>
                        <xf:group  class="svFullGroup bordered">
                            <xf:label>Telecom</xf:label>
                            <xf:repeat ref="./*:telecom[*:use/@value='work']" appearance="compact" class="svRepeat">
                                <xf:output ref="./*:value/@value"/>
    					    </xf:repeat>
    					</xf:group>
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
                    <xf:group ref="instance('views')/Stored">
                        <xf:label>Gespeichert!</xf:label>
                    </xf:group>
                </td><td colspan="2">
                    <xf:trigger class="svSaveTrigger" ref="instance('views')/NotDeleted">
                        <xf:label>Löschen (inaktiv)</xf:label>
<!--
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('default')/*:Organization[index('r-orgs-id')]/*:active/@value" value="'false'"/>
                            <xf:send submission="s-submit-contact-data"/>
                        </xf:action>
-->
                    </xf:trigger>
                    <xf:group ref="instance('views')/Deleted">
                        <xf:label>Gelöscht!</xf:label>
                    </xf:group>
                </td>
                </tr>
            </table>
            <xf:group  ref="instance('default')/*:Organization[index('r-orgs-id')]">
                <xf:group class="svFullGroup bordered"><br/>
                    <xf:label>Name</xf:label>
                        <xf:input id="tce-name" ref="./*:name/@value" class="long-input">
                            <xf:label>Name:</xf:label>
                        </xf:input>
                        <xf:select1 id="tce-org" ref="./*:partOf/*:reference/@value" class="long-input">
                            <xf:label>Teil von</xf:label>
                            <xf:itemset nodeset="instance('i-organizations')/*:Organization">
                                <xf:label ref="./*:name/@value"/>
                                <xf:value ref="./*:identifier/*:value/@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:setvalue ref="instance('default')/*:Organization[index('r-orgs-id')]/*:partOf/*:display/@value"
                                    value="instance('i-organizations')/*:Organization[./*:identifier/*:value/@value=instance('default')/*:Organization[index('r-orgs-id')]/*:partOf/*:reference/@value]/*:name/@value"/>
                            </xf:action>
                        </xf:select1>
                </xf:group>
                <xf:group  class="svFullGroup bordered">
                    <xf:label>Adresse</xf:label>
                    <table>
                        <thead>
                            <td>
                                <xf:label>Adress-Zeile </xf:label>
                                <xf:trigger>
                                    <xf:label>+</xf:label>
                                    <xf:action ev:event="DOMActivate">
                                        <xf:insert
                                            nodeset="instance()/*:Organization[index('r-orgs-id')]/*:address/*:line"
                                            context="instance()/*:Organization[index('r-orgs-id')]/*:address"
                                            origin="instance('i-oinfos')/*:bricks/*:line"/>
                                    </xf:action>
                                </xf:trigger>
                                <xf:trigger>
                                    <xf:label>-</xf:label>
                                    <xf:action ev:event="DOMActivate">
                                        <xf:delete
                                            nodeset="instance()/*:Organization[index('r-orgs-id')]/*:address/*:line"
                                            at="index('r-lines-id')"/>
                                    </xf:action>
                                </xf:trigger>
                            </td>
                        </thead>
                        <tbody>
                            <tr><td>
                                <xf:repeat id="r-lines-id" ref="*:address/*:line" appearance="compact" class="svRepeat">
                                    <xf:input ref="./@value" class="long-input">
                                        <xf:label class="svRepeatHeader"></xf:label>
                                    </xf:input>
                                </xf:repeat>
                            </td></tr>
                        </tbody>
                    </table>
                    <xf:group>
                        <xf:input id="tce-plz" ref="./*:address/*:postalCode/@value" class="tiny-input">
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
                <xf:group  class="svFullGroup bordered">
                    <xf:label>Telecom</xf:label>
                    <table>
                        <thead>
                            <td>
                                    <xf:label>Work </xf:label>
                                    <xf:trigger>
                                        <xf:label>+</xf:label>
                                        <xf:action ev:event="DOMActivate">
                                            <xf:insert
                                                nodeset="instance()/*:Organization[index('r-orgs-id')]/*:telecom[*:use/@value='work']"
                                                context="instance()/*:Organization[index('r-orgs-id')]"
                                                origin="instance('i-oinfos')/*:bricks/*:telecom[*:use/@value='work']"/>
                                        </xf:action>
                                    </xf:trigger>
                                    <xf:trigger>
                                        <xf:label>-</xf:label>
                                        <xf:action ev:event="DOMActivate">
                                            <xf:delete
                                                nodeset="instance()/*:Organization[index('r-orgs-id')]/*:telecom[*:use/@value='work']"
                                                at="index('tce-work-id')"/>
                                        </xf:action>
                                    </xf:trigger>
                            </td>
                        </thead>
                        <tbody>
                            <tr><td>
                                <xf:repeat id="tce-work-id" ref="./*:telecom[*:use/@value='work']" appearance="compact" class="svRepeat">
                                    <xf:select1 ref="./*:system/@value" class="short-input">
                                        <xf:label class="svRepeatheader">System</xf:label>
                                        <xf:itemset nodeset="instance('i-oinfos')/telecom/system">
                                            <xf:label ref="./@label"/>
                                            <xf:value ref="./@value"/>
                                        </xf:itemset>
                                    </xf:select1>
                                    <xf:input ref="./*:value/@value" class="">
                                        <xf:label class="svRepeatHeader">Nr:</xf:label>
                                    </xf:input>
                                </xf:repeat>
                            </td></tr>
                        </tbody>
                    </table>
                </xf:group>
                <xf:group  class="svFullGroup bordered">
                    <xf:label>Kontakt</xf:label>
                    <table>
                        <thead>
                            <td>
                                    <xf:label>Person </xf:label>
                                    <xf:trigger>
                                        <xf:label>+</xf:label>
                                        <xf:action ev:event="DOMActivate">
                                            <xf:insert
                                                nodeset="instance()/*:Organization[index('r-orgs-id')]/*:contact"
                                                context="instance()/*:Organization[index('r-orgs-id')]"
                                                origin="instance('i-oinfos')/*:bricks/*:contact"/>
                                        </xf:action>
                                    </xf:trigger>
                                    <xf:trigger>
                                        <xf:label>-</xf:label>
                                        <xf:action ev:event="DOMActivate">
                                            <xf:delete
                                                nodeset="instance()/*:Organization[index('r-orgs-id')]/*:contact"
                                                at="index('tce-contacts-id')"/>
                                        </xf:action>
                                    </xf:trigger>
                            </td>
                        </thead>
                        <tbody>
                            <tr><td>
                                <xf:repeat id="tce-contacts-id"  ref="./*:contact" appearance="compact" class="svRepeat">
                                    <xf:input ref="./*:name/*:family/@value">
                                        <xf:label class="svRepeatHeader">Name</xf:label>
                                    </xf:input>
                                    <xf:select1 ref="./*:telecom[*:use/@value='work']/*:system/@value" class="short-input">
                                        <xf:label class="svRepeatheader">System</xf:label>
                                        <xf:itemset nodeset="instance('i-oinfos')/telecom/system">
                                            <xf:label ref="./@label"/>
                                            <xf:value ref="./@value"/>
                                        </xf:itemset>
                                    </xf:select1>
                                    <xf:input ref="./*:telecom[*:use/@value='work']/*:value/@value" class="medium-input">
                                        <xf:label class="svRepeatHeader">Telecom</xf:label>
                                    </xf:input>
                                    <xf:input ref="./*:telecom[*:use/@value='work']/*:when/@value" class="medium-input">
                                        <xf:label class="svRepeatHeader">Zeiten</xf:label>
                                    </xf:input>
                                </xf:repeat>
                            </td></tr>
                        </tbody>
                    </table>
                </xf:group>
                <xf:group class="svFullGroup bordered">
                    <xf:label>Details</xf:label><br/>
                    <xf:select1 id="tce-type" ref="./*:type/*:coding[*:system/@value='#organization-type']/*:code/@value" class="medium-input">
                        <xf:label>Typ</xf:label>
                        <xf:itemset nodeset="instance('i-oinfos')/type/item">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                        </xf:itemset>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue ref="instance('default')/*:Organization[index('r-orgs-id')]/*:type/*:coding/*:display/@value"
                                value="instance('i-oinfos')/type/item[./@value=instance('default')/*:Organization[index('r-orgs-id')]/*:type/*:coding/*:code/@value]/@label"/>
                            <xf:setvalue ref="instance('default')/*:Organization[index('r-orgs-id')]/*:type/*:text/@value"
                               value="instance('default')/*:Organization[index('r-orgs-id')]/*:type/*:coding/*:display/@value"/>
                        </xf:action>
                    </xf:select1>
                    <xf:input id="tce-tag" ref="*:meta/*:tag/*:text/@value">
                        <xf:label>Tags:</xf:label>
                    </xf:input>
                    <xf:textarea id="tce-note" ref="./*:extension/*:note/@value" class="fullareashort">
                        <xf:label>Notiz:</xf:label>
                    </xf:textarea>
                </xf:group>
            </xf:group>
        </xf:case>
    </xf:switch>
</div>
)
};
