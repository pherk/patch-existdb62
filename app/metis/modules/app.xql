xquery version "3.0";

module namespace app="http://enahar.org/exist/apps/metis";

import module namespace templates="http://exist-db.org/xquery/templates";

import module namespace config   ="http://enahar.org/exist/apps/metis/config"  at "config.xqm";
import module namespace help     ="http://enahar.org/exist/apps/metis/help"    at "help.xqm";

import module namespace r-practrole ="http://enahar.org/exist/restxq/metis/practrole"
                       at "../FHIR/PractitionerRole/practitionerrole-routes.xqm";
import module namespace practitioner = "http://enahar.org/exist/apps/metis/practitioner" at "../FHIR/Practitioner/practitioner.xqm";
import module namespace practrole = "http://enahar.org/exist/apps/metis/practrole" at "../FHIR/PractitionerRole/practitionerrole.xqm";
import module namespace prpass   = "http://enahar.org/exist/apps/metis/prpass" at "../FHIR/PractitionerRole/prpass.xqm";
import module namespace organization = "http://enahar.org/exist/apps/metis/organization" at "../FHIR/Organization/organization.xqm";
import module namespace leave    = "http://enahar.org/exist/apps/metis/leave"            at "../FHIR/Leave/leave.xqm";
import module namespace loc      = "http://enahar.org/exist/apps/metis/location"         at "../FHIR/Location/location.xqm";
import module namespace device   = "http://enahar.org/exist/apps/metis/device"           at "../FHIR/Device/device.xqm";


declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace fhir   = "http://hl7.org/fhir";

(:~
 : This is a sample templating function. It will be called by the templating module if
 : it encounters an HTML element with a class attribute: class="app:test". The function
 : has to take exactly 3 parameters.
 : 
 : @param $node the HTML node with the class attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function app:main($node as node(), $model as map(*), $action, $topic, $uid)
{
    let $server := request:get-header('host')
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $pref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $pid  := substring-after($pref,'metis/practitioners/')
    return
        switch($action)
        case 'editAccount'      return practrole:editAccount($pid)
        case 'changePasswd'     return prpass:changePasswd($logu)
        case 'help'             return help:help($topic)
        case 'listContacts'     return practitioner:listContacts()
        case 'listOrganizations' return organization:listOrganizations()
        case 'listLeaves'       return leave:listLeaves()
        case 'editLeave'        return leave:editLeave($uid)
        case 'newLeave'         return leave:userNew()
        case 'editLocation'     return loc:locations()
        default                 return practrole:editAccount($pid)
};

declare function app:news($node as node(), $model as map(*)) {
<div>
    <h4>Aktuelles</h4>
    <dl>
        <dt>29.12.2023 (v1.0.1)</dt>
        <dd>
            <ul>
                <li>Passwort Ändern wieder funktional</li>
            </ul>
        </dd>
        <dt>19.06.2020 (v1.0)</dt>
        <dd>
            <ul>
                <li>Practitioner and PractitionerRoles splitted</li>
            </ul>
        </dd>
        <dt>19.08.2018 (v0.9.0)</dt>
        <dd>
            <ul>
                <li>Devices and Locations revisited</li>
            </ul>
        </dd>
        <dt>04.03.2016 (v0.6.9)</dt>
        <dd>
            <ul>
                <li>Datenspeicherung und -zugriff verbessert.</li>
                <li><a href="/exist/apps/metis/FHIR/Leave/d3leaves.html">Graphische Urlaubsübersicht</a></li>
            </ul>
        </dd>
        <dt>16.02.2015</dt>
        <dd>Abwesenheiten, Entities implementiert</dd>
        <dt>16.01.2015</dt>
        <dd>User/RBAC an FHIR-Resourcen adaptiert</dd>
        <dt>24.10.2014</dt>
        <dd>Das User Management wurde in die Applikation "Metis ID" ausgelagert.</dd>
        <dd>Die Accounts sind für die App-Familie "Nabu, Metis, eNahar" identisch und
            werden von Metis ID incl. der User-Profile verwaltet.</dd>
    </dl>
</div>
};

declare function app:dashboard($node as node(), $model as map(*)) {
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
return
    if ($uid)
    then <div><br/>
            <p>{$uid}: it is {current-dateTime()}</p>
                {practrole:showFunctions($logu,$uid)}
            <!-- {leave:showFunctions($uid)} in user functions -->
                {practitioner:showFunctions()}
                {loc:showFunctions($logu, $uid)}
                {help:showFunctions()}
        </div>
    else
        <div><br/>
        <p><strong>User not found. Most certainly a bug. Tell the admin.</strong></p>
        </div>
};


declare function app:main-admin($node as node(), $model as map(*), $action as xs:string*, $what as xs:string*, $uid as xs:string*) 
{
    if ($action="validate")
    then
        switch ($what)
        case "leaves" return 
            leave:adminValidateAll()
        case "leave" return
            leave:adminValidateSingle($uid)
        default return app:admin()
    else if ($action="show")
    then
        switch ($what)
        case 'account' return practrole:editAccount($uid)
        case 'newaccount' return practrole:editAccount($uid)
        case 'leave'   return leave:editLeave($uid)
        case "team"    return practrole:adminTeam()
        case "new_team" return practrole:adminTeam()
        case "leaves"  return leave:listLeaves()
        case 'locations' return loc:locations()
        case 'devices' return device:devices()
        default return app:admin()
    else if ($action="new")
    then
        switch ($what)
        case 'leave'   return leave:adminNew()
        default return app:admin()
    else app:admin()
};

declare function app:admin() 
{
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $isAdmin := $prid = ('u-admin')
    let $hasUA := 'perm_updateAccount' = $perms
    let $hasVL := 'perm_validateLeaves' = $perms
    return
    if ($isAdmin or $hasUA or $hasVL)
    then
        <div>
            <h4>Admin-Funktionen</h4>
            <ul>
                <li>Team
                <ul>
                    <!--
                    <li>
                        <a href="./admin.html?action=show&amp;what=team">Alte Teamliste</a>
                    </li>
                    -->
                    <li>
                        <a href="./admin.html?action=show&amp;what=new_team">Neue Teamliste</a>
                    </li>
                </ul>
                </li>
                <li>Abwesenheiten
                    <ul>
                        <li>
                            <a href="./admin.html?action=validate&amp;what=leaves">Vidieren</a>
                        </li>
                        <li>
                            <a href="./admin.html?action=show&amp;what=leaves">Übersicht</a>
                        </li>
                    </ul>
                </li>
                <li>Facility-Management
                    <ul>
                        <li>
                            <a href="./admin.html?action=show&amp;what=locations">Locations</a>                    
                        </li>
                        <li>
                            <a href="./admin.html?action=show&amp;what=devices">Devices</a>                    
                        </li>
                    </ul>
                </li>
            </ul>
            <h4>Statistiken</h4>
            <ul>
                <li>
                    <a href="./admin.html?action=show&amp;what=workload">Auslastung</a>
                </li>
            </ul>
        </div>
    else
        <div>Sie sind nicht authorisiert, Admin-Funktionen auszuführen</div>
};
