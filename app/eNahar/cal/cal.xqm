xquery version "3.0";

module namespace cal = "http://enahar.org/exist/apps/enahar/edit";

import module namespace config  = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";

import module namespace ical    = "http://enahar.org/lib/ical";
import module namespace r-ical  = "http://enahar.org/exist/restxq/enahar/icals"  at "../cal/cal-routes.xqm";
import module namespace sched   = "http://enahar.org/exist/apps/enahar/schedule" at "../schedule/schedule.xqm";
import module namespace sched-util   = "http://enahar.org/exist/apps/eNahar/sched-util" at "../schedule/sched-util.xqm";

import module namespace r-practrole  = "http://enahar.org/exist/restxq/metis/practrole"   
                           at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

declare variable $cal:restxq-icals     := "/exist/restxq/enahar/icals";


declare variable $cal:calendars     := "/exist/apps/eNaharData/data/calendars";
declare variable $cal:cal-infos-uri             := "cal/cal-infos.xml";

declare function cal:edit($what as xs:string)
{
    if ($what=("service", "worktime"))
    then cal:user-schedules($what)
    else if ($what='meeting')
    then cal:user-meetings()
    else ()
};

declare function cal:user-schedules($what as xs:string)
{
    let $logu   := r-practrole:userByAlias(xmldb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $realm := 'kikl-spzn'
    let $header := switch($what)
        case "service" return "Sprechstunden"
        case "meeting" return "Meetings"
        case "worktime" return "Arbeitszeiten"
        default return "Schedules"
    return
(<div style="display:none;">
    <xf:model id="mcals">
        <xf:instance id="i-cals">
            <data xmlns=""/>
        </xf:instance>
        
        <xf:bind ref="instance('i-cals')/cal[1]/schedule/agenda">        
            <xf:bind ref="./period/start/@value"   type="xs:dateTime" />
            <xf:bind ref="./period/end/@value"     type="xs:dateTime" />
        </xf:bind>
        <xf:bind ref="instance('i-cals')/cal[1]/schedule/global">        
            <xf:bind ref="./isSpecial/@value"   type="xs:boolean" />
            <xf:bind ref="./ff/@value"     type="xs:boolean" />
        </xf:bind>
        <xf:bind ref="instance('i-cals')/cal[1]/schedule/agenda/event">     
            <xf:bind ref="./name/@value"        type="xs:string" required="true()"/>
            <xf:bind ref="./start/@value"       type="xs:time" required="true()"/>
            <xf:bind ref="./end/@value"         type="xs:time" required="true()"/>

            <xf:bind ref="./rdate/date/@value"  type="xs:date"/>
            <xf:bind ref="./rrule/byWeekNo/@value"  constraint=".=('','even','odd') or '[0-9,]*'"/>
        </xf:bind>
      
        <xf:submission id="s-get-ical"
                method="get"
                instance="i-cals" 
                replace="instance">
            <xf:resource value="concat('/exist/restxq/enahar/icals?owner=',instance('i-search')/*:owner,'&amp;realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
            <xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:action if="count(instance('i-cals')/*:cal) = 0">
                    <xf:insert
                            ref="instance('i-cals')/*:cal"
                            context="instance('i-cals')"
                            origin="instance('i-calInfos')/*:bricks/*:cal"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:id/@value" 
                            value="concat('cal-', instance('i-search')/*:owner)"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:owner/*:reference/@value" 
                            value="concat('metis/practitioners/',instance('i-search')/*:owner)"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:owner/*:display/@value" 
                            value="instance('i-search')/*:owner-display"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:summary/@value" 
                            value="instance('i-search')/*:owner-display"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:owner/*:group/@value" 
                            value="instance('i-search')/*:service"/>
                    <xf:message level="ephemeral">neuer Kalender: <xf:output ref="instance('i-search')/*:owner-display"/></xf:message>   
                </xf:action>
                <xf:setindex index="count(instance('i-cals')/*:cal/*:schedule[*:global/*:type/@value='{$what}'])" repeat="r-scheds-id"/>
            </xf:action>
            <xf:action ev:event="xforms-submit-error">
                <xf:message level="modal">No calendar? Error!</xf:message>
            </xf:action>
        </xf:submission>        
        <xf:submission id="s-submit-ical"
                				   ref="instance('i-cals')/cal"
								   method="put"
								   replace="none">
			<xf:resource value="concat('{$cal:restxq-icals}?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('control-instance')/*:dirty" value="'false'"/>
                <xf:message level="ephemeral">ical submitted</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit ical! Validation error?</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>15</length>
                <owner></owner>
                <owner-display></owner-display>
                <service></service>
            </parameters>
        </xf:instance>

        <xf:instance id="control-instance">
            <control xmlns="">
                <dirty>false</dirty>
                <save-trigger/>
                <has-calendar/>
                <delete-schedule-trigger/>
                <delete-agenda-trigger/>
                <delete-event-trigger/>  
                <delete-rdate-trigger/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('control-instance')/*:save-trigger" relevant="instance('control-instance')/*:dirty = 'true'"/>
        <xf:bind nodeset="instance('control-instance')/has-calendar"
                relevant="instance('i-cals')/*:cal[1]/*:owner/*:reference/@value ne ''"/>
        <xf:bind nodeset="instance('control-instance')/delete-schedule-trigger"
                relevant="count(instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}']) &gt; 0"/>

        <xf:bind nodeset="instance('control-instance')/delete-agenda-trigger" 
                relevant="count(instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda) &gt; 0"/>
        <xf:bind nodeset="instance('control-instance')/delete-event-trigger"
                relevant="count(instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]/event) &gt; 0"/>
        <xf:bind nodeset="instance('control-instance')/delete-rdate-trigger"
                relevant="count(instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]/event[index('r-event-ids')]/rdate/date/@value) &gt; 0"/>
                            
        <xf:instance id="i-schedules" xmlns="">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-schedules"
                				   ref="instance('i-schedules')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat('{$sched:restxq-schedules}?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">schedules loaded</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load schedules! Server error!</xf:message>
        </xf:submission>

        <xf:instance id="i-calInfos" xmlns="" src="cal/cal-infos.xml"/>
        
        <xf:instance id="tabset-instance" xmlns="">
                <tabset value="create">
                    <item value="t-overview">Überblick</item>
                    <item value="t-agendas">Agendas</item>
                    <item value="t-events">Termine</item>
                </tabset>
        </xf:instance>
        
        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-schedules"/>
        </xf:action>        
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
    <xf:input id="owner-uid"     ref="instance('i-search')/*:owner"/>
    <xf:input id="owner-display" ref="instance('i-search')/*:owner-display">
        <xf:action ev:event="xforms-value-changed">
            <xf:send submission="s-get-ical"/>
        </xf:action>
    </xf:input>
    <xf:input id="service"       ref="instance('i-search')/*:service"/>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <table>
        <tr>
            <th>Service</th>
            <th>Erbringer</th>
        </tr>
        <tr>
            <td>
                <select class="caladmin-select" name="service-hack">
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="../eNahar/cal/cal-service.js"/>
            </td>
            <td>
                <select class="caladmin-select" name="owner-hack">
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="../eNahar/cal/cal-owner.js"/>
            </td>
            <td>
                <xf:group ref="instance('control-instance')/*:save-trigger" class="svFullGroup">
                    <xf:trigger id="save-schedule" class="svSaveTrigger">
                        <xf:label>Save</xf:label>
                        <xf:hint>This button will save ical.</xf:hint>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-submit-ical"/>
                        </xf:action>
                    </xf:trigger>
                </xf:group>
            </td>
        </tr>
    </table>
    <hr/>

    <xf:group ref="instance('control-instance')/has-calendar" class="tabframe">
        <div class="tabs">
        <xf:repeat nodeset="instance('tabset-instance')/item" id="tab-item-repeat">
            <xf:trigger ref="." appearance="minimal"> 
                <xf:label><xf:output ref="."/></xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('tabset-instance')/@value" 
                    value="instance('tabset-instance')/item[index('tab-item-repeat')]"/>
                    <xf:toggle ref=".">
                        <xf:case value="@value"/>
                    </xf:toggle>
                </xf:action>
            </xf:trigger>
        </xf:repeat>
        </div>
        <div class="tabpane-large">
        <xf:switch>
        <xf:case id="t-overview" selected="true">
            {cal:overview($header, $what)}
        </xf:case>
        <xf:case id="t-agendas">
            {cal:agendas($header, $what)}
        </xf:case>
        <xf:case id="t-events">
            {cal:events($header, $what)}
        </xf:case>
        </xf:switch>
        </div>
    </xf:group>
</div>
)
};

declare function cal:overview($header, $what)
{
<xf:group class="svFullGroup">
    <table>
        <tr>
            <td>
                <xf:group id="schedules"  ref="instance('i-cals')/cal[1]" class="svFullGroup bordered">
                    <xf:label>Liste der {$header}</xf:label>
                    <xf:repeat id="r-scheds-id" ref="./*:schedule[./*:global/*:type/@value='{$what}']" appearance="compact" class="svRepeat">
                        <xf:output ref="./global/display/@value">
                            <xf:label class="svListHeader">Title:</xf:label>
                        </xf:output>
                    </xf:repeat>
                </xf:group>
                <xf:group appearance="minimal" class="svTriggerGroup">
                <table>
                    <tr>
                        <td>
                            <xf:trigger class="svAddTrigger" >
                                <xf:label>Neu</xf:label>
                                <xf:action ev:event="DOMActivate">
                                    <xf:insert position="after"
                                        nodeset="instance('i-cals')/*:cal[1]/*:schedule[./*:global/*:type/@value='{$what}']"
                                        context="instance('i-cals')/*:cal[1]"
                                        origin="instance('i-calInfos')/*:bricks/*:schedule"/>
                                    <xf:setvalue
                                        ref="instance('i-cals')/*:cal[1]/*:schedule[./*:global/*:type/@value='']/*:global/*:type/@value"
                                        value="'{$what}'"/>
                                    <xf:setvalue
                                        ref="instance('i-cals')/*:cal[1]/*:schedule[./*:global/*:type/@value='{$what}'][last()]/*:global/*:display/@value"
                                        value="'???'"/>
                                </xf:action>
                            </xf:trigger>
                        </td>
                        <td>
                            <xf:trigger   ref="instance('control-instance')/delete-schedule-trigger" class="svDelTrigger">
                                <xf:label>Entfernen</xf:label>
                                <xf:delete ev:event="DOMActivate" nodeset="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}']" at="index('r-scheds-id')"/>
                                <xf:setvalue ref="instance('control-instance')/*:dirty" value="'true'"/>
                            </xf:trigger>
                        </td>
                    </tr>
                </table>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-cals')/*:cal[1]/*:schedule[./*:global/*:type/@value='{$what}'][index('r-scheds-id')]"
                        class="svFullGroup bordered">
                    <xf:label>Referenzkalender festlegen</xf:label><br/>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('control-instance')/*:dirty" value="'true'"/>
                        <xf:setvalue ref="./*:global/*:display/@value" value="instance('i-schedules')/*:schedule[./*:identifier/*:value/@value=instance('i-cals')/*:cal[1]/*:schedule[./*:global/*:type/@value='{$what}'][index('r-scheds-id')]/*:global/*:reference/@value]/*:name/@value"/>
                    </xf:action>
                    <xf:select1 id="sched-id" ref="./global/*:reference/@value">
                        <xf:label>Auswahl:</xf:label><br/>
                        <xf:itemset nodeset="instance('i-schedules')/*:schedule[./*:type/@value='{$what}']">
                            <xf:label ref="./*:name/@value"/>
                            <xf:value ref="./*:identifier/*:value/@value"/>
                        </xf:itemset>
                        <xf:alert>a string is required</xf:alert>
                    </xf:select1>
                </xf:group>
                { cal:details($what) }
            </td>
        </tr>
    </table>
</xf:group>
};

declare %private function cal:details($what)
{
    <xf:group ref="instance('i-cals')/cal[1]">
        <xf:action ev:event="xforms-value-changed">
            <xf:setvalue ref="instance('control-instance')/*:dirty" value="'true'"/>
        </xf:action>
        <table>
            <tr>
                <td>
                    <strong>LastModifiedBy</strong>
                </td>
                <td>
                    <xf:output ref="./*:lastModifiedBy/*:display/@value"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>LastModified</strong>
                </td>
                <td>
                    <xf:output ref="./*:lastModified/@value"/>
                </td>
            </tr>            
            <tr>
                <td>
                    <strong>Owner</strong>
                </td>
                <td>
                    <xf:output ref="./*:owner/*:display/@value"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Summary</strong>
                </td>
                <td>
                    <xf:output ref="./*:summary/@value"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Decription</strong>
                </td>
                <td>
                    <xf:output ref="./*:description/@value"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Active</strong>
                </td>
                <td>
                    <xf:output ref="./*:active/@value"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>CUType</strong>
                </td>
                <td>
                    <xf:output ref="./*:cutype/*:text/@value"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>CalType</strong>
                </td>
                <td>
                    <xf:output ref="./*:caltype/*:text/@value"/>
                </td>
            </tr>  
            <tr>
                <td>
                    <strong>Location</strong>
                </td>
                <td>
                    <xf:output ref="./*:location/*:display/@value"/>
                </td>
            </tr> 
            <tr>
                <td>
                    <strong>TimeZone</strong>
                </td>
                <td>
                    <xf:output ref="./*:timezone/@value"/>
                </td>
            </tr>
            <tr>
                <td><strong>Ausgewählte Ambulanz</strong></td><td>-------------------------------------------</td>
            </tr>
            <tr>
                <td>
                    <strong>Spezialambulanz</strong>
                </td>
                <td>
                    <xf:input ref="./schedule[global/type/@value='{$what}'][index('r-scheds-id')]/*:global/*:isSpecial/@value"/>
                </td>
            </tr> 
            <tr>
                <td>
                    <strong>Fallführung</strong>
                </td>
                <td>
                    <xf:input ref="./schedule[global/type/@value='{$what}'][index('r-scheds-id')]/*:global/*:ff/@value"/>
                </td>
            </tr> 
        </table>
    </xf:group>
};

declare function cal:agendas($header as xs:string, $what)
{
<xf:group class="svFullGroup">
    <table>
        <tr>
            <td>
                <xf:group id="agendas"  ref="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]" class="svFullGroup bordered">
                    <xf:label><xf:output ref="./global/display/@value"/></xf:label>
                    <xf:group id="agendalist" class="svFullGroup">
                        <xf:repeat id="r-agendas-id" nodeset="./agenda" appearance="compact" class="svRepeat">
                        <xf:output value="choose(period/start/@value='', '&lt;---',tokenize(./period/start/@value,'T')[1])">
                            <xf:label class="svListHeader">Von:</xf:label>
                        </xf:output>
                        <xf:output value="choose(period/end/@value='', '---&gt;',tokenize(./period/end/@value,'T')[1])">
                            <xf:label class="svListHeader">Bis:</xf:label>
                        </xf:output>
                        </xf:repeat>
                    </xf:group>
                    <xf:group appearance="minimal" class="svTriggerGroup">
                    <table>
                    <tr>
                        <td>
                            <xf:trigger class="svAddTrigger" >
                                <xf:label>Neu</xf:label>
                                <xf:action ev:event="DOMActivate">
                                    <xf:insert position="after" at="index('r-agendas-id')"
                                        nodeset="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda"
                                        context="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]"
                                        origin="instance('i-calInfos')/bricks/agenda"/>
                                </xf:action>
                            </xf:trigger>
                        </td>
                        <td>
                            <xf:trigger class="svAddTrigger" ref="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda">
                                <xf:label>Clone</xf:label>
                                <xf:action ev:event="DOMActivate">
                                    <xf:insert position="after" at="index('r-agendas-id')"
                                        nodeset="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda"
                                        origin="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]"/>
                                </xf:action>
                            </xf:trigger>
                        </td>
                        <td>
                            <xf:trigger  ref="instance('control-instance')/delete-agenda-trigger" class="svDelTrigger">
                                <xf:label>Entfernen</xf:label>
                                    <xf:delete ev:event="DOMActivate" 
                                        nodeset="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda"
                                        at="index('r-agendas-id')"/>
                                    <xf:setvalue ref="instance('control-instance')/*:dirty" value="'true'"/>
                            </xf:trigger>
                        </td>
                    </tr>
                    </table>
                    </xf:group>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]" class="svFullGroup bordered">
                    <xf:label>Gültigkeit</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('control-instance')/*:dirty" value="'true'"/>
                    </xf:action>
                    <xf:group class="svFullGroup">
                        <xf:input id="agd-start" ref="./period/start/@value">
                            <xf:label>Von:</xf:label>
                            <xf:alert>a valid date is required</xf:alert>
                        </xf:input><br/>
                        <xf:input id="agd-end" ref="./period/end/@value">
                            <xf:label>Bis:</xf:label>
                            <xf:alert>a valid date is required</xf:alert>
                        </xf:input>
                    </xf:group>
                </xf:group>
            </td>
        </tr>
    </table>
</xf:group>
};


declare function cal:events($header as xs:string, $what)
{
<xf:group class="svFullGroup">
    <table>
        <tr>
            <td>
                <xf:group id="events" ref="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]" class="svFullGroup bordered">
                    <xf:label><xf:output ref="./global/display/@value"/></xf:label>
                    <xf:repeat id="r-event-ids" nodeset="./agenda[index('r-agendas-id')]/event" appearance="compact" class="svRepeat">
                        <xf:output ref="./name/@value">
                            <xf:label class="svListHeader">Name:</xf:label>
                        </xf:output>
                    </xf:repeat>
                    <xf:group appearance="minimal" class="svTriggerGroup">
                        <table>
                            <tr>
                            <td>
                                <xf:trigger class="svAddTrigger" >
                                    <xf:label>Neu</xf:label>
                                    <xf:action ev:event="DOMActivate">
                                        <xf:insert position="after" at="index('r-event-ids')"
                                            nodeset="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]/event"
                                            context="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]"
                                            origin="instance('i-calInfos')/bricks/event"/>
                                <!--
                                        <xf:setvalue 
                                            ref="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]/event[index('r-event-ids')+1]"
                                            value="current-dateTime()"/>
                                -->
                                    </xf:action>
                                </xf:trigger>
                            </td>
                            <td>
                                <xf:trigger  ref="instance('control-instance')/delete-event-trigger" class="svDelTrigger">
                                    <xf:label>Entfernen</xf:label>
                                    <xf:delete ev:event="DOMActivate" 
                                        nodeset="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]/event"
                                        at="index('r-event-ids')"/>
                                    <xf:setvalue ref="instance('control-instance')/*:dirty" value="'true'"/>
                                </xf:trigger>
                            </td>
                            </tr>
                        </table>
                    </xf:group>
                </xf:group>
            </td>
            <td>
                <xf:group  ref="instance('i-cals')/cal[1]/schedule[global/type/@value='{$what}'][index('r-scheds-id')]/agenda[index('r-agendas-id')]/event[index('r-event-ids')]"
                        class="svFullGroup bordered">
                    <xf:label>Sprechstundenzeiten</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('control-instance')/*:dirty" value="'true'"/>
                    </xf:action>
                    <xf:group class="svFullGroup">
                        <xf:input ref="./name/@value" class="medium-input">
                            <xf:label class="svListHeader">Name:</xf:label>
                        </xf:input><br/>
                        <xf:input id="evt-start" ref="./start/@value" appearance="bf:time" class="medium-input">
                            <xf:label class="svListHeader" >Von:</xf:label>
                            <xf:alert>a valid time is required</xf:alert>
                        </xf:input>
                        <xf:input id="evt-end" ref="./end/@value" appearance="bf:time" class="medium-input">
                            <xf:label  class="svListHeader">Bis:</xf:label>
                            <xf:alert>a valid time is required</xf:alert>
                        </xf:input>
                        <xf:textarea class="fullareashort" ref="./note">
                            <xf:label id="evt-note" class="svListHeader">Hinweise:</xf:label>
                        </xf:textarea>
                    </xf:group>
                    { sched-util:rrules() }
                    { sched-util:rdates() }
                    { sched-util:exdates() }
                    { sched-util:trigger()}
                    { sched-util:help()}
                </xf:group>
            </td>
        </tr>
    </table>
</xf:group>
};


declare function cal:user-meetings()
{
    let $logu   := r-practrole:userByAlias(xmldb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $realm := 'kikl-spzn'
    let $header := "Meetings"
    return
(<div style="display:none;">
    <xf:model id="mcals">
        <xf:instance id="i-cals">
            <data xmlns=""/>
        </xf:instance>
        
        <xf:submission id="s-get-ical"
                method="get" 
                instance="i-cals" 
                replace="instance">
            <xf:resource value="concat('/exist/restxq/enahar/icals?owner=',instance('i-search')/*:owner,'&amp;realm={$realm}&amp;loguid={$uid}&amp;lognam={$unam}')"/>
            <xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:action if="count(instance('i-cals')/*:cal) = 0">
                    <xf:message level="ephemeral">init</xf:message>    
                    <xf:insert
                            ref="instance('i-cals')/*:cal"
                            context="instance('i-cals')"
                            origin="instance('i-calInfos')/*:bricks/*:cal"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:id/@value" 
                            value="concat('cal-', instance('i-search')/*:owner)"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:owner/*:reference/@value" 
                            value="concat('metis/practitioners/',instance('i-search')/*:owner)"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:owner/*:display/@value" 
                            value="instance('i-search')/*:owner-display"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:summary/@value" 
                            value="instance('i-search')/*:owner-display"/>
                    <xf:setvalue ref="instance('i-cals')/*:cal/*:owner/*:group/@value" 
                            value="instance('i-search')/*:service"/>
                    <xf:message level="ephemeral">neuer Kalender: <xf:output ref="instance()/*:owner-display"/></xf:message>   
                </xf:action>
                <xf:setindex index="count(instance('i-cals')/cal/schedule[global/type/@value='meeting'])" repeat="r-scheds-id"/>
            </xf:action>
            <xf:action ev:event="xforms-submit-error">
                <xf:message level="modal">No calendar? Error!</xf:message>
            </xf:action>
        </xf:submission>        
        <xf:submission id="s-submit-ical"
                				   ref="instance('i-cals')/cal[1]"
								   method="put"
								   replace="none">
			<xf:resource value="'{$cal:restxq-icals}?realm={$realm}&amp;loguid={$uid}&amp;lognam={$unam}'"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('control-instance')/*:dirty" value="'false'"/>
                <xf:message level="ephemeral">ical submitted</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit ical! Validation? error?</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>15</length>
                <owner></owner>
                <owner-display></owner-display>
                <service></service>
            </parameters>
        </xf:instance>

        <xf:instance id="control-instance">
            <control xmlns="">
                <dirty>false</dirty>
                <save-trigger/>
                <has-calendar/>
                <delete-schedule-trigger/>
            </control>
        </xf:instance>
        <xf:bind nodeset="instance('control-instance')/*:save-trigger" relevant="instance('control-instance')/*:dirty = 'true'"/>
        <xf:bind nodeset="instance('control-instance')/*:delete-schedule-trigger"
                relevant="count(instance('i-cals')/*:cal[1]/*:schedule[*:global/*:type/@value='meeting']) &gt; 0"/>
        <xf:bind nodeset="instance('control-instance')/*:has-calendar"
                relevant="instance('i-cals')/*:cal[1]/*:owner/*:reference/@value ne ''"/>

        <xf:instance id="i-schedules" xmlns="">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-schedules"
                				   ref="instance('i-schedules')"
								   method="get"
								   replace="instance">
			<xf:resource value="'{$sched:restxq-schedules}?realm={$realm}&amp;loguid={$uid}&amp;lognam={$unam}'"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">schedules loaded</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load schedules! Program error!</xf:message>
        </xf:submission>

        <xf:instance id="i-calInfos" xmlns="" src="cal/cal-infos.xml"/>
    
        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-schedules"/>
        </xf:action>        
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
    <xf:input id="owner-uid"     ref="instance('i-search')/*:owner"/>
    <xf:input id="owner-display" ref="instance('i-search')/*:owner-display">
        <xf:action ev:event="xforms-value-changed">
            <xf:send submission="s-get-ical"/>
        </xf:action>
    </xf:input>
    <xf:input id="service"       ref="instance('i-search')/*:service"/>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <table>
        <tr>
            <th>Service</th>
            <th>Erbringer</th>
        </tr>
        <tr>
            <td>
                <select class="caladmin-select" name="service-hack">
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="../eNahar/cal/cal-service.js"/>
            </td>
            <td>
                <select class="caladmin-select" name="owner-hack">
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="../eNahar/cal/cal-owner.js"/>
            </td>
            <td>
                <xf:group ref="instance('control-instance')/*:save-trigger" class="svFullGroup">
                    <xf:trigger id="save-schedule" class="svSaveTrigger">
                        <xf:label>Save</xf:label>
                        <xf:hint>This button will save ical.</xf:hint>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-submit-ical"/>
                        </xf:action>
                    </xf:trigger>
                </xf:group>
            </td>
        </tr>
    </table>
    <hr/>

    <xf:group ref="instance('control-instance')/has-calendar" class="tabframe">
        {cal:overview($header,'meeting')}
    </xf:group>
</div>
)
};




