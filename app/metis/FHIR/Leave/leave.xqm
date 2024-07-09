xquery version "3.0";

module namespace leave = "http://enahar.org/exist/apps/metis/leave";

import module namespace config  = "http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";

import module namespace r-leave = "http://enahar.org/exist/restxq/metis/leaves" at "../Leave/leave-routes.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"
     at "../PractitionerRole/practitionerrole-routes.xqm";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

declare variable $leave:restxq-leaves := "/exist/restxq/metis/leaves";
declare variable $leave:leave-infos-uri := "FHIR/Leave/leave-infos.xml";
declare variable $leave:regexp-date := "(19|20)\d\d[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])";
declare variable $leave:regexp-time := "([01]?[0-9]|2[0-3]):[0-5][0-9]";
declare variable $leave:regexp-iso  := "\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\d";
(:~
 : Helper for dashboard to show available User Account functionality
 : 
 : @param  $user alias
 : @param  $uid  userid
 : 
 : @return html 
 :)
declare function leave:showFunctions($uid as xs:string)
{
    let $perms := r-practrole:perms($uid)/fhir:perm
    let $hasUA := 'perm_updateAccount' = $perms
    return
    <div>
        <ul>
                <li>
                    <a href="index.html?action=listLeaves">Abwesenheiten</a>
                </li>
        </ul>
    </div>
};

(:~
 : presents table with User Account
 : 
 : @return html 
 :)
declare function leave:listLeaves()
{
    let $logu := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  :=  substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $org   := 'metis/organizations/kikl-spzn'
    let $realm   := $org
    let $isAdmin := $uid=('u-admin')
    let $today := adjust-dateTime-to-timezone(current-dateTime(),())
    let $hasUA   := $isAdmin or 'perm_validateLeaves' = $perms
    let $year := tokenize(current-dateTime(),'-')[1]
    let $start := if ($hasUA)
        then $year || "-01-01"
        else $today
    let $leaves := r-leave:leavesXML(
              $org, $uid, $unam
            , "1","*"
            , $uid, ""
            , $start, "2026-04-01T23:59:59"
            , ('cancelled','confirmed','tentative'), "")
return
    <div><h2>Abwesenheiten<span>({$leaves/count/string()})</span></h2>
        <table id="leaves" class="tablesorter">
            <thead>
                <tr id="0">
                    <th>Name</th>
                    <th data-value="">Von</th>
                    <th>Bis</th>
                    <th>Titel</th>
                    <th>Grund</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>{ leave:leavesToRows($leaves) }</tbody>
            <script type="text/javascript" defer="defer" src="FHIR/Leave/listLeaves.js"/>
        </table><br/>
        <h4>Was möchten Sie tun?</h4>
        <ul>
            <li><a href="index.html?action=newLeave&amp;uid={$uid}">Neue Abwesenheit eintragen</a></li>
            <li><a href="index.html?action=editAccount&amp;uid={$uid}">Persönliche Daten ändern</a></li>
            <li><a href="index.html?action=changePasswd&amp;uid={$uid}">Passwort ändern</a></li>
        </ul>
    </div>
};

(:~
 : validate
 : presents table with leaves for validation
 : 
 : @return html 
 :)
declare function leave:adminValidateAll()
{
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $org   := 'metis/organizations/kikl-spzn'
    let $realm := $org
    let $start := tokenize(current-dateTime(),'-')[1] || "-01-01"
    let $leaves := r-leave:leavesXML(
              $org, $uid, $unam
            ,"1","*"
            , "", ""
            , $start, "2026-04-01"
            ,("confirmed","tentative"),"")
return
    <div>
        <h2>Abwesenheiten</h2>
        <table id="leaves" class="tablesorter">
            <thead>
                <tr id="0">
                    <th>Name</th>
                    <th data-value="">Von</th>
                    <th>Bis</th>
                    <th>Titel</th>
                    <th>Grund</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>{ leave:leavesToRows($leaves) }</tbody>
            <script type="text/javascript" defer="defer" src="FHIR/Leave/validate.js"/>
        </table><br/>
        <h4>Sonst noch was?</h4>
        <ul>
            <li><a href="admin.html?action=new&amp;what=leave">Neue Abwesenheit eintragen</a></li>
        </ul>
    </div>
};

declare %private function leave:workdays($start as xs:date, $end as xs:date)
{
  let $cdays := ($end - $start) div xs:dayTimeDuration('P1D') + 1
  return 
      $cdays - 2 * ($cdays idiv 7)
};

declare %private function leave:leavesToRows($leaves)
{
    for $l in $leaves/leave
    let $lid := $l/id/@value/string()
    let $start := tokenize($l/period/start/@value,'T')[1]
    let $end   := tokenize($l/period/end/@value,'T')[1]
(:  let $wd    := leave:workdays($start,$end) :)
    return
         <tr id="{$lid}">
            <td>{$l/actor/display/@value/string()}</td>
            <td>{$start}</td> 
            <td>{$end}</td>
            <td>{$l/summary/@value/string()}</td>
            <td>{$l/cause/coding/display/@value/string()}</td>
            <td>{$l/status/coding/display/@value/string()}</td>
         </tr> 
};


declare function leave:editLeave($id)
{
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $org     := 'metis/organizations/kikl-spzn'
    let $realm   := $org
let $lll := util:log-app('TRACE','apps.nabu',$id)
    let $leave   := r-leave:leaveByID($id, $org, $uid, $unam)
let $lll := util:log-app('TRACE','apps.nabu',$leave)
    let $header  := concat("Abwesenheit", " (", $leave/actor/display/@value, ")")
    let $isAdmin := $uid=('u-admin','u-metis-admin')
    let $hasUA   := $isAdmin or 'perm_validateLeaves' = $perms
    let $start   := $leave//*:period/*:start/@value/string()
    let $end     := $leave//*:period/*:end/@value/string()
    let $isFutureLeave := if ($start > tokenize(current-dateTime(),'T')[1] or
                                $end > tokenize(current-dateTime(),'T')[1]
                  )
        then 'true'
        else 'false'
    return
(<div style="display:none;">
    <xf:model id="mleaves">
        <xf:instance xmlns="" id="i-leave">
            <data>{$leave}</data>
        </xf:instance>
    
        <xf:bind ref="instance('i-leave')/leave">
            <xf:bind ref="*:summary/@value" type="xs:string"   required="true()"/>
            <xf:bind ref="./*:period/*:start/@value" type="xs:dateTime" required="true()"/>
            <xf:bind ref="./*:period/*:end/@value" type="xs:dateTime" required="true()"/>
            <xf:bind ref="*:cause/*:coding/*:code/@value"   type="xs:string"   required="true()"/>
            <xf:bind ref="*:allDay/@value"  type="xs:boolean"  required="true()"/>
        </xf:bind>

        <xf:submission id="s-submit-leave"
                				   ref="instance('i-leave')/leave"
								   method="put"
								   replace="none">
			<xf:resource value="concat('{$leave:restxq-leaves}','?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('control-instance')/dirty">false</xf:setvalue>
                <xf:message level="ephemeral">leave submitted</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit leaves! Server error?</xf:message>
        </xf:submission>

        <xf:instance xmlns="" id="i-dateTime">
            <data>
                <startdate>{tokenize($start,'T')[1]}</startdate>
                <startTime>{substring(tokenize($start,'T')[2],1,8)}</startTime>
                <enddate>{tokenize($end,'T')[1]}</enddate>
                <endTime>{substring(tokenize($end,'T')[2],1,8)}</endTime>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-dateTime')/*:startdate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:startTime" type="xs:time"/>
        <xf:bind ref="instance('i-dateTime')/*:enddate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:endTime" type="xs:time"/>

        <xf:instance id="control-instance">
            <control xmlns="">
                <dirty>false</dirty>
                <save-trigger/>
                <hasSubject/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('control-instance')/save-trigger" relevant="../dirty = 'true'"/>
        <xf:bind nodeset="instance('control-instance')/hasSubject"   relevant="instance('i-leave')//*:actor/*:reference/@value != ''"/>

        <xf:instance id="views">
            <control xmlns="">
                <timeNeeded/>
                <timeNotNeeded/>
                <FutureLeave/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('views')/*:timeNeeded"    relevant="instance('i-leave')/*:leave/*:allDay/@value='false'"/>
        <xf:bind nodeset="instance('views')/*:timeNotNeeded" relevant="instance('i-leave')/*:leave/*:allDay/@value='true'"/>
        <xf:bind nodeset="instance('views')/*:FutureLeave" relevant="'{$isFutureLeave}' = 'true'"/>

        <xf:instance id="i-leaveInfos" src="{$leave:leave-infos-uri}"/>
        
        <xf:instance id="i-dfa" xmlns="">
            <data>
                <event>leave</event>
            </data>
        </xf:instance>

        <xf:action ev:event="xforms-ready">
        </xf:action>
    </xf:model>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <table>
        <tr>
            <td colspan="3">
                { if ($hasUA)
                    then leave:mkFullLeaveGroup()
                    else leave:showLeaveGroup()
                }
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Abbrechen</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/index.html?action=listLeaves"/> 
                </xf:trigger>
            </td>
            { if ($hasUA)
                then
            <td>
                <xf:select1 ref="instance('i-dfa')/*:event" class="medium-select" incremental="true">
                    <xf:label>Workflow:</xf:label>
                    <xf:itemset ref="instance('i-leaveInfos')/scxml/state[@id = 'tentative']/transition">
                        <xf:label ref="./@event"/>
                        <xf:value ref="./@event"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='open'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'tentative'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='cancel'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'cancelled'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='confirm'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'confirmed'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='leave'">
                        <xf:message level="ephemeral">don't touch</xf:message>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ev:event="xforms-value-changed" 
                            ref="instance('control-instance')/dirty">true</xf:setvalue>
                        <xf:setvalue
                            ref="instance('i-leave')//status/coding/display/@value"
                            value="instance('i-leaveInfos')/state[@value= instance('i-leave')//status/coding/code/@value]/@label"/>
                    </xf:action>
                </xf:select1>
            </td>
                else 
            <td>
                <xf:group ref="instance('views')/*:FutureLeave">
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Löschen</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'cancelled'"/>
                            <xf:setvalue
                                ref="instance('i-leave')//status/coding/display/@value"
                                value="instance('i-leaveInfos')/state[@value= instance('i-leave')//status/coding/code/@value]/@label"/>
                        </xf:action>
                    </xf:trigger>
                </xf:group>
            </td>
            }
            <td>
                <xf:trigger ref="instance('control-instance')/save-trigger"  class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:hint>This button will save the ticket.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-leave"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</div>
)
};

declare function leave:adminValidateSingle($id)
{
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $org     := 'metis/organizations/kikl-spz'
    let $leave   := r-leave:leaveByID($id, $org, $uid, $unam)
    let $realm   := $org
    let $header  := concat("Abwesenheit", " (", $leave/actor/display/@value, ")")
    let $isAdmin := $uid=('u-admin','u-metis-admin')
    let $hasUA   := $isAdmin or 'perm_validateLeaves' = $perms
    let $start   := $leave//*:period/*:start/@value/string()
    let $end     := $leave//*:period/*:end/@value/string()
    return
(<div style="display:none;">
    <xf:model id="mleaves">
        <xf:instance xmlns="" id="i-leave">
            <data>{$leave}</data>
        </xf:instance>
    
        <xf:bind ref="instance('i-leave')/leave">
            <xf:bind ref="*:summary/@value" type="xs:string"   required="true()"/>
            <xf:bind ref="./*:period/*:start/@value" type="xs:dateTime" required="true()"/>
            <xf:bind ref="./*:period/*:end/@value" type="xs:dateTime" required="true()"/>
            <xf:bind ref="*:cause/*:coding/*:code/@value"   type="xs:string"   required="true()"/>
            <xf:bind ref="*:allDay/@value"  type="xs:boolean"  required="true()"/>
        </xf:bind>

        <xf:submission id="s-submit-leave"
                				   ref="instance('i-leave')/leave"
								   method="put"
								   replace="none">
			<xf:resource value="concat('{$leave:restxq-leaves}','?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">leave submitted</xf:message>
                <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/admin.html?action=validate&amp;what=leaves"/> 
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit leaves! Server error?</xf:message>
        </xf:submission>

        <xf:instance xmlns="" id="i-dateTime">
            <data>
                <startdate>{tokenize($start,'T')[1]}</startdate>
                <startTime>{tokenize($start,'T')[2]}</startTime>
                <enddate>{tokenize($end,'T')[1]}</enddate>
                <endTime>{tokenize($end,'T')[2]}</endTime>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-dateTime')/*:startdate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:startTime" type="xs:time"/>
        <xf:bind ref="instance('i-dateTime')/*:enddate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:endTime" type="xs:time"/>

        <xf:instance id="control-instance">
            <control xmlns="">
                <dirty>false</dirty>
                <save-trigger/>
                <hasSubject/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('control-instance')/save-trigger" relevant="../dirty = 'true'"/>
        <xf:bind nodeset="instance('control-instance')/hasSubject"   relevant="instance('i-leave')//*:actor/*:reference/@value != ''"/>

        <xf:instance id="views">
            <control xmlns="">
                <timeNeeded/>
                <timeNotNeeded/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('views')/timeNeeded" relevant="instance('i-leave')/*:leave/*:allDay/@value='false'"/>
        <xf:bind nodeset="instance('views')/timeNotNeeded" relevant="instance('i-leave')/*:leave/*:allDay/@value='true'"/>

        <xf:instance id="i-leaveInfos" src="{$leave:leave-infos-uri}"/>
        
        <xf:instance id="i-dfa" xmlns="">
            <data>
                <event>leave</event>
            </data>
        </xf:instance>

        <xf:action ev:event="xforms-ready">
        </xf:action>
    </xf:model>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <table>
        <tr>
            <td colspan="3">
                { leave:mkFullLeaveGroup() }
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Abbrechen</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/admin.html?action=validate&amp;what=leaves"/> 
                </xf:trigger>
            </td>
            <td>
                <xf:select1 ref="instance('i-dfa')/*:event" class="medium-select" incremental="true">
                    <xf:label>Workflow:</xf:label>
                    <xf:itemset ref="instance('i-leaveInfos')/scxml/state[@id = 'tentative']/transition">
                        <xf:label ref="./@event"/>
                        <xf:value ref="./@event"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='open'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'tentative'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='cancel'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'cancelled'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='confirm'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'confirmed'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='leave'">
                        <xf:message level="ephemeral">don't touch</xf:message>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ev:event="xforms-value-changed" 
                            ref="instance('control-instance')/dirty">true</xf:setvalue>
                        <xf:setvalue
                            ref="instance('i-leave')//status/coding/display/@value"
                            value="instance('i-leaveInfos')/state[@value= instance('i-leave')//status/coding/code/@value]/@label"/>
                    </xf:action>
                </xf:select1>
            </td>
            <td>
                <xf:trigger ref="instance('control-instance')/save-trigger"  class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:hint>This button will save the ticket.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-leave"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</div>
)
};

declare function leave:adminNew()
{
    let $realm  := "kikl-spzn"
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $roles  := r-practrole:rolesByID($prid,$realm,$uid,$unam)
    let $org    := concat('metis/organizations/',$realm)
    let $realm  := $org
    let $header := "Neue Abwesenheit"
    let $itsme := $uid=('u-admin','u-metis-admin')
    let $hasUA := $itsme
    let $today  := adjust-date-to-timezone(current-date(),())
    let $ctime  := format-dateTime(current-dateTime(),'[H01]:[m01]:[s01]')
    let $now    := concat($today,'T',$ctime)
    return
(<div style="display:none;">
    <xf:model id="mleaves">
        <xf:instance xmlns="" id="i-leave">
            <data/>
        </xf:instance>
    
        <xf:bind ref="instance('i-leave')/*:leave">
            <xf:bind ref="./*:period/*:start/@value" type="xs:string"
                    constraint="matches(.,'\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d')" required="true()"/>
            <xf:bind ref="./*:period/*:end/@value" type="xs:string"
                    constraint="matches(.,'\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d')" required="true()"/>
            <xf:bind ref="./*:summary/@value" type="xs:string"   required="true()"/>
            <xf:bind ref="./*:cause/*:coding/*:code/@value"   type="xs:string"   required="true()"/>
            <xf:bind ref="./*:allDay/@value"  type="xs:boolean"  required="true()"/>
        </xf:bind>

        <xf:submission id="s-submit-leave"
                				   ref="instance('i-leave')/*:leave"
								   method="put"
								   replace="none">
			<xf:resource value="concat('{$leave:restxq-leaves}','?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('control-instance')/dirty">false</xf:setvalue>
                <xf:message level="ephemeral">leave submitted</xf:message>
                <xf:setvalue ref="instance('i-leave')//summary/@value" value="''"/>
                <xf:setvalue ref="instance('i-leave')//description/@value" value="''"/>
                <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'tentative'"/>
                <xf:setvalue ref="instance('i-leave')//status/coding/display/@value" value="'provisorisch'"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit leaves! Validation or Server error?</xf:message>
        </xf:submission>

        <xf:instance xmlns="" id="i-dateTime">
            <data>
                <startdate>{$today}</startdate>
                <startTime>{$ctime}</startTime>
                <enddate>{$today}</enddate>
                <endTime>{$ctime}</endTime>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-dateTime')/*:startdate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:startTime" type="xs:time"/>
        <xf:bind ref="instance('i-dateTime')/*:enddate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:endTime" type="xs:time"/>

        <xf:instance id="control-instance">
            <control xmlns="">
                <dirty>false</dirty>
                <save-trigger/>
                <hasSubject/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('control-instance')/save-trigger" relevant="../dirty = 'true'"/>
        <xf:bind nodeset="instance('control-instance')/hasSubject"   relevant="instance('i-leave')//*:actor/*:reference/@value!=''"/>

        <xf:instance id="views">
            <control xmlns="">
                <timeNeeded/>
                <timeNotNeeded/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('views')/timeNeeded" relevant="instance('i-leave')/*:leave/*:allDay/@value='false'"/>
        <xf:bind nodeset="instance('views')/timeNotNeeded" relevant="instance('i-leave')/*:leave/*:allDay/@value='true'"/>

        <xf:instance id="i-leaveInfos" src="{$leave:leave-infos-uri}"/>
        
        <xf:instance id="i-dfa" xmlns="">
            <data>
                <event>leave</event>
            </data>
        </xf:instance>

        <xf:action ev:event="xforms-ready">
            <xf:insert nodeset="instance('i-leave')/leave" 
                context="instance('i-leave')"
                origin="instance('i-leaveInfos')/*:bricks/*:leave"/>
            <xf:setvalue ref="instance('i-leave')//*:actor/*:reference/@value" value="concat('metis/practitioners/', '{$uid}')"/>
            <xf:setvalue ref="instance('i-leave')//*:actor/*:display/@value" value="'{$unam}'"/>
            <xf:setvalue ref="instance('i-leave')//*:period/*:start/@value" value="concat(format-dateTime(current-dateTime(),'[Y0001]-[M01]-[D01]'),'T00:00:00')"/>
            <xf:setvalue ref="instance('i-leave')//*:period/*:end/@value"   value="concat(format-dateTime(current-dateTime(),'[Y0001]-[M01]-[D01]'),'T23:59:59')"/>
        </xf:action>
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
        <xf:input id="subject-ref"     ref="instance('i-leave')//*:actor/*:reference/@value"/>
        <xf:input id="subject-display" ref="instance('i-leave')//*:actor/*:display/@value"/>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <table>
        <tr>
            <td>
                <label for="subject-hack" class="xfLabel aDefault xfEnabled">Mitarbeiter:</label>
                <select class="leave-select" type="text" name="subject-hack"/>
                <script type="text/javascript" defer="defer" src="FHIR/Leave/leave.js"/>
                <br/>
            </td>
        </tr>
        <tr>
            <td colspan="3">
                { leave:mkFullLeaveGroup() }
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Abbrechen</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/admin.html?action=validate&amp;what=leaves"/> 
                </xf:trigger>
            </td>
            <td>
                <xf:select1 ref="instance('i-dfa')/*:event" class="medium-select" incremental="true">
                    <xf:label>Workflow:</xf:label>
                    <xf:itemset ref="instance('i-leaveInfos')/scxml/state[@id='tentative']/transition">
                        <xf:label ref="./@event"/>
                        <xf:value ref="./@event"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='open'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'tentative'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='cancel'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'cancelled'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='confirm'">
                        <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'confirmed'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='leave'">
                        <xf:message level="ephemeral">don't touch</xf:message>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ev:event="xforms-value-changed" 
                            ref="instance('control-instance')/dirty">true</xf:setvalue>
                        <xf:setvalue
                            ref="instance('i-leave')//status/coding/display/@value"
                            value="instance('i-leaveInfos')/state[@value= instance('i-leave')//status/coding/code/@value]/@label"/>
                    </xf:action>
                </xf:select1>
            </td>
            <td>
                <xf:trigger  ref="instance('control-instance')/hasSubject" class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:hint>This button will save the ticket.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-leave"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</div>
)
};

declare function leave:userNew()
{
    let $realm  := "metis/organizations/kikl-spzn"
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $roles  := r-practrole:rolesByID($prid,$realm,$uid,$unam)
    let $header := "Neue Abwesenheit"
    let $today  := adjust-date-to-timezone(current-date(),())
    let $ctime  := format-dateTime(current-dateTime(),'[H01]:[m01]:[s01]')
    let $now    := concat($today,'T',$ctime)
    return
(<div style="display:none;">
    <xf:model id="mleaves">
        <xf:instance xmlns="" id="i-leave">
            <data/>
        </xf:instance>
    
        <xf:bind ref="instance('i-leave')/leave">
            <xf:bind ref="./*:period/*:start/@value" type="xs:string"
                    constraint="matches(.,'\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d')" required="true()"/>
            <xf:bind ref="./*:period/*:end/@value" type="xs:string"
                    constraint="matches(.,'\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d')" required="true()"/>
            <xf:bind ref="summary/@value" type="xs:string"   required="true()"/>
            <xf:bind ref="cause/coding/code/@value"   type="xs:string"   required="true()"/>
            <xf:bind ref="allDay/@value"  type="xs:boolean"  required="true()"/>
        </xf:bind>

        <xf:submission id="s-submit-leave"
                				   ref="instance('i-leave')/*:leave"
								   method="put"
								   replace="none">
			<xf:resource value="concat('{$leave:restxq-leaves}','?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('control-instance')/dirty">false</xf:setvalue>
                <xf:message level="ephemeral">leave submitted</xf:message>
                <xf:setvalue ref="instance('i-leave')//summary/@value" value="''"/>
                <xf:setvalue ref="instance('i-leave')//description/@value" value="''"/>
                <xf:setvalue ref="instance('i-leave')//status/coding/code/@value" value="'tentative'"/>
                <xf:setvalue ref="instance('i-leave')//status/coding/display/@value" value="'provisorisch'"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit leaves! Validation or Server error?</xf:message>
        </xf:submission>

        <xf:instance xmlns="" id="i-dateTime">
            <data>
                <startdate>{$today}</startdate>
                <startTime>08:00:00</startTime>
                <enddate>{$today}</enddate>
                <endTime>17:00:00</endTime>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-dateTime')/*:startdate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:startTime" type="xs:time"/>
        <xf:bind ref="instance('i-dateTime')/*:enddate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:endTime" type="xs:time"/>

        <xf:instance id="control-instance">
            <control xmlns="">
                <dirty>false</dirty>
                <save-trigger/>
                <hasSubject/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('control-instance')/save-trigger" relevant="../dirty = 'true'"/>
        <xf:bind nodeset="instance('control-instance')/hasSubject"   relevant="instance('i-leave')//*:actor/*:reference/@value!=''"/>

        <xf:instance id="views">
            <control xmlns="">
                <timeNeeded/>
                <timeNotNeeded/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('views')/timeNeeded" relevant="instance('i-leave')/*:leave/*:allDay/@value='false'"/>
        <xf:bind nodeset="instance('views')/timeNotNeeded" relevant="instance('i-leave')/*:leave/*:allDay/@value='true'"/>

        <xf:instance id="i-leaveInfos" src="{$leave:leave-infos-uri}"/>
        
        <xf:instance id="i-dfa" xmlns="">
            <data>
                <event>leave</event>
            </data>
        </xf:instance>

        <xf:action ev:event="xforms-ready">
            <xf:insert nodeset="instance('i-leave')/leave" 
                context="instance('i-leave')"
                origin="instance('i-leaveInfos')/*:bricks/*:leave"/>
            <xf:setvalue ref="instance('i-leave')//*:actor/*:reference/@value" value="'{$uref}'"/>
            <xf:setvalue ref="instance('i-leave')//*:actor/*:display/@value" value="'{$unam}'"/>
            <xf:setvalue ref="instance('i-leave')//*:period/*:start/@value" value="concat(format-dateTime(current-dateTime(),'[Y0001]-[M01]-[D01]'),'T00:00:00')"/>
            <xf:setvalue ref="instance('i-leave')//*:period/*:end/@value"   value="concat(format-dateTime(current-dateTime(),'[Y0001]-[M01]-[D01]'),'T23:59:59')"/>
        </xf:action>
    </xf:model>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <table>
        <tr>
            <td>
                <xf:output ref="instance('i-leave')//*:actor/*:display/@value">
                    <xf:label class="svListHeader">Mitarbeiter:</xf:label>
                </xf:output>
                <br/>
            </td>
        </tr>
        <tr>
            <td colspan="3">
                { leave:mkFullLeaveGroup() }
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Abbrechen</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/index.html?action=listLeaves"/> 
                </xf:trigger>
            </td>
            <td>
                <xf:trigger  ref="instance('control-instance')/hasSubject" class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:hint>This button will save the ticket.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-leave"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</div>
)
};

declare %private function leave:showLeaveGroup()
{
    <xf:group class="svFullGroup bordered">
        <xf:label>Details</xf:label>
            <xf:group  ref="instance('i-leave')/leave" class="svFullGroup">
            <xf:setvalue ev:event="xforms-value-changed" 
                ref="instance('control-instance')/dirty">true</xf:setvalue>
            <xf:output id="evt-title" ref="./summary/@value" class="medium-input">
                <xf:label class="svListHeader">Titel:</xf:label>
            </xf:output>
            <xf:output ref="./lastModifiedBy/display/@value">
                <xf:label>Von:</xf:label>
            </xf:output>
            <xf:output ref="./lastModified/@value">
                <xf:label>am:</xf:label>
            </xf:output>
            <br/>
            <xf:output id="evt-cause" value="concat(./cause/coding/display/@value, ' : ')">
                <xf:label class="svListHeader">Anlass:</xf:label>
            </xf:output>
            <xf:output value="choose(./allDay/@value,'ganztägig abwesend','teilweise abwesend')"/>
            <br/>
            <xf:group ref="instance('views')/*:timeNeeded">
                <xf:output id="evt-start" value="concat(instance('i-leave')//period/start/@value,' bis ',instance('i-leave')//period/end/@value)">
                    <xf:label class="svListHeader">Zeitraum:</xf:label>
                </xf:output>
            </xf:group>
            <xf:group ref="instance('views')/*:timeNotNeeded">
                <xf:output id="evt-start" value="concat(tokenize(instance('i-leave')//period/start/@value,'T')[1],' bis ',tokenize(instance('i-leave')//period/end/@value,'T')[1])">
                    <xf:label class="svListHeader">Zeitraum</xf:label>
                </xf:output>
            </xf:group>
            <xf:textarea class="fullarea" ref="./description/@value">
                <xf:label id="evt-note" class="svListHeader">Notiz:</xf:label>
            </xf:textarea>
            <xf:output id="evt-status" ref="./status/coding/display/@value">
                <xf:label class="svListHeader">Status:</xf:label>
            </xf:output>
        </xf:group>
    </xf:group>
};

declare %private function leave:mkFullLeaveGroup()
{
    <xf:group ref="instance('control-instance')/hasSubject" class="svFullGroup bordered">
        <xf:label>Details</xf:label>
        <xf:group  ref="instance('i-leave')/leave" class="svFullGroup">
            <xf:setvalue ev:event="xforms-value-changed" 
                    ref="instance('control-instance')/dirty">true</xf:setvalue>
            <xf:input id="evt-title" ref="./summary/@value" class="">
                <xf:label class="svListHeader">Titel:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:output ref="./lastModifiedBy/display/@value">
                <xf:label>Zuletzt:</xf:label>
            </xf:output>
            <xf:output ref="./lastModified/@value">
                <xf:label>am:</xf:label>
            </xf:output>
            <br/>
            <xf:select1 id="evt-cause" ref="./cause/coding/code/@value" class="medium-select">
                <xf:label class="svListHeader">Grund:</xf:label>
                <xf:itemset nodeset="instance('i-leaveInfos')/cause">
                    <xf:label ref="./@label"/>
                    <xf:value ref="./@value"/>
                </xf:itemset>
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="instance('i-leave')//cause/coding/display/@value"
                        value="instance('i-leaveInfos')/cause[@value=instance('i-leave')//cause/coding/code/@value]/@label"/>
                </xf:action>
            </xf:select1>
            <xf:input ref="./allDay/@value">
                <xf:label class="svListHeader">Ganzer Tag?:</xf:label>
                <xf:action ev:event="xforms-value-changed">
                </xf:action>
            </xf:input><br/>
            <xf:input ref="instance('i-dateTime')/*:startdate" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'" incremental="true">
                <xf:label>Von:</xf:label>
                <xf:hint>dd.mm.yyyy</xf:hint>
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="instance('i-leave')//*:period/*:start/@value"
                        value="concat(instance('i-dateTime')/*:startdate,'T',instance('i-dateTime')/*:startTime)"/>
                </xf:action>
            </xf:input>
            <xf:select1 ref="instance('i-dateTime')/*:startTime" incremental="true">
                <xf:label class="svListHeader">Uhr:</xf:label>
                <xf:itemset ref="instance('i-leaveInfos')/*:time/*:code">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                </xf:itemset>                    
                <xf:action ev:event="xforms-value-changed">
                    <xf:action if="instance('i-dateTime')/*:startTime =''">
                        <xf:setvalue ref="instance('i-dateTime')/*:startTime" value="'08:00:00'"/>
                    </xf:action>
                    <xf:setvalue ref="instance('i-leave')//*:period/*:start/@value"
                        value="concat(instance('i-dateTime')/*:startdate,'T',instance('i-dateTime')/*:startTime)"/>
                </xf:action>
            </xf:select1><br/>
            <xf:input ref="instance('i-dateTime')/*:enddate" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'" incremental="true">
                <xf:label>Bis:</xf:label>
                <xf:hint>dd.mm.yyyy</xf:hint>
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="instance('i-leave')//*:period/*:end/@value"
                        value="concat(instance('i-dateTime')/*:enddate,'T',instance('i-dateTime')/*:endTime)"/>
                </xf:action>
            </xf:input>
            <xf:select1 ref="instance('i-dateTime')/*:endTime" incremental="true">
                <xf:label class="svListHeader">Uhr:</xf:label>
                <xf:itemset ref="instance('i-leaveInfos')/*:time/*:code">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                </xf:itemset> 
                <xf:action ev:event="xforms-value-changed">
                    <xf:action if="instance('i-dateTime')/*:endTime =''">
                        <xf:setvalue ref="instance('i-dateTime')/*:endTime" value="'17:00:00'"/>
                    </xf:action>
                    <xf:setvalue ref="instance('i-leave')//*:period/*:end/@value"
                        value="concat(instance('i-dateTime')/*:enddate,'T',instance('i-dateTime')/*:endTime)"/>
                </xf:action>
            </xf:select1>
            <br/>
            <xf:textarea class="fullarea" ref="./description/@value">
                <xf:label id="evt-note" class="svListHeader">Notiz:</xf:label>
            </xf:textarea>
            <xf:output id="evt-status" ref="./status/coding/display/@value">
                <xf:label class="svListHeader">Status:</xf:label>
            </xf:output>
        </xf:group>
    </xf:group>
};