xquery version "3.1";
module namespace prown = "http://enahar.org/exist/apps/metis/prown";

import module namespace prutil = "http://enahar.org/exist/apps/metis/prutil"  at "../PractitionerRole/prutil.xqm";

declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

declare variable $prown:restxq-account       := "/exist/restxq/metis/PractitionerRole";
declare variable $prown:restxq-organizations := "/exist/restxq/metis/organizations";
declare variable $prown:restxq-roles         := "/exist/restxq/metis/roles";
declare variable $prown:restxq-groups        := "/exist/restxq/metis/groups";
(:~
 : 
 : show xform for user
 : 
 : @param $uid   user id
 : @param $uname user name
 : @param $isAdmin xs:boolean
 : @return
 :  
 :)
declare function prown:updateOwnAccount(
          $account as element(fhir:PractitionerRole)
        , $loguid as xs:string
        , $lognam as xs:string
        , $realm as xs:string 
        )
{


(<div style="display:none;">
    <xf:model id="m-account">
        <xf:instance xmlns="" xmlns:fhir="http://hl7.org/fhir" id="i-account">
            { $account }
        </xf:instance>
        <xf:submission id="s-submit-account"
                				   ref="instance('i-account')"
								   method="put"
								   replace="none">
			<xf:resource value="concat('/exist/restxq/metis/PractitionerRole?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit account! Validation?, server down?</xf:message>
        </xf:submission>

        <xf:bind ref="instance('i-account')/*:active/@value" type="xs:boolean"/>
   
        <xf:instance xmlns="" xmlns:fhir="http://hl7.org/fhir" id="i-organizations">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-organizations"
                				   ref="instance('i-organizations')"
								   method="get"
								   replace="instance">
			<xf:resource value="'{$prown:restxq-organizations}?partOf=ukk-kikl&amp;partOf=ukk-hno'"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $loguid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-error">
                <xf:message level="ephemeral">Submit Error!</xf:message>
            </xf:action>
        </xf:submission>

        <xf:instance xmlns="" id="i-roles">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-roles"
                				   ref="instance('i-roles')"
								   method="get"
								   replace="instance"
								   resource="{$prown:restxq-roles}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $loguid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get roles! Server down!</xf:message>
        </xf:submission>

        <xf:instance xmlns="" id="i-groups">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-groups"
                				   ref="instance('i-groups')"
								   method="get"
								   replace="instance"
								   resource="{$prown:restxq-groups}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $loguid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get groups! Server down!</xf:message>
        </xf:submission>

        <xf:instance id="i-pinfos" xmlns="" src="/exist/apps/metis/FHIR/PractitionerRole/practitionerrole-infos.xml"/>
        
        <xf:instance id="i-views" xmlns="">
            <data>
                <edit-admin/>
                <has-no-roles/>
                <delete-role/>
                <has-no-quals/>
                <delete-qual/>
            </data>
        </xf:instance>
        <xf:instance id="i-login" xmlns="">
            <data>
                <loguid>{$loguid}</loguid>
                <lognam>{$lognam}</lognam>
                <realm>{$realm}</realm>
            </data>
        </xf:instance> 
        <xf:instance xmlns="" id="i-rooms">
            <data/>
        </xf:instance> 
        <xf:submission id="s-get-rooms"
                				   ref="instance('i-rooms')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat('/exist/restxq/metis/locations?_format=full&amp;loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;type=ro')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load rooms! Server error!</xf:message>
        </xf:submission>
        
        <xf:bind id="edit-admin" 
            ref="instance('i-views')/edit-admin"
            readonly="true()"/> <!--"{not($isAdmin)}"/>-->
        <xf:bind id="has-no-roles" 
            ref="instance('i-views')/has-no-roles"
            relevant="count(instance('i-account')/*:code/*:coding) = 0"/>
        <xf:bind id="del-role" 
            ref="instance('i-views')/delete-role"
            relevant="count(instance('i-account')/*:code/*:coding) &gt; 0"/>
            
        <xf:bind id="has-no-quals" 
            ref="instance('i-views')/has-no-quals"
            relevant="count(instance('i-account')/*:specialty/*:coding) = 0"/>
        <xf:bind id="del-qual" 
            ref="instance('i-views')/delete-qual"
            relevant="count(instance('i-account')/*:specialty/*:coding) &gt; 0"/>

        <xf:instance id="i-bricks" xmlns="">
            <bricks xmlns="http://hl7.org/fhir">
                <birthDate value=""/>
                <qualification>
                    <code>
                        <coding>
                            <code value=""/>
                        </coding>
                        <text value=""/>
                    </code>
                    <period>
                        <start value=""/>
                        <end value=""/>
                    </period>
                    <issuer>
                        <reference value=""/>
                        <display value=""/>
                    </issuer>
                </qualification>
                <identifier>
                    <use value="official"/>
                    <type value="#qualification-identifier"/>
                    <system value="#qualification-identifier"/>
                    <value value="[string]"/>
                    <assigner>
                        <reference value=""/>
                        <display value=""/>
                    </assigner>
                </identifier>
            </bricks>
        </xf:instance>
        
        <xf:action ev:event="xforms-ready">
            <xf:action ev:event="xforms-submit-done">
                <xf:insert  if="not(instance('i-account')/*:organization)"
                    at="last()"
                    nodeset="instance('i-account')/*:organization"
                    context="instance('i-account')"
                    origin="instance('i-bricks')/*:organization"/>
            </xf:action>
            <xf:send submission="s-get-organizations"/>
            <xf:send submission="s-get-roles"/>
            <xf:send submission="s-get-groups"/>
            <xf:send submission="s-get-rooms"/>
        </xf:action>
    </xf:model>
</div>,
<div id="xforms">
    <h2>Persönliche Daten: <xf:output ref="instance('i-account')/*:practitioner/*:display/@value"/>(<xf:output ref="instance('i-login')/*:loguid"/>)</h2>
    <table>
        <tr>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Save</xf:label>
                    <xf:hint>This button will save the user account.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-account"/>
                        <xf:load resource="/exist/apps/metis/index.html"/> 
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
        <tr>
            <td colspan="3">
                <div class="divider"></div>
            </td>
        </tr>
    </table>
    { prutil:mkMainGroup() }
</div>    
)
};

