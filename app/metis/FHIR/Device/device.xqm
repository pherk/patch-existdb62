xquery version "3.0";

module namespace device = "http://enahar.org/exist/apps/metis/device";

import module namespace config  = "http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";

import module namespace r-device  = "http://enahar.org/exist/restxq/metis/devices" at "../Device/device-routes.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"   at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";


declare variable $device:restxq-entities  := "/exist/restxq/metis";
declare variable $device:restxq-locations := $device:restxq-entities || "/locations";
declare variable $device:restxq-devices   := $device:restxq-entities || "/devices";


(:~
 : Helper for dashboard to show available User Account functionality
 : 
 : @param  $user alias
 : @param  $uid  userid
 : 
 : @return html 
 :)
declare function device:showFunctions($account as item(), $uid as xs:string)
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
                        <a href="index.html?action=showDevices">Geräte</a>
                    </li>
                </ul>
            </div>
        else    ()
};

declare function device:devices()
{
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $realm := 'kikl-spz' 
    let $header := "Geräte - SPZ"
return
(<div style="display:none;">
    <xf:model id="m-devices">
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
        <xf:submission id="s-submit-device"
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
        <xf:submission id="s-submit-room"
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
        

        <xf:instance id="i-views" xmlns="">
            <data>
                <hasRoom/>
                <hasNoRoom/>
                <hasDevice/>
                <hasNoDevice/>
            </data>
        </xf:instance>

        <xf:bind ref="instance('i-views')/hasNoRoom"
            relevant="count(instance('i-rooms')/*:Location) &lt; 1"/>
        <xf:bind ref="instance('i-views')/hasRoom"
            relevant="instance('i-rooms')/*:Location"/>
        <xf:bind ref="instance('i-views')/hasNoDevice"
            relevant="count(instance('i-devices')/*:Device) &lt; 1"/>
        <xf:bind ref="instance('i-views')/hasDevice"
            relevant="instance('i-devices')/*:Device"/>
            
        <xf:instance id="i-devinfos" src="FHIR/Device/device-infos.xml"/>
        <xf:instance id="i-locinfos" src="FHIR/Location/loc-infos.xml"/>

        <xf:action ev:event="xforms-ready">
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
                    <xf:hint>This button will save device.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-device"/>
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
                <xf:group id="aps" class="svFullGroup">
                    <xf:label>Geräte:</xf:label>
                    <xf:repeat id="room-aps-id"
                                    ref="instance('i-devices')/*:Device"
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
            </td>
            <td>
                <xf:group id="entity-rooms" ref="instance('i-views')/hasRoom" class="svFullGroup bordered">
                    <xf:label>Raum</xf:label>
                    <xf:repeat id="r-rooms-id"
                            ref="instance('i-rooms')/*:Location[*:id/@value=substring-after(instance()/*:Device/*:location/*:reference/@value,'metis/locations/')]"
                            appearance="compact" class="svRepeat">
                        <xf:output ref="./*:name/@value">
                        </xf:output>
                    </xf:repeat>
                </xf:group>
                <xf:group ref="instance('i-views')/hasNoRoom" class="svFullGroup bordered">
                    <xf:label>Kein Raum</xf:label>
                </xf:group>
            </td>
        </tr>
    </table>
</div>
)
};
