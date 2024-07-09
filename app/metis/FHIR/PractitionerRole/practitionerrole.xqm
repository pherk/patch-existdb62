xquery version "3.0";
(:~
 : Utility functions and XFORMS for MetisID
 : 
 : @author Peter Herkenrath
 : @version 1.0
 : @date 2020-06-29
 : 
 :)
module namespace practrole ="http://enahar.org/exist/apps/metis/practrole";

import module namespace config = "http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";
import module namespace date = "http://enahar.org/exist/apps/metis/date"  at "../../modules/date.xqm";

import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"  at "../PractitionerRole/practitionerrole-routes.xqm";
import module namespace prown = "http://enahar.org/exist/apps/metis/prown"  at "../PractitionerRole/prown.xqm";
import module namespace pradmin = "http://enahar.org/exist/apps/metis/pradmin"  at "../PractitionerRole/pradmin.xqm";
import module namespace r-leave = "http://enahar.org/exist/restxq/metis/leaves" at "../Leave/leave-routes.xqm";

declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

declare variable $practrole:restxq-api := "/exist/restxq/metis/practitioners";
declare variable $practrole:restxq-pdf-api := "/exist/restxq/metis/practitioners2pdf";



declare variable $practrole:restxq-bd-pdf-api := "/exist/restxq/metis/users2birthdates";
(:~
 : Helper for dashboard to show available User Account functionality
 : 
 : @param  $user alias
 : @param  $uid  userid
 : 
 : @return html 
 :)
declare function practrole:showFunctions($account as element(fhir:PractitionerRole), $uid as xs:string)
{
    let $orga  := $account/fhir:organization/fhir:display/@value/string()
    let $roles := if (count($account/fhir:code)=0)
        then 'no Roles'
        else string-join($account/fhir:code/fhir:text/@value, ', ')
    let $perms := r-practrole:perms($uid)/fhir:perm
    let $isAdmin := $uid = ('u-admin','u-metis-admin')
    let $hasUA := 'perm_updateAccount' = $perms
    let $hasVL := 'perm_validateLeaves' = $perms
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid   := $logu/fhir:id/@value/string()
    let $perms   := r-practrole:perms($prid)/fhir:perm

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
declare %private function practrole:ensureGroup($group as xs:string) {
    if (not(sm:group-exists($group)))
    then system:as-user('admin', '', sm:create-group($group))
    else ()
};



declare function practrole:check-user($repoConf as element()) as xs:string+ {
    let $perms := $repoConf/repo:permissions
    let $user := if ($perms/@user) then $perms/@user/string() else sm:id()//sm:real/sm:username/string()
    let $group := if ($perms/@group) then $perms/@group/string() else sm:get-user-groups($user)[1]
    return
        try {
            let $create := system:as-user('admin', '', (
                if (sm:user-exists($user)) then
                    if (index-of(sm:get-user-groups($user), $group)) then
                        ()
                    else (
                        practrole:ensureGroup($group),
                        sm:add-group-member($user, $group)
                    )
                else (
                        practrole:ensureGroup($group),
                        sm:create-account($user, $perms/@password, $group, ())
                )))
            return 
                        ($user, $group)
    } catch * {
        ()
    }
};


declare %private function practrole:getName($id as xs:string*) as xs:string
{
    let $u := r-practrole:userByID($id,'ref')
    return
        $u//*:display/@value/string()
};



declare function practrole:listUsers()
{
    practrole:adminTeam()
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
declare function practrole:adminTeam()
{
    let $realm  := "metis/organizations/kikl-spzn"
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid   := $logu/fhir:id/@value/string()
    let $uref   := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid    := substring-after($uref,'metis/practitioners/')
    let $unam   := $logu/fhir:practitioner/fhir:display/@value/string()
    let $roles  := r-practrole:rolesByID($prid,$realm,$uid,$unam)
    let $org    := 'metis/organizations/kikl-spz'
    let $perms  := r-practrole:perms($prid)/fhir:perm
    let $isAdmin := $uid = ('u-admin','u-metis-admin')
    let $hasUA := 'perm_updateAccount' = $perms
    let $bundle :=  r-practrole:practRoles("1","*", '', '', '', '', '', '', 'true')
    let $today := tokenize(current-dateTime(),'T')[1]
    let $leaves := r-leave:leavesXML(
              $org, $uid, $unam
            , "1","*", "", ""
            , $today, $today
            , ('confirmed','tentative'), "")
return
    <div><h2>Mitarbeiter<span>({$bundle/fhir:length/string()})</span></h2>
        <table id="accounts" class="tablesorter">
            <thead>
                <tr id="0">
                    <th>Account?</th>
                    <th>Name</th>
                    <th>Beruf</th>
                    <th>Abwesenheit</th>
                    <th>Telecom</th>
                    <th>Realm</th>
                    <th>Büro</th>
                </tr>
            </thead>
            <tbody>{ practrole:accountsToRows($bundle/fhir:entry/fhir:resource/fhir:*,$leaves/leave, $today)}</tbody>
            <script type="text/javascript" defer="defer" src="../metis/FHIR/PractitionerRole/practrole.js"/>
        </table><br/>
<!--
    <a href="{$practrole:restxq-bd-pdf-api}">Geburtstagsliste</a>
-->
    </div>
};

declare %private function practrole:accountsToRows(
      $users as element(fhir:PractitionerRole)*
    , $leaves as element(leave)*
    , $today as xs:string
    )
{
    for $u in $users
    let $uid := $u/fhir:id/@value/string()
    let $hasAccount := $u/fhir:identifier[fhir:system/@value="http://eNahar.org/nabu/system#metis-account"]/fhir:value/@value != ''
    let $ls := if ($hasAccount)
        then $leaves/../leave[actor[reference[@value=$u/fhir:practitioner/fhir:reference/@value]]]
        else ()
    return
         <tr id="{$uid}">
            <td>{if ($hasAccount) then 'a' else ''}</td>
            <td>{$u/fhir:practitioner/fhir:display/@value/string()}</td>
            <td>{$u/fhir:specialty/fhir:text/@value/string()}</td>
            <td>
            {
            string-join(
                for $l in $ls
                return
                    if ($l/allDay/@value='true')
                    then let $lend := tokenize($l/period/end/@value,'T')[1]
                        return
                        if ($lend=$today)
                        then "heute"
                        else concat('bis ',tokenize($l/period/end/@value,'T')[1])
                    else concat(date:shortTime($l/period/start/@value),' bis ',date:shortTime($l/period/end/@value))
                , '; ')
            }    
            </td>
            <td>
            {   if ($u/fhir:telecom)
                then string-join($u/fhir:telecom/fhir:value/@value, ': ')
                else ''
            }
            </td>
            <td>{$u/fhir:organization/fhir:display/@value/string()}</td>
            <td>{$u/fhir:location/fhir:display/@value/string()}</td>
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
declare function practrole:editAccount($id as xs:string)
{
    let $realm  := "metis/organizations/kikl-spzn"
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid   := $logu/fhir:id/@value/string()
    let $uref   := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid    := substring-after($uref,'metis/practitioners/')
    let $unam   := $logu/fhir:practitioner/fhir:display/@value/string()
    let $roles  := r-practrole:rolesByID($prid,$realm,$uid,$unam)
    let $org    := 'metis/organizations/kikl-spz'
    let $perms  := r-practrole:perms($prid)/fhir:perm
    let $isAdmin := $uid = ('u-admin','u-metis-admin')
    let $hasUA   := 'perm_updateAccount' = $perms
    let $self := $uid = $id
    let $realm := 'kikl-spz'
    let $isGuest :='perm_get-patient-only' = $perms
    return
    if ($isGuest) then
        <div>
            <h2>Ihr Profil können Sie als Gast nicht editieren.</h2>
            <h2>Nur das Passwort ändern.</h2>
        </div>
    else if ($self) then
        prown:updateOwnAccount($logu, $uid, $unam, $realm)
    else if ($isAdmin or $hasUA) then
        pradmin:updateAccount($id, $uid, $unam, $realm)
    else 
        <div><p>{$uid}: has no authorization! Should not happen. Tell the admin.</p>
            <p>Permissions
            <ul>
                {for $p in $perms
                return
            <li>{$p}</li>
                }
            </ul>
            </p>
        </div>
};


declare variable $practrole:restxq-account       := "/exist/restxq/metis/PractitionerRole";
declare variable $practrole:restxq-organizations := "/exist/restxq/metis/organizations";
declare variable $practrole:restxq-roles         := "/exist/restxq/metis/roles";
declare variable $practrole:restxq-groups        := "/exist/restxq/metis/groups";


