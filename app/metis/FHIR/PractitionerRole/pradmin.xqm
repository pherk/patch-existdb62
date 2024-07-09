xquery version "3.1";
module namespace pradmin = "http://enahar.org/exist/apps/metis/pradmin";

import module namespace prutil = "http://enahar.org/exist/apps/metis/prutil"  at "../PractitionerRole/prutil.xqm";
import module namespace pravail = "http://enahar.org/exist/apps/metis/pravail"  at "../PractitionerRole/pravailable.xqm";

declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";


declare variable $pradmin:restxq-account       := "/exist/restxq/metis/PractitionerRole";
declare variable $pradmin:restxq-organizations := "/exist/restxq/metis/organizations";
declare variable $pradmin:restxq-roles         := "/exist/restxq/metis/roles";
declare variable $pradmin:restxq-groups        := "/exist/restxq/metis/groups";
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
declare function pradmin:updateAccount(
          $uid as xs:string
        , $loguid as xs:string
        , $lognam as xs:string
        , $realm as xs:string
        )
{

(<div style="display:none;">
    <xf:model id="m-account">
        <xf:instance xmlns="" xmlns:fhir="http://hl7.org/fhir" id="i-account">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-account"
                				   ref="instance('i-account')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat('/exist/restxq/metis/PractitionerRole/',instance('i-login')/*:uid,'?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:insert  if="not(instance('i-account')/*:organization)"
                    at="last()"
                    nodeset="instance('i-account')/*:organization"
                    context="instance('i-account')"
                    origin="instance('i-bricks')/*:organization"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load account! Server down!</xf:message>
        </xf:submission>
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
        <xf:bind ref="instance('i-account')/*:birthDate/@value" type="xs:date"/>
<!--
        <xf:bind ref="instance('i-account')/*:qualification/*:period/*:start//@value" type="xs:date"/>
        <xf:bind ref="instance('i-account')/*:qualification/*:period/*:end/@value" type="xs:date"/>
-->    
        <xf:instance xmlns="" xmlns:fhir="http://hl7.org/fhir" id="i-organizations">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-organizations"
                				   ref="instance('i-organizations')"
								   method="get"
								   replace="instance">
			<xf:resource value="'{$pradmin:restxq-organizations}?partOf=ukk-kikl&amp;partOf=ukk-hno&amp;partOf=ukk'"/>
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
                <xf:message>Submit Error! </xf:message>
            </xf:action>
        </xf:submission>

        <xf:instance xmlns="" id="i-roles">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-roles"
                				   ref="instance('i-roles')"
								   method="get"
								   replace="instance"
								   resource="{$pradmin:restxq-roles}">
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
								   resource="{$pradmin:restxq-groups}">
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
                <uid>{$uid}</uid>
                <loguid>{$loguid}</loguid>
                <lognam>{$lognam}</lognam>
                <realm>{$realm}</realm>
            </data>
        </xf:instance>    
        
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
            ref="instance('i-views')/has-no-spec"
            relevant="count(instance('i-account')/*:specialty/*:coding) = 0"/>
        <xf:bind id="del-qual" 
            ref="instance('i-views')/delete-spec"
            relevant="count(instance('i-account')/*:specialty/*:coding) &gt; 0"/>

        <xf:instance id="i-bricks" xmlns="">
            <bricks xmlns="http://hl7.org/fhir">
                <code>
                    <coding>
                        <code value=""/>
                        <display value=""/>
                    </coding>
                    <text value=""/>
                </code>
                <organization>
                    <reference value="metis/organizations/ukk-kikl-spzn"/>
                    <display value="Neuro- und Sozialpädiatrie (nSPZ)"/>
                </organization>
                <specialty>
                    <coding>
                        <code value=""/>
                        <display value=""/>
                    </coding>
                    <text value=""/>
                </specialty>
        <identifier>
            <use value="official"/>
            <label value="PersonalID"/>
            <system value="http://eNahar.org/nabu/system#ukk-idm"/>
            <value value=""/>
            <period>
                <start value="{current-dateTime()}"/>
                <end value=""/>
            </period>
            <assigner>
                <reference value="metis/Organization/ukk"/>
                <display value="UKK"/>
            </assigner>
        </identifier>
            <identifier>
                <use value="usual"/>
                <label value="MetisID"/>
                <system value="http://eNahar.org/nabu/system#metis-account"/>
                <value value=""/>
            <period>
                <start value="{current-dateTime()}"/>
                <end value=""/>
            </period>
            <assigner>
                <reference value="metis/Organization/ukk-kikl-spzn"/>
                <display value="nSPZ UKK"/>
            </assigner>
            </identifier>
            </bricks>
        </xf:instance>
        
        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-account"/>
            <xf:send submission="s-get-organizations"/>
            <xf:send submission="s-get-roles"/>
            <xf:send submission="s-get-groups"/>
            <xf:send submission="s-get-rooms"/>
            <xf:action if="count(instance('i-account')/*:identifier[*:system/@value='http://eNahar.org/nabu/system#metis-account'])=0">
                <xf:insert position="after" nodeset="instance('i-account')/*:identifier"
                                            context="instance('i-account')"
                                            origin="instance('i-bricks')/*:identifier[*:system/@value='http://eNahar.org/nabu/system#metis-account']"/>
            </xf:action>
            <xf:action if="count(instance('i-account')/*:identifier[*:system/@value='http://eNahar.org/nabu/system#ukk-idm'])=0">
                <xf:insert position="after" nodeset="instance('i-account')/*:identifier"
                                            context="instance('i-account')"
                                            origin="instance('i-bricks')/*:identifier[*:system/@value='http://eNahar.org/nabu/system#ukk-idm']"/>
            </xf:action>
        </xf:action>
    </xf:model>
</div>,
<div id="xforms">
    <h2>Team Member: <xf:output ref="instance('i-account')/*:practitioner/*:display/@value"/>(<xf:output ref="instance('i-login')/*:uid"/>)</h2>
    <table>
        <tr>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>zurück</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/admin.html?action=show&amp;what=new_team"/> 
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Save</xf:label>
                    <xf:hint>This button will save the user account.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-account"/>
                        <xf:load resource="/exist/apps/metis/admin.html?action=show&amp;what=new_team"/> 
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
    { prutil:mkAdminGroup() }
    { pravail:mkAvailGroup() }
</div>    
)
};

