xquery version "3.0";

module namespace loc = "http://enahar.org/exist/apps/metis/location";

import module namespace config  = "http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";

import module namespace r-loc  = "http://enahar.org/exist/restxq/metis/locations" at "../Location/location-routes.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"  
                  at "../../FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";


declare variable $loc:restxq-entities  := "/exist/restxq/metis";
declare variable $loc:restxq-locations := $loc:restxq-entities || "/locations";
declare variable $loc:restxq-devices   := $loc:restxq-entities || "/devices";

(:~
 : Helper for dashboard to show available User Account functionality
 : 
 : @param  $user alias
 : @param  $uid  userid
 : 
 : @return html 
 :)
declare function loc:showFunctions($account as item(), $uid as xs:string)
{
    let $orga  := $account/fhir:organization/fhir:display/@value/string()
    let $perms := r-practrole:perms($uid)/fhir:perm
    let $hasUA := 'updateAccount' = $perms
    return

        if ($hasUA)
        then
            <div>
                <h3>Entities</h3>
                <ul>
                    <li>
                        <a href="index.html?action=editLocation">Räume, Arbeitsplätze</a>
                    </li>
                </ul>
            </div>
        else    ()
};

declare function loc:locations()
{
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $realm := 'kikl-spzn' 
    let $header := "Räume  - SPZ"
return
(<div style="display:none;">
    <xf:model id="m-locations">
        <xf:instance xmlns="" id="i-buildings">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-buildings"
                				   ref="instance('i-buildings')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat(bf:appContext('contextroot'),'/restxq/metis/locations?_format=full&amp;realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;type=bu')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load buildings! Server error!</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-floors">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-floors"
                				   ref="instance('i-floors')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat(bf:appContext('contextroot'),'/restxq/metis/locations?_format=full&amp;realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;type=fl')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load floors! Server error!</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-rooms">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-rooms"
                				   ref="instance('i-rooms')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat(bf:appContext('contextroot'),'/restxq/metis/locations?_format=full&amp;realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;type=ro')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load rooms! Server error!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-rooms"
                				   ref="instance('i-rooms')/*:Location[index('r-rooms-id')]"
								   method="put"
								   replace="none">
			<xf:resource value="concat(bf:appContext('contextroot'),'/restxq/metis/locations?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit rooms!</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-devices">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-devices"
                				   ref="instance('i-devices')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat(bf:appContext('contextroot'),'/restxq/metis/devices?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load devices!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-devices"
                				   ref="instance('i-devices')/*:Locatiion[index('r-devices-id')]"
								   method="put"
								   replace="none">
			<xf:resource value="concat(bf:appContext('contextroot'),'/restxq/metis/devices?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit devices!</xf:message>
        </xf:submission>

        <xf:instance id="i-views" xmlns="">
            <data>
                <hasRoom/>
                <hasNoRoom/>
                <hasFloor/>
                <hasNoFloor/>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-views')/hasFloor"
            relevant="instance('i-floors')/*:Location[*:partOf/*:reference/@value=concat('metis/locations/',instance('i-buildings')/*:Location[index('r-buildings-id')]/*:id/@value)]"/>
        <xf:bind ref="instance('i-views')/hasNoFloor"
            relevant="not(instance('i-floors')/*:Location[*:partOf/*:reference/@value=concat('metis/locations/',instance('i-buildings')/*:Location[index('r-buildings-id')]/*:id/@value)])"/>
        <xf:bind ref="instance('i-views')/hasNoRoom"
            relevant="count(instance('i-rooms')/*:Location) &lt; 1"/>
        <xf:bind ref="instance('i-views')/hasRoom"
            relevant="instance('i-rooms')/*:Location"/>

        <xf:instance id="i-locInfos" src="FHIR/Location/loc-infos.xml"/>

        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-buildings"/>
            <xf:send submission="s-get-floors"/>
            <xf:send submission="s-get-rooms"/>
            <xf:send submission="s-get-devices"/>
        </xf:action>
    </xf:model>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <table>
        <tr>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Cancel</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:load resource="index.html" show="replace"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td colspan="2">
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Save</xf:label>
                    <xf:hint>This button will save locations.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-locations"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td>
                <!--
                <xf:trigger class="svAddTrigger" >
                    <xf:label>Neu</xf:label>
                    <xf:action ev:event="DOMActivate">
                    </xf:action>
                </xf:trigger>
                -->
            </td>
            <td>
                <xf:trigger  ref="instance('control-instance')/delete-trigger" class="svDelTrigger">
                    <xf:label>Entfernen</xf:label>
                </xf:trigger>
            </td>
            <td>
            </td>
        </tr>
        <tr>
            <td colspan="4">
                <hr/>
            </td>
        </tr>
        <tr>
            <td>
                <xf:group id="entity-building" class="svFullGroup bordered">
                    <xf:label>Gebäude</xf:label>
                    <xf:repeat id="r-buildings-id"
                            ref="instance('i-buildings')/*:Location"
                            appearance="compact" class="svRepeat">
                        <xf:output ref="./*:name/@value">
                        </xf:output>
                    </xf:repeat>
                </xf:group>
            </td>
            <td>
                <xf:group id="entity-floors" ref="instance('i-views')/hasFloor" class="svFullGroup bordered">
                    <xf:label>Etage</xf:label>
                    <xf:repeat id="r-floors-id"
                            ref="instance('i-floors')/*:Location[*:partOf/*:reference/@value=concat('metis/locations/',instance('i-buildings')/*:Location[index('r-buildings-id')]/*:id/@value)]"
                            appearance="compact" class="svRepeat">
                        <xf:output ref="./*:name/@value">
                        </xf:output>
                    </xf:repeat>
                </xf:group>
                <xf:group ref="instance('i-views')/hasNoFloor" class="svFullGroup bordered">
                    <xf:label>Keine Etage</xf:label>
                </xf:group>
            </td>
            <td>
                <xf:group id="entity-rooms" ref="instance('i-views')/hasRoom" class="svFullGroup bordered">
                    <xf:label>Raum</xf:label>
                    <xf:repeat id="r-rooms-id"
                            ref="instance('i-rooms')/*:Location[*:partOf/*:reference[matches(@value,substring(instance('i-floors')/*:Location[*:partOf/*:reference/@value=concat('metis/locations/',instance('i-buildings')/*:Location[index('r-buildings-id')]/*:id/@value)][index('r-floors-id')]/*:id/@value,3))]]"
                            appearance="compact" class="svRepeat">
                        <xf:output ref="./*:name/@value">
                        </xf:output>
                    </xf:repeat>
                </xf:group>
                <xf:group ref="instance('i-views')/hasNoRoom" class="svFullGroup bordered">
                    <xf:label>Kein Raum</xf:label>
                </xf:group>
            </td>
            <td colspan="2">
                <xf:group  class="svFullGroup bordered">
                    <xf:label>Details:</xf:label>
                    <xf:group ref="instance('i-rooms')/*:Location[*:partOf/*:reference[matches(@value,substring(instance('i-floors')/*:Location[*:partOf/*:reference/@value=concat('metis/locations/',instance('i-buildings')/*:Location[index('r-buildings-id')]/*:id/@value)][index('r-floors-id')]/*:id/@value,3))]][index('r-rooms-id')]" class="svFullGroup">
                        <xf:output id="room-name" ref="./*:name/@value" class="short-input">
                            <xf:label class="svListHeader">Name:</xf:label>
                        </xf:output>
                        <xf:output id="room-flur" value="tokenize(./*:partOf/*:reference/@value,'-')[4]" class="short-input">
                            <xf:label class="svListHeader">Flur:</xf:label>
                        </xf:output><br/>
                        <xf:input id="room-desc" ref="./*:description/@value" class="long-input">
                            <xf:label class="svListHeader">Info:</xf:label>
                        </xf:input>
                        <xf:input id="room-active" ref="./*:status/@value" class="medium-input">
                            <xf:label class="svListHeader">Status:</xf:label>
                        </xf:input>
                        <xf:select1 id="room-realm" ref="./*:extension[@url='#managedByGroup']/*:valueCode/@value" class="medium-input">
                            <xf:label class="svListHeader">Gruppe:</xf:label>
                            <xf:itemset nodeset="instance('i-locInfos')/*:group">
                                <xf:label ref="./@label"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                        </xf:select1>
                        <xf:select1 id="room-type" ref="./*:extension[@url='#room-type']/*:valueCode/@value" class="short-input">
                            <xf:label class="svListHeader">Typ</xf:label>
                            <xf:itemset nodeset="instance('i-locInfos')/*:roomType">
                                <xf:label ref="./@label"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                        </xf:select1>
                        <xf:input id="room-area" ref="./*:extension[@url='#room-area']/*:valueDecimal/@value" class="short-input">
                            <xf:label  class="svListHeader">Fläche</xf:label>
                        </xf:input>
                        <xf:input id="room-np" ref="./*:extension[@url='#room-pc-no']/*:valueInteger/@value" class="short-input">
                          <xf:label  class="svListHeader">Anzahl AP</xf:label>
                        </xf:input>
                        <hr/>
                        <xf:group id="aps" class="svFullGroup">
                            <xf:label>ContactPoints:</xf:label>
                            <xf:repeat id="room-cps-id"
                                    ref="./*:telecom"
                                    appearance="compact"
                                    class="svRepeat">
                                <xf:input ref="./*:system/@value" class="short-input">
                                    <xf:label class="svListHeader">Typ:</xf:label>
                                    <xf:alert>a string is required</xf:alert>
                                </xf:input>
                                <xf:input ref="./*:value/@value" class="short-input">
                                    <xf:label class="svListHeader">Nr:</xf:label>
                                </xf:input>
                            </xf:repeat>
                        </xf:group>
                        <hr/>
                        <xf:group id="aps" class="svFullGroup">
                            <xf:label>Endpoints:</xf:label>
                            <xf:repeat id="room-aps-id"
                                    ref="instance('i-devices')/*:Device[*:location/*:reference/@value=concat('metis/locations/',
                                        instance('i-rooms')/*:Location[*:partOf/*:reference/@value=concat('metis/locations/',
                                        instance('i-floors')/*:Location[*:partOf/*:reference/@value=concat('metis/locations/',
                                        instance('i-buildings')/*:Location[index('r-buildings-id')]/*:id/@value)][index('r-floors-id')]/*:id/@value)][index('r-rooms-id')]/*:id/@value)]"
                                    appearance="compact"
                                    class="svRepeat">
                                <xf:input ref="./*:identifier/*:value/@value" class="short-input">
                                    <xf:label class="svListHeader">ID:</xf:label>
                                    <xf:alert>a string is required</xf:alert>
                                </xf:input>
                                <xf:input ref="./*:url/@value" class="short-input">
                                    <xf:label class="svListHeader">IP:</xf:label>
                                </xf:input>
                                <xf:input ref="./*:extension[@url='#device-os']/*:valueCode/@value" class="tiny-input">
                                    <xf:label class="svListHeader">System:</xf:label>
                                </xf:input>
                                <xf:input ref="./*:extension[@url='#device-apps']/*:valueCode/@value" class="medium-input">
                                    <xf:label class="svListHeader">Software:</xf:label>
                                </xf:input>
                            </xf:repeat>
                        </xf:group>
                    </xf:group>
                </xf:group>
            </td>
        </tr>
    </table>
</div>
)
};
