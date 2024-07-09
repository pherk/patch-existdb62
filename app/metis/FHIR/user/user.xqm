xquery version "3.0";
(:~
 : Utility functions and XFORMS for MetisID
 : 
 : @author Peter Herkenrath
 : @version 0.6
 : @date 2014-10-29
 : 
 :)
module namespace user="http://enahar.org/exist/apps/metis/user";

import module namespace config="http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";
import module namespace r-user="http://enahar.org/exist/restxq/metis/users" at "../user/user-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "../Practitioner/practitioner-routes.xqm";

declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

declare variable $user:restxq-bd-pdf-api := "/exist/restxq/metis/users2birthdates";
(:~
 : Helper for dashboard to show available User Account functionality
 : 
 : @param  $user alias
 : @param  $uid  userid
 : 
 : @return html 
 :)
declare function user:showFunctions($account as item(), $uid as xs:string)
{
    let $orga  := $account/fhir:organization/fhir:display/@value/string()
    let $roles := if (count($account/fhir:role)=0)
        then 'no Roles'
        else string-join($account/fhir:role/fhir:text/@value, ', ')
    let $perms := r-user:perms($uid)/perm
    let $isAdmin := $uid = ('u-admin','u-metis-admin')
    let $hasUA := 'perm_updateAccount' = $perms
    let $hasVL := 'perm_validateLeaves' = $perms
    let $logu   := r-user:userByAlias(xdb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $perms   := r-user:perms($loguid)/perm

    let $isGuest := 'perm_get-patient-only' = $perms
    return
    <div>
        <ul>
            <li>Mother: {$orga}</li>
            <li>Roles:  {$roles}</li>
            <li>Perms:  {string-join($perms, ', ')}</li>
            <li>Session: {session:get-attribute("metis.user")}</li>
        </ul>
        { if ($isGuest)
            then
        <ul>
            <li>
                <a href="index.html?action=changePasswd">Passwort ändern</a>
            </li>
        </ul>
            else
        <ul>
            <li>
                <a href="{concat('index.html?action=editAccount&amp;uid=',$uid)}">Persönliche Daten ändern</a>
            </li>
            <li>
                <a href="index.html?action=listLeaves">Abwesenheiten</a>
            </li>
            <li>
                <a href="index.html?action=changePasswd">Passwort ändern</a>
            </li>
        </ul>
        }
    </div>
};

(:~
 : Helper for User Account functionality
 : 
 : @param  $group
 : 
 : @return
 :)
declare %private function user:ensureGroup($group as xs:string) {
    if (not(xmldb:group-exists($group)))
    then system:as-user('admin', '', xmldb:create-group($group))
    else ()
};



declare function user:check-user($repoConf as element()) as xs:string+ {
    let $perms := $repoConf/repo:permissions
    let $user := if ($perms/@user) then $perms/@user/string() else xmldb:get-current-user()
    let $group := if ($perms/@group) then $perms/@group/string() else xmldb:get-user-groups($user)[1]
    return
        try {
            let $create := system:as-user('admin', '', (
                if (xmldb:exists-user($user)) then
                    if (index-of(xmldb:get-user-groups($user), $group)) then
                        ()
                    else (
                        user:ensureGroup($group),
                        xmldb:add-user-to-group($user, $group)
                    )
                else (
                        user:ensureGroup($group),
                        xmldb:create-user($user, $perms/@password, $group, ())
                )))
            return 
                        ($user, $group)
    } catch * {
        ()
    }
};


declare %private function user:getName($id as xs:string*) as xs:string
{
    let $u := r-user:userByID($id,'ref')
    return
        $u//*:display/@value/string()
};


(:~
 : presents table with User Accounts
 : 
 : @param  $node template var
 : @param  $model dito
 : @param  $uid userid
 : 
 : @return html 
 :)
declare function user:adminTeam()
{
    let $realm  := "kikl-spz"
    let $logu   := xdb:get-current-user()
    let $loguid := r-user:userByAlias($logu)/fhir:id/@value/string()
    let $roles  := r-user:rolesByID($loguid,$realm,$loguid)
    let $org    := 'metis/organizations/kikl-spz'
    let $perms  := r-user:perms($loguid)/perm
    let $isAdmin := $loguid = ('u-admin','u-metis-admin')
    let $hasUA := 'perm_updateAccount' = $perms
    let $users :=   r-practitioner:practitioners("1","*", '', '', '', '', '', 'team', 'true')
return
    <div><h2>Team Members<span>({$users/count/string()})</span></h2>
        <table id="accounts" class="tablesorter">
            <thead>
                <tr id="0">
                    <th>Name</th>
                    <th>Alias</th>
                    <th>ID</th>
                    <th>Telecom</th>
                    <th>Realm</th>
                    <th>Roles</th>
                </tr>
            </thead>
            <tbody>{ user:accountsToRows($users) }</tbody>
            <script type="text/javascript" defer="defer" src="FHIR/user/listUsers.js"/>
        </table><br/>
            <a href="{$user:restxq-bd-pdf-api}">Geburtstagsliste</a>
    </div>
};

declare %private function user:accountsToRows($users)
{
    for $u in $users/fhir:Practitioner
    let $uid := $u/fhir:id/@value/string()
    return
         <tr id="{$uid}">
            <td>{concat( string-join($u/fhir:name[fhir:use/@value='official']/fhir:family/@value,' ')
                        , ', '
                        ,$u/fhir:name[fhir:use/@value='official']/fhir:given/@value)}</td>
            <td>{$u/fhir:identifier[fhir:system/@value="http://eNahar.org/nabu/system#metis-account"]/fhir:value/@value/string()}</td> 
            <td>{$u/fhir:identifier[fhir:system/@value="http://eNahar.org/nabu/system#ukk-idm"]/fhir:value/@value/string()}</td> 
            <td>
            {   if ($u/fhir:telecom)
                then $u/fhir:telecom[1]/fhir:value/@value/string()
                else ''
            }
            </td>
            <td>{$u/fhir:organization/fhir:display/@value/string()}</td>
            <td>{string-join($u/fhir:role/fhir:coding/fhir:code/@value/string(),', ')}</td>
         </tr> 
};

(:~
 : show User Account (XFORMS)
 : 
 : @param $node  template var
 : @param $model template var
 : @param $uid  userid
 : 
 : @return html  with embedded xforms elements
 :)
declare function user:editAccount($uid as xs:string)
{
    let $logu    := r-user:userByAlias(xdb:get-current-user())
    let $loguid  := $logu/fhir:id/@value/string()
    let $self    := $loguid = $uid
    let $perms   := r-user:perms($loguid)/perm
    let $isAdmin := $loguid = ('u-admin','u-metis-admin')
    let $hasUA   := 'perm_updateAccount' = $perms
    let $perms   := r-user:perms($loguid)/perm

    let $isGuest :='perm_get-patient-only' = $perms
    return
    if ($isGuest) then
        <div>
            <h2>Ihr Profil können Sie als Gast nicht editieren.</h2>
            <h2>Nur das Passwort ändern.</h2>
        </div>
    else if ($self) then
        user:updateOwnAccount($logu)
    else if ($isAdmin or $hasUA) then
        user:updateAccount($uid, $loguid)
    else 
        <div>{$loguid} has no authorization! Should not happen. Tell the admin.</div>
};


declare variable $user:restxq-account       := "/exist/restxq/metis/practitioners";
declare variable $user:restxq-organizations := "/exist/restxq/metis/organizations";
declare variable $user:restxq-roles         := "/exist/restxq/metis/roles";
declare variable $user:restxq-groups        := "/exist/restxq/metis/groups";


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
declare function user:updateOwnAccount($logu as item())
{

let $loguid := $logu/fhir:id/@value/string()
let $realm := "metis/organizations/kikl-spz"
return
(<div style="display:none;">
    <xf:model id="m-account">
        <xf:instance xmlns="" xmlns:fhir="http://hl7.org/fhir" id="i-account">
            { $logu }
        </xf:instance>
        <xf:submission id="s-submit-account"
                				   ref="instance('i-account')"
								   method="put"
								   replace="none"
								   resource="{$user:restxq-account}">
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
			<xf:resource value="'{$user:restxq-organizations}?partOf=kikl'"/>
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
                <xf:message>Submit Error! Resource-uri: <xf:output value="event('resource-uri')"/>
                            Response-reason-phrase: <xf:output value="event('response-reason-phrase')"/>
                </xf:message>
            </xf:action>
        </xf:submission>

        <xf:instance xmlns="" id="i-roles">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-roles"
                				   ref="instance('i-roles')"
								   method="get"
								   replace="instance"
								   resource="{$user:restxq-roles}">
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
								   resource="{$user:restxq-groups}">
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

        <xf:instance id="i-pinfos" xmlns="" src="/exist/apps/metis/FHIR/Practitioner/practitioner-infos.xml"/>
        
        <xf:instance id="i-views" xmlns="">
            <data>
                <edit-admin/>
                <has-no-roles/>
                <delete-role/>
                <has-no-quals/>
                <delete-qual/>
            </data>
        </xf:instance>
    
        <xf:bind id="edit-admin" 
            ref="instance('i-views')/edit-admin"
            readonly="true()"/> <!--"{not($isAdmin)}"/>-->
        <xf:bind id="has-no-roles" 
            ref="instance('i-views')/has-no-roles"
            relevant="count(instance('i-account')/*:role) = 0"/>
        <xf:bind id="del-role" 
            ref="instance('i-views')/delete-role"
            relevant="count(instance('i-account')/*:role) &gt; 0"/>
            
        <xf:bind id="has-no-quals" 
            ref="instance('i-views')/has-no-quals"
            relevant="count(instance('i-account')/*:qualification) = 0"/>
        <xf:bind id="del-qual" 
            ref="instance('i-views')/delete-qual"
            relevant="count(instance('i-account')/*:qualification) &gt; 0"/>

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
            <!-- practitioner template has no birthDate, organization, role -->
            <xf:action ev:event="xforms-submit-done">
                <xf:insert if="not(instance('i-account')/*:birthDate)"
                    at="last()"
                    nodeset="instance('i-account')/*:birthDate"
                    context="instance('i-account')"
                    origin="instance('i-bricks')/*:birthDate"/>
                <xf:insert  if="not(instance('i-account')/*:organization)"
                    at="last()"
                    nodeset="instance('i-account')/*:organization"
                    context="instance('i-account')"
                    origin="instance('i-bricks')/*:organization"/>
            </xf:action>
            <xf:send submission="s-get-organizations"/>
            <xf:send submission="s-get-roles"/>
            <xf:send submission="s-get-groups"/>
        </xf:action>
    </xf:model>
</div>,
<div id="xforms">
    <h2>Persönliche Daten: <xf:output ref="instance('i-account')/*:name[*:use/@value='official']/*:family/@value"/> ({$loguid})</h2>
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
    { user:mkMainGroup() }
</div>    
)
};

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
declare function user:updateAccount($uid as xs:string, $loguid as xs:string)
{

let $realm := "metis/organizations/kikl-spz"
return
(<div style="display:none;">
    <xf:model id="m-account">
        <xf:instance xmlns="" xmlns:fhir="http://hl7.org/fhir" id="i-account">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-account"
                				   ref="instance('i-account')"
								   method="get"
								   replace="instance"
			                       resource="{concat($user:restxq-account, '/', $uid)}">
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
            <!-- practitioner template has no birthDate, organization, role -->
            <xf:action ev:event="xforms-submit-done">
                <xf:insert if="not(instance('i-account')/*:birthDate)"
                    at="last()"
                    nodeset="instance('i-account')/*:birthDate"
                    context="instance('i-account')"
                    origin="instance('i-bricks')/*:birthDate"/>
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
								   replace="none"
								   resource="{$user:restxq-account}">
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
			<xf:resource value="'{$user:restxq-organizations}?partOf=kikl'"/>
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
                <xf:message>Submit Error! Resource-uri: <xf:output value="event('resource-uri')"/>
                            Response-reason-phrase: <xf:output value="event('response-reason-phrase')"/>
                </xf:message>
            </xf:action>
        </xf:submission>

        <xf:instance xmlns="" id="i-roles">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-roles"
                				   ref="instance('i-roles')"
								   method="get"
								   replace="instance"
								   resource="{$user:restxq-roles}">
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
								   resource="{$user:restxq-groups}">
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

        <xf:instance id="i-pinfos" xmlns="" src="/exist/apps/metis/FHIR/Practitioner/practitioner-infos.xml"/>
        
        <xf:instance id="i-views" xmlns="">
            <data>
                <edit-admin/>
                <has-no-roles/>
                <delete-role/>
                <has-no-quals/>
                <delete-qual/>
            </data>
        </xf:instance>
    
        <xf:bind id="edit-admin" 
            ref="instance('i-views')/edit-admin"
            readonly="true()"/> <!--"{not($isAdmin)}"/>-->
        <xf:bind id="has-no-roles" 
            ref="instance('i-views')/has-no-roles"
            relevant="count(instance('i-account')/*:role) = 0"/>
        <xf:bind id="del-role" 
            ref="instance('i-views')/delete-role"
            relevant="count(instance('i-account')/*:role) &gt; 0"/>
            
        <xf:bind id="has-no-quals" 
            ref="instance('i-views')/has-no-quals"
            relevant="count(instance('i-account')/*:qualification) = 0"/>
        <xf:bind id="del-qual" 
            ref="instance('i-views')/delete-qual"
            relevant="count(instance('i-account')/*:qualification) &gt; 0"/>

        <xf:instance id="i-bricks" xmlns="">
            <bricks xmlns="http://hl7.org/fhir">
                <birthDate value=""/>
                <role>
                    <coding>
                        <code value=""/>
                        <display value=""/>
                    </coding>
                    <text value=""/>
                </role>
                <organization>
                    <reference value="metis/organizations/kikl-spz"/>
                    <display value="Neuro- und Sozialpädiatrie (SPZ)"/>
                </organization>
                <qualification>
                    <code>
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
                <reference value="metis/Organization/kikl-spzn"/>
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
    <h2>Team Member: <xf:output ref="instance('i-account')/*:name[*:use/@value='official']/*:family/@value"/> ({$uid})</h2>
    <table>
        <tr>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>zurück</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/admin.html?action=show&amp;what=team"/> 
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Save</xf:label>
                    <xf:hint>This button will save the user account.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-account"/>
                        <xf:load resource="/exist/apps/metis/admin.html?action=show&amp;what=team"/> 
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
    { user:mkAdminGroup() }
</div>    
)
};


declare %private function user:mkMainGroup() {
        <xf:group  ref="instance('i-account')" class="svFullGroup bordered">
            <xf:input id="a-name" ref="./*:name[*:use/@value='official']/*:family/@value" class="">
                <xf:label class="svListHeader">Name:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:output id="a-alias" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#metis-account']/*:value/@value" class="medium-input">
                <xf:label class="svListHeader">Alias:</xf:label>
            </xf:output>
            <xf:output id="a-persid" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#ukk-idm']/*:value/@value" class="medium-input">
                <xf:label class="svListHeader">PersID:</xf:label>
            </xf:output>
            <xf:input id="a-bd" ref="./*:birthDate/@value" appearance="bf:iso8601"
                    data-bf-params="date:'dd.MM.yyyy'" incremental="true" class="medium-input">
                <xf:label class="svListHeader">Geburtstag:</xf:label>
                <xf:alert>a date is required</xf:alert>
            </xf:input>
            { user:mkQualificationGroup() }
            { user:mkDetailGroup() }
        </xf:group>
};

declare %private function user:mkAdminGroup() {
        <xf:group  ref="instance('i-account')" class="svFullGroup bordered">
            <xf:input id="a-name" ref="./*:name[*:use/@value='official']/*:family/@value" class="">
                <xf:label class="svListHeader">Name:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:input id="a-alias" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#metis-account']/*:value/@value" class="medium-input">
                <xf:label class="svListHeader">Alias:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:input id="a-persid" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#ukk-idm']/*:value/@value" class="medium-input">
                <xf:label class="svListHeader">PersID:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:input id="a-bd" ref="./*:birthDate/@value" appearance="bf:iso8601"
                    data-bf-params="date:'dd.MM.yyyy'" incremental="true" class="medium-input">
                <xf:label class="svListHeader">Geburtstag:</xf:label>
                <xf:alert>a date is required</xf:alert>
            </xf:input>
            <xf:input id="a-active" ref="./*:active/@value" class="">
                <xf:label class="svListHeader">Active:</xf:label>
            </xf:input>
<!--
            <xf:input id="a-sign" ref="./a_signature">
                <xf:label class="svListHeader">Signature:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
-->
            <xf:group ref="instance('i-views')/edit-admin">
                { user:mkRBACGroup() }
            </xf:group>
            <br/>
            { user:mkQualificationGroup() }
            { user:mkDetailGroup() }
        </xf:group>
};

declare %private function user:mkRBACGroup() {
        <xf:group ref="instance('i-account')">
            <xf:select1 id="a-org" ref="./*:organization/*:reference/@value">
                <xf:label class="svListHeader">Org:</xf:label>
                    <xf:itemset nodeset="instance('i-organizations')/*:Organization">
                        <xf:label ref="./*:name/@value"/>
                        <xf:value ref="./*:identifier/*:value/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-account')/*:organization/*:display/@value"
                                value="instance('i-organizations')/*:Organization[./*:identifier/*:value/@value=instance('i-account')/*:organization/*:reference/@value]/*:name/@value"/>
                    </xf:action>
            </xf:select1>
            <xf:group class="svFullGroup bordered">
                <xf:label>Roles</xf:label>
                <xf:group ref="instance('i-views')/has-no-roles">
                    <p>No roles defined yet.</p>
                </xf:group>
                <xf:repeat id="r-role-id" ref="./*:role" appearance="compact" class="svRepeat multicol">
                    <xf:select1 ref="./*:coding/*:code/@value" class="">
                        <xf:itemset nodeset="instance('i-roles')/*:Group">
                            <xf:label ref="./*:name/@value"/>
                            <xf:value ref="./*:code/*:text/@value"/>
                        </xf:itemset>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue ref="instance('i-account')/*:role[index('r-role-id')]/*:coding/*:display/@value"
                                value="instance('i-roles')/*:Group[./*:code/*:text/@value=instance('i-account')/*:role[index('r-role-id')]/*:coding/*:code/@value]/*:name/@value"/>
                            <xf:setvalue ref="instance('i-account')/*:role[index('r-role-id')]/*:text/@value"
                                value="instance('i-account')/*:role[index('r-role-id')]/*:coding/*:display/@value"/>
                        </xf:action>
                    </xf:select1>
                </xf:repeat>
                <xf:group appearance="minimal" class="svTriggerGroup">
                    <table>
                        <tr>
                            <td>
                                <xf:trigger class="svAddTrigger" >
                                    <xf:label>New</xf:label>
                                    <xf:action ev:event="DOMActivate">
                                        <xf:insert position="after" at="index('r-role-id')"
                                            nodeset="instance('i-account')/*:role"
                                            context="instance('i-account')"
                                            origin="instance('i-bricks')/*:role[1]"/>
                                    </xf:action>
                                </xf:trigger>
                            </td>
                            <td>
                                <xf:trigger  ref="instance('i-views')/delete-role" class="svDelTrigger">
                                    <xf:label>Delete</xf:label>
                                    <xf:delete ev:event="DOMActivate"
                                        nodeset="instance('i-account')/*:role" at="index('r-role-id')"/>
                                </xf:trigger>
                            </td>
                        </tr>
                    </table>
                </xf:group>
            </xf:group>
            <xf:textarea id="a-details" ref="./details" class="fullareashort">
                <xf:label class="svListHeader">Details:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:textarea>
            <xf:textarea id="a-note" ref="./notes" class="fullareashort">
                <xf:label class="svListHeader">Notizen:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:textarea>
        </xf:group>
};

declare %private function user:mkDetailGroup()
{
    <xf:group ref="instance('i-account')" class="svFullGroup bordered">
        <xf:label>Details</xf:label><br/>
        <xf:select1 id="tce-specialty" ref="./*:specialty/*:coding/*:code/@value" class="medium-input">
            <xf:label>Beruf</xf:label>
            <xf:itemset nodeset="instance('i-pinfos')/profs/prof">
                <xf:label ref="./@label"/>
                <xf:value ref="./@value"/>
            </xf:itemset>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-account')/*:specialty/*:coding/*:display/@value"
                    value="instance('i-pinfos')/profs/prof[./@value=instance('i-account')/*:specialty/*:coding/*:code/@value]/@label"/>
                <xf:setvalue ref="instance('i-account')/*:specialty/*:text/@value"
                    value="instance('i-account')/*:specialty/*:coding/*:display/@value"/>
            </xf:action>
        </xf:select1>
        <xf:input id="tce-tag" ref="*:meta/*:tag/*:text/@value">
            <xf:label>Tags:</xf:label>
        </xf:input>
        <xf:textarea id="tce-note" ref="./*:extension/*:note/@value" class="fullarea">
            <xf:label>Notiz:</xf:label>
        </xf:textarea>
    </xf:group>
};

declare %private function user:mkQualificationGroup()
{
    <xf:group ref="instance('i-account')" class="svFullGroup bordered">
        <xf:label>Qualifikationen</xf:label>
        <xf:group ref="instance('i-views')/has-no-quals">
            <p>No qualifications defined yet.</p>
        </xf:group>
        <xf:repeat id="r-qualis-id" ref="./*:qualification" appearance="compact" class="svRepeat">
            <xf:select1 ref="./*:code/*:coding/*:code/@value" class="">
                <xf:label class="svListHeader">Bezeichnung</xf:label>
                <xf:itemset nodeset="instance('i-groups')/*:Group[./*:meta/*:tag/*:text/@value=('certified', 'edu', 'contract')]">
                    <xf:label ref="./*:name/@value"/>
                    <xf:value ref="./*:code/*:text/@value"/>
                </xf:itemset>
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="instance('i-account')/*:qualification/*:code/*:text/@value"
                            value="instance('i-account')/*:qualification/*:code/*:coding/*:code/@value"/>
                </xf:action>
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
                                    nodeset="instance('i-account')/*:qualification"
                                    context="instance('i-account')"
                                    origin="instance('i-bricks')/*:qualification"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref="instance('i-views')/delete-qual" class="svDelTrigger">
                            <xf:label>Löschen</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:delete 
                                    nodeset="instance('i-account')/*:qualification"
                                    at="index('r-qualis-id')"/>
                                </xf:action>
                        </xf:trigger>
                    </td>
                </tr>
            </table>
        </xf:group>
    </xf:group>
};


(:~
 : show xform for password change
 : 
 : @return html 
 :)
declare function user:changePasswd()
{
let $account:= r-user:userByAlias(xmldb:get-current-user())
let $loguid := $account/fhir:id/@value/string()
let $uname  :=  string-join($account/fhir:name[fhir:use/@value='official']/fhir:family/@value, ' ')
let $header := concat("Passwort für: ", $uname)
let $restxq-passwd   := concat('/exist/restxq/metis/users/', $loguid, '/passwd')
let $realm := "metis/organizations/kikl-spz"
return
(<div style="display:none;">
    <xf:model id="m-passwd">
         <xf:instance id="i-passwd" xmlns="">        
            <data>
                <oldPassword/>
                <newPassword/>
                <confirmPassword/>
            </data>
        </xf:instance>
        
        <xf:submission id="s-submit-passwd"
                				   ref="instance('i-passwd')"
								   method="put"
								   replace="none"
								   resource="{$restxq-passwd}">
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
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit passwd!</xf:message>
        </xf:submission>
        
        <xf:bind ref="instance('i-passwd')/oldPassword" required="true()" constraint=". != ''"/>
        <xf:bind ref="instance('i-passwd')/newPassword" required="true()" constraint=". != ''"/>
        <xf:bind ref="instance('i-passwd')/confirmPassword" required="true()" constraint=". = ../newPassword"/>   

    </xf:model>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <p><strong>Nur drei Regeln:</strong>
     <ol>
        <li>Das neue Passwort muss sich vom alten Passwort unterscheiden.</li>
        <li>Das neue Passwort muss mindestens 6 Zeichen lang sein und mindestens eine Ziffer und einen Buchstaben enthalten;
            erlaubt sind noch !@#$%.<br/>
            Das Ganze als regexp: ^(?=.*\d+)(?=.*[a-zA-Z])[0-9a-zA-Z!@#$%]{6,10}$</li>
        <li>Das neue Passwort muss identisch wiederholt werden.</li>
    </ol>
    </p>
    <table>
        <tr>
            <td colspan="3">
                <div class="divider"></div>
            </td>
        </tr>
        <tr>
            <td colspan="3">
                { user:mkPasswdGroup() }
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Cancel</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/index.html"/> 
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Submit</xf:label>
                    <xf:hint>This button will submit the user password.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-passwd"/>
                        <xf:load resource="/exist/apps/metis/index.html"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td></td>
        </tr>
    </table>
</div>    
)
};

declare %private function user:mkPasswdGroup() {
        <xf:group class="svFullGroup bordered">
            <xf:label>Passwort ändern?</xf:label><br/>
            <xf:secret ref="instance('i-passwd')/oldPassword">
                <xf:label>Altes Password</xf:label>
            </xf:secret>
            <xf:secret ref="instance('i-passwd')/newPassword">
                <xf:label>Neues Password</xf:label>
            </xf:secret>
            <xf:secret ref="instance('i-passwd')/confirmPassword">
                <xf:label>Password bestätigen</xf:label>
            </xf:secret>
        </xf:group>
};

