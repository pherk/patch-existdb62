xquery version "3.0";
module namespace comm = "http://enahar.org/exist/apps/nabu/communication";

import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"      
                    at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
import module namespace r-comm = "http://enahar.org/exist/restxq/nabu/communications" at "/db/apps/nabu/FHIR/Communication/communication-routes.xqm";
import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients"    at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";


declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";


(:~
 : show communication functionality for dashboard
 : 
 : @param $uid user id
 : @return html
 :)
declare function comm:showFunctions()
{
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $realm := "kikl-spzn"
    let $cs := r-comm:communicationsXML($realm, $uid, $unam, "1", "*", $uid, "", "", "", 'in-progress', "count")
    return
    <ul>
        <li>
            <a href="index.html?action=showComms">Druckliste({$cs/*:count/string()})</a>
        </li>
    </ul>
};

(:~
 : presents table with User Account
 : 
 : @return html 
 :)
declare function comm:showComms($filter)
{
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $realm   := 'metis/organizations/kikl-spzn'
    
    let $start := '2015-01-01T08:00:00'
    let $end   := '2026-04-01T08:00:00'
    return
(
<div style="display=none;">
    <xf:model id="m-comms">
        <xf:instance xmlns="" id="i-comms">
            <data/>
        </xf:instance>
        
        <xf:submission id="s-get-comms"
        			instance="i-comms"
					method="get"
				    replace="instance">
			<xf:resource value="concat('/exist/restxq/nabu/communications?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;sender=',bf:instanceOfModel('m-comms','i-control-center')/*:sender-uid,'&amp;subject=',bf:instanceOfModel('m-comms','i-control-center')/*:subject-uid)"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Comms loaded</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get comms</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-comm"
        			ref="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]"
					method="put"
				    replace="none">
			<xf:resource value="concat('/exist/restxq/nabu/communications?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Communication submitted</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit comm</xf:message>
        </xf:submission>        
        <xf:submission id="s-get-raw"
                method="get"
                replace="embedHTML"
                targetid="letterpane">
            <xf:resource value="concat('/exist/restxq/nabu/communications/',instance('i-control-center')/*:docid,'/payload')"/>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue 
                    ref="instance('i-control-center')/*:info/*:p/*:hi" 
                    value="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:payload//*:div[@type='info']/*:p[@rend='bold']/*:hi"/>
            </xf:action>
        </xf:submission> 
        
        <xf:instance id="i-comm-infos" xmlns="" src="/exist/apps/nabu/FHIR/Communication/communication-infos.xml"/>
        
        <xf:instance id="i-login">
            <data  xmlns="">
                <loguid>{$uid}</loguid>
                <lognam>{$unam}</lognam>
                <realm>kikl-spzn</realm>
            </data>
        </xf:instance>
        
        <xf:instance id="i-control-center">
            <data  xmlns="">
                <doctype>info</doctype>
                <docid/>
                <sender-uid>{$uid}</sender-uid>
                <subject-uid></subject-uid>
                <status>in-progress</status>
                <info><p xmlns="http://www.tei-c.org/ns/1.0" rend="bold"><hi rend="bold"></hi></p></info>
                <dirty>false</dirty>
            </data>
        </xf:instance>
        
        <xf:instance id="views">
            <data  xmlns="">
                <CommShown/>
                <CommInfo/>
            </data>
        </xf:instance>    
        <xf:bind id="commShown" ref="instance('views')/*:CommShown"
                relevant="instance('i-control-center')/*:docid != ''"/>
        <xf:bind id="commInfo" ref="instance('views')/*:CommInfo"
                relevant="instance('i-control-center')/*:docid != ''"/> 
                <!-- and instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:reasonCode/*:coding/*:code/@value = 'info'"/>
                 -->
        <xf:action ev:event="reload-infopane">
            <xf:load show="none" targetid="letterpane"></xf:load>
            <xf:setvalue ref="instance('i-control-center')/*:docid" value="instance('i-comms')/*:Communication[index('r-comms-id')]/*:id/@value"/>
            <xf:setvalue ref="instance('i-control-center')/*:info/*:p/*:hi" value="''"/>
            <xf:setvalue ref="instance('i-control-center')/*:dirty" value="'false'"/>
            <xf:send submission="s-get-raw"/>
        </xf:action>
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-comms"/>
        </xf:action>
        <xf:action ev:event="xforms-ready">
            <xf:dispatch name="reload-infopane" targetid="m-comms"/>
        </xf:action>
    </xf:model>
</div>
,
<div id="xforms">
    <xf:group>
        <xf:label class="svListHeader">Druckjobs</xf:label>
        <xf:group ref="instance('i-comms')/*:Communication" class="svFullGroup">
            <xf:action ev:event="betterform-index-changed">
                <xf:dispatch name="reload-infopane" targetid="m-comms"/>
            </xf:action>
            <table>
                <tr>
                    <td rowspan="2">
                        <xf:repeat id="r-comms-id" ref="instance('i-comms')/*:Communication" class="svRepeat" appearance="compact">
                            <xf:output ref="./*:subject/*:display/@value">
                                <xf:label class="svRepeatHeader">Name des Patienten</xf:label>
                            </xf:output>
                        </xf:repeat>
                    </td>
                    <td>
                        <xf:trigger class="svUpdateMasterTrigger">
                            <xf:label>Abbrechen</xf:label>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref="instance('views')/*:CommShown" class="svDelTrigger">
                            <xf:label>Löschen</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue 
                                    ref="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:status/@value"
                                    value="'failed'"/>
                                <xf:send submission="s-submit-comm"/>
                                <xf:delete ref="instance('i-comms')/*:Communication" at="index('r-comms-id')"/>
                                <xf:dispatch name="reload-infopane" targetid="m-comms"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref="instance('views')/*:CommShown" class="svSaveTrigger">
                            <xf:label>ohne Drucken</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue 
                                    ref="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:status/@value"
                                    value="'completed'"/>
                                <xf:send submission="s-submit-comm"/>
                                <xf:delete ref="instance('i-comms')/*:Communication" at="index('r-comms-id')"/>
                                <xf:dispatch name="reload-infopane" targetid="m-comms"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                </tr>
                <tr>
                    <td>
                        <xf:trigger ref="instance('views')/*:CommShown" class="svSaveTrigger">
                            <xf:label>Drucken</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:message>Brief geht in die Druckqueue der Verwaltung</xf:message>
                                <xf:setvalue
                                    ref="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:status/@value"
                                    value="'printing'"/>
                                <xf:send submission="s-submit-comm"/>
                                <xf:delete ref="instance('i-comms')/*:Communication" at="index('r-comms-id')"/>
                                <xf:dispatch name="reload-infopane" targetid="m-comms"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                </tr>
                <tr>
                    <td colspan="3">
                        <br/>
                        <xf:group  ref="instance('views')/*:CommInfo" class="svFullGroup bordered">
                            <xf:label>Zusätzliches Briefinfo</xf:label>
                            <xf:switch>
                                <xf:case id="c-addinfo">
                                    <xf:trigger class="svAddTrigger">
                                        <xf:label>Einfügen</xf:label>
                                        <xf:action ev:event="DOMActivate">
                                            <xf:action if="count(instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:payload//*:div[@type='info']/*:p[@rend='bold']) = 0">
                                                <xf:insert
                                                    at="1" position="before"
                                                    nodeset="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:payload//*:div[@type='info']/*:p"
                                                    context="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:payload//*:div[@type='info']"
                                                    origin="instance('i-control-center')/*:info/*:p"/>
                                            </xf:action>
                                            <xf:toggle case="c-input"/>
                                        </xf:action>
                                    </xf:trigger>
                                </xf:case>
                                <xf:case id="c-input">
                                    <xf:textarea ref="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:payload//*:div[@type='info']/*:p[@rend='bold']/*:hi" class="bigarea" incremental="true">
                                    </xf:textarea>
                                    <xf:select1 ref="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:payload//*:div[@type='info']/*:p[@rend='bold']/*:hi" appearance="minimal" incremental="true">
                                        <xf:label class="svListHeader">Std.Text</xf:label>
                                        <xf:itemset ref="instance('i-comm-infos')/*:infobrief/*:text">
                                            <xf:label ref="./@label-de"/>
                                            <xf:value ref="./@value"/>
                                        </xf:itemset>
                                    </xf:select1>
                                </xf:case>
                            </xf:switch>
                        </xf:group>
                    </td>
                </tr>
                <tr>
                    <td colspan="3">
                        <br/>
                        <xf:group  ref="instance('views')/*:CommShown" class="svFullGroup bordered">
                            <xf:label>Interne Notiz</xf:label><br/>
                            <xf:textarea ref="instance('i-comms')/*:Communication[*:id/@value=instance('i-control-center')/*:docid]/*:note/@value" class="bigarea" incremental="true">
                            </xf:textarea>
                        </xf:group>
                    </td>
                </tr>
                <tr>
                    <td colspan="3">
                        <xf:group id="letterpane">
                        </xf:group>
                    </td>
                </tr>
            </table>
        </xf:group>
    </xf:group>
</div>
)
};

(:~
 : presents table with User Account
 : 
 : @return html 
 :)
declare function comm:listComms($filter)
{
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $realm   := 'metis/organizations/kikl-spzn'
    
    let $start := '2015-01-01T08:00:00'
    let $end   := '2026-04-01T08:00:00'

    let $comms := r-comm:communicationsXML($realm, $uid, $unam, "1","*", "", $start, $end, "", "printing", "full")
    return
        if ($perms = 'perm_printing')
        then
        <div><h2>Druckjobs <span>({$comms/count/string()})</span></h2>
            <table id="comms" class="tablesorter">
                <thead>
                    <tr id="0">
                        <th>Patient</th>
                        <th>Datum</th>
                        <th>Art</th>
                    </tr>
                </thead>
                <tbody>{ comm:commsToRows($comms) }</tbody>
                <script type="text/javascript" defer="defer" src="FHIR/Communication/listComms.js"/>
            </table>
            <h4>Was möchten Sie tun?</h4>
            <ul>
                <li><a href="{concat('/exist/restxq/nabu/communications2pdf'
                                , '?rangeStart=',$start
                                , '&amp;rangeEnd=',$end
                                , '&amp;status=printing'
                                , '&amp;printed=true')}">Alle offenen Briefe drucken!</a></li>
            </ul>
        </div>
        else
            <div><h4>Sie haben keine Lizenz zum Drucken der Briefe.</h4></div>
};

declare %private function comm:commsToRows($comms)
{
    for $l in $comms/fhir:Communication
    let $lid := $l/fhir:id/@value/string()
    let $remind := if ($l/fhir:status/@value='enroll')
        then 'remind'
        else ''
    return
         <tr id="{$lid}" class="{$remind}">
            <td>{$l/fhir:subject/fhir:display/@value/string()}</td>
            <td>{$l/fhir:sent/@value/string()}</td> 
            <td>{$l/fhir:reasonCode//fhir:display/@value/string()}</td>
         </tr> 
};


