xquery version "3.0";

module namespace sched = "http://enahar.org/exist/apps/enahar/schedule";

import module namespace config  = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";
import module namespace sched-util  = "http://enahar.org/exist/apps/eNahar/sched-util"   at "/db/apps/eNahar/schedule/sched-util.xqm";

import module namespace r-practrole  = "http://enahar.org/exist/restxq/metis/practrole"   
                         at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

declare variable $sched:restxq-schedules     := "/exist/restxq/enahar/schedules";


declare function sched:schedules($what)
{
    let $logu   := sm:id()//sm:real/sm:username/string()
    let $user   := r-practrole:userByAlias($logu)
    let $prid := $user/fhir:id/@value/string()
    let $uref := $user/fhir:practitioner/fhir:reference/string()
    let $uid  := substring-after($uref, 'metis/practitioners/')
    let $unam := $user/fhir:practitioner/fhir:display/string()
    let $realm  := 'kikl-spzn'
    let $header := switch($what)
        case 'service' return "Sprechstunden im nSPZ"
        case 'meeting' return "Meetings im nSPZ"
        default return "Error"
    let $today := concat(substring-before(xs:string(current-dateTime()),'T'),'T00:00:00')
    return
(
<div style="display:none;">
    <xf:model id="m-schedules">
        <xf:instance xmlns="" id="i-schedules">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-schedules"
                				   ref="instance('i-schedules')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat('/exist/restxq/enahar/schedules?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;type=','{$what}')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">schedules loaded</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load schedules! Program error!</xf:message>
        </xf:submission>

        <xf:submission id="s-submit-schedule"
                				   ref="instance('i-schedules')/*:schedule[index('r-schedules-id')]"
								   method="put"
								   replace="none">
			<xf:resource value="concat('/exist/restxq/enahar/schedules?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('i-control-center')/*:dirty" value="'false'"/>
                <xf:message level="ephemeral">schedules submitted</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit schedules! Program error!</xf:message>
        </xf:submission>
        <xf:bind ref="instance('i-schedules')/*:schedule/*:fc/*:editable/@value" type="xs:boolean"/>
        <xf:bind ref="instance('i-schedules')/*:schedule/*:ff/@value" type="xs:boolean"/>
        <xf:bind ref="instance('i-schedules')/*:schedule/*:isSpecial/@value" type="xs:boolean"/>
        <xf:bind ref="instance('i-schedules')/*:schedule/*:timing/*:overbookable/@value" type="xs:boolean"/>
        
        <xf:instance id="i-subscribers">
            <data xmlns=""/>
        </xf:instance>
        <xf:submission id="s-get-subscribers"
                				   ref="instance('i-subscribers')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat('/exist/restxq/enahar/subscribers?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;schedule=',encode-for-uri(instance('i-schedules')/schedule[index('r-schedules-id')]/*:id/@value))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('i-search')/*:owner" value="''"/>
                <xf:setvalue ref="instance('i-search')/*:owner-display" value="''"/>
                <xf:message level="ephemeral">subscribers loaded</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get subscribers!</xf:message>
        </xf:submission>        
        <xf:submission id="s-add-subscription"
								   method="post"
								   replace="none">
			<xf:resource value="concat('/exist/restxq/enahar/icals/',instance('i-search')/*:owner,'/schedules?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;sid=',encode-for-uri(instance('i-schedules')/schedule[index('r-schedules-id')]/*:id/@value),'&amp;name=',encode-for-uri(instance('i-schedules')/schedule[index('r-schedules-id')]/*:name/@value),'&amp;type=',encode-for-uri(instance('i-schedules')/schedule[index('r-schedules-id')]/*:type/@value),'&amp;action=add')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:send submission="s-get-subscribers"/>
        <script type="text/javascript">
            console.log('clear filter');
            $('.task-select[name="owner-hack"]').val('').trigger('change');
        </script>
                <xf:message level="ephemeral">subscriber added</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot add subscriber!</xf:message>
        </xf:submission>
        <xf:submission id="s-del-subscription"
                				   method="post"
								   replace="none">
			<xf:resource value="concat('/exist/restxq/enahar/icals/',substring-after(instance('i-subscribers')/*:cal[index('r-subscribers-id')]/*:owner/*:reference/@value,'metis/practitioners/'),'/schedules?realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;sid=',encode-for-uri(instance('i-schedules')/schedule[index('r-schedules-id')]/*:id/@value),'&amp;action=delete')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:delete ref="instance('i-subscribers')/*:cal"/>
                <xf:message level="ephemeral">subscriber removed</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot remove subscriber!</xf:message>
        </xf:submission>
        
        <xf:instance id="i-locations">
            <data xmlns=""/>
        </xf:instance>
        <xf:submission id="s-get-locations"
                				   ref="instance('i-locations')"
								   method="get"
								   replace="instance">
			<xf:resource value="concat('/exist/restxq/metis/locations?_format=short&amp;realm=',encode-for-uri('{$realm}'),'&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;partOf=bu')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">locations loaded</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get locations!</xf:message>
        </xf:submission>         
        <xf:instance id="i-calInfos" xmlns="" src="cal/cal-infos.xml"/>
        <xf:instance id="i-scheduleInfos" xmlns="" src="schedule/schedule-infos.xml"/>

        <xf:instance id="i-control-center">
            <data xmlns="">
                <header>Agendas</header>
                <dirty>false</dirty>
                <save-trigger/>
                <delete-agenda-trigger/>
                <delete-event-trigger/>  
                <delete-rdate-trigger/>
            </data>
        </xf:instance>
        <xf:bind nodeset="instance('i-control-center')/*:save-trigger" relevant="instance('i-control-center')/*:dirty = 'true'"/>
        <xf:bind nodeset="instance('i-control-center')/delete-agenda-trigger" 
                relevant="count(instance('i-schedules')/schedule[index('r-schedules-id')]/agenda) &gt; 0"/>
        <xf:bind nodeset="instance('i-control-center')/delete-event-trigger"
                relevant="count(instance('i-schedules')/schedule[index('r-schedules-id')]/agenda[index('r-agendas-id')]/event) &gt; 0"/>
        <xf:bind nodeset="instance('i-control-center')/delete-rdate-trigger"
                relevant="count(instance('i-schedules')/schedule[index('r-schedules-id')]/agenda[index('r-agendas-id')]/event[index('r-events-id')]/rdate/date/@value) &gt; 0"/>

        <xf:instance id="i-search">
            <data xmlns="">
                <owner/>
                <owner-display/>
            </data>
        </xf:instance>
        
        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-schedules"/>
            <xf:send submission="s-get-locations"/>
        </xf:action>
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
    <xf:input id="owner-uid"     ref="instance('i-search')/*:owner"/>
    <xf:input id="owner-display" ref="instance('i-search')/*:owner-display">
        <xf:action ev:event="xforms-value-changed">
        </xf:action>
    </xf:input>
</div>
,
<xf:group id="xforms">
    <xf:action ev:event="newSchedule">
        <xf:insert
            nodeset="instance('i-schedules')/schedule"
            context="instance('i-schedules')"
            origin="instance('i-scheduleInfos')/*:bricks/schedule"/>
        <xf:setvalue ref="instance('i-schedules')/*:schedule[last()]/*:type/@value" value="'{$what}'"/>
    </xf:action>
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
            <td>
                <xf:trigger ref="instance('i-control-center')/*:dirty[.='true']" class="svSaveTrigger">
                    <xf:label>Save</xf:label>
                    <xf:hint>This button will save selected schedule.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-schedule"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svAddTrigger" >
                    <xf:label>Neu</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="newSchedule" targetid="xforms"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
        <tr>
            <td rowspan="4">
                <xf:group id="global-schedules"  ref="instance('i-schedules')" class="svFullGroup bordered">
                    <xf:action ev:event="betterform-index-changed">
                        <xf:action if="instance('i-control-center')/*:dirty='true'">
                            <xf:message level="modal">Achtung, Schedule saved?</xf:message>
                        </xf:action>
                        <xf:delete ref="instance('i-subscribers')/*:cal"/>
                        <xf:toggle case="t-agendas"/>
                    </xf:action>
                    <xf:label>Schedules</xf:label>
                    <xf:repeat id="r-schedules-id" nodeset="./*:schedule" appearance="compact" class="svRepeat">
                        <xf:output value="substring-before(./*:agenda[last()]/*:period/*:start/@value,'T')"/>
                        <xf:output value="substring-before(./*:agenda[last()]/*:period/*:end/@value,'T')"/>
                        <xf:output ref="./*:name/@value"/>
                    </xf:repeat>
                </xf:group>
            </td>
            <td colspan="3">
                <xf:group ref="instance('i-schedules')/schedule[index('r-schedules-id')]" class="svFullGroup bordered">
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-control-center')/*:dirty" value="'true'"/>
                    </xf:action>
                    <xf:label>Details:</xf:label>
                    <table>
                        <tr>
                            <td>
                                <strong>Name</strong>
                            </td>
                            <td>
                                <xf:input ref="./*:name/@value" class="long-input">
                                    <xf:alert>a string is required</xf:alert>
                                </xf:input>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <strong>Beschreibung</strong>
                            </td>
                            <td>
                    <xf:textarea ref="./*:description/@value" class="fullarea">
                        <xf:alert>a string is required</xf:alert>
                    </xf:textarea>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <strong>Ort</strong>
                            </td>
                            <td>
                                <xf:select1 ref="./*:location/*:reference/@value">
                                    <xf:itemset ref="instance('i-locations')/*:Location">
                                        <xf:label ref="./*:description/@value"/>
                                        <xf:value ref="./*:identifier/*:value/@value"/>
                                    </xf:itemset>
                                    <xf:action ev:event="xforms-value-changed">
                                        <xf:setvalue 
                                                ref="instance('i-schedules')/schedule[index('r-schedules-id')]/*:location/*:display/@value"
                                                value="instance('i-locations')/*:Location[*:identifier/*:value/@value=instance('i-schedules')/schedule[index('r-schedules-id')]/*:location/*:reference/@value]/*:name/@value"/>
                                        <xf:setvalue ref="instance('i-control-center')/*:dirty" value="'true'"/>
                                    </xf:action>
                                </xf:select1>
                            </td>
                        </tr>
                        <tr>
                            <td>
                            <xf:group ref="./*:type[@value='service']">
                                <strong>Fallführung</strong>
                            </xf:group>
                            </td>
                            <td>
                            <xf:group ref="./*:type[@value='service']">
                                <xf:input ref="./*:ff/@value">
                                    <xf:alert>a bool is required</xf:alert>
                                </xf:input>
                            </xf:group>
                            </td>
                        </tr>
                        <tr>
                            <td>
                            <xf:group ref="./*:type[@value='service']">
                                <strong>Specialambulanz</strong>
                            </xf:group>
                            </td>
                            <td>
                            <xf:group ref="./*:type[@value='service']">
                                <xf:input ref="./*:isSpecial/@value">
                                    <xf:alert>a bool is required</xf:alert>
                                </xf:input>
                            </xf:group>
                            </td>
                        </tr>
                        <tr>
                            <td>
                            <xf:group ref="./*:type[@value='service']">
                                <strong>Appletter</strong>
                            </xf:group>
                            </td>
                            <td>
                            <xf:group ref="./*:type[@value='service']">
                                <xf:input ref="./*:appletter/*:alt-name/@value" class="medium-input" >
                                    <xf:label class="svListHeader">Alt-Name:</xf:label>
                                    <xf:alert>a string is required</xf:alert>
                                </xf:input>
                            </xf:group>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <strong>Kalender</strong>
                            </td>
                            <td>
                        <xf:input ref="./*:fc/*:className/@value" class="medium-input" >
                            <xf:label class="svListHeader">CSS-Class:</xf:label>
                            <xf:alert>a string is required</xf:alert>
                        </xf:input>
                        <xf:input ref="./*:fc/*:backgroundColor/@value" class="short-input">
                            <xf:label class="svListHeader">Bkg/Text-Color</xf:label>
                            <xf:alert>a color is required</xf:alert>
                        </xf:input>
                        <xf:input ref="./*:fc/*:textColor/@value" class="short-input">
                            <xf:alert>a color is required</xf:alert>
                        </xf:input>
                        <xf:input ref="./*:fc/*:editable/@value">
                            <xf:label class="svListHeader">Editierbar?</xf:label>
                            <xf:alert>a bool is required</xf:alert>
                        </xf:input>
                            </td>
                        </tr>
                        <tr>
                            <td>
                            <xf:group ref="./*:type[@value='service']">
                                <strong>Timing</strong>
                            </xf:group>
                            </td>
                            <td>
                            <xf:group ref="./*:type[@value='service']">
                        <xf:input ref="./*:timing/*:pre/@value" class="tiny-input" >
                            <xf:label class="svListHeader">Pre/In/Post</xf:label>
                            <xf:alert>an int is required</xf:alert>
                        </xf:input>
                        <xf:input ref="./*:timing/*:exam/@value" class="tiny-input">
                            <xf:alert>an int is required</xf:alert>
                        </xf:input>
                        <xf:input ref="./*:timing/*:post/@value" class="tiny-input">
                            <xf:alert>an int is required</xf:alert>
                        </xf:input>
                        <xf:input ref="./*:timing/*:overbookable/@value">
                            <xf:label class="svListHeader">Overbookable?</xf:label>
                            <xf:alert>a bool is required</xf:alert>
                        </xf:input>
                        <xf:input ref="./*:timing/*:parallel-per-hour/@value" class="short-input">
                            <xf:label class="svListHeader">Parallel-Per-Hour</xf:label>
                            <xf:alert>a string is required</xf:alert>
                        </xf:input>
                        <xf:select1 ref="./*:timing/*:query/@value">
                            <xf:label class="svListHeader">Order</xf:label>
                            <xf:item>
                                <xf:label>pre</xf:label>
                                <xf:value>pre</xf:value> 
                            </xf:item>
                            <xf:item>
                                <xf:label>post</xf:label>
                                <xf:value>post</xf:value> 
                            </xf:item>
                        </xf:select1>
                        </xf:group>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <strong>Notiz:</strong>
                        </td>
                        <td>
                    <xf:textarea ref="./*:note/*:text/@value" class="fullarea">
                        <xf:alert>a string is required</xf:alert>
                    </xf:textarea>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <strong>Status</strong>
                        </td>
                        <td>
                            <xf:select1 ref="./*:status/@value">
                            <xf:item>
                                <xf:label>aktiv</xf:label>
                                <xf:value>active</xf:value> 
                            </xf:item>
                            <xf:item>
                                <xf:label>inaktiv</xf:label>
                                <xf:value>inactive</xf:value> 
                            </xf:item>
                            </xf:select1>
                        </td>
                    </tr>
                </table>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td colspan="3">
                <div class="btn-group" role="group">

                            <xf:trigger class="btn btn-secondary svSubTrigger">
                                <xf:label>Agendas</xf:label>
                                <xf:setvalue ref="instance('i-control-center')/*:header" value="'Agendas'"/>
                                <xf:toggle case="t-agendas" ev:event="DOMActivate"/>
                            </xf:trigger>
                            <xf:trigger class="btn btn-secondary svSubTrigger">
                                <xf:label>Events</xf:label>
                                <xf:setvalue ref="instance('i-control-center')/*:header" value="'Events'"/>
                                <xf:toggle case="t-events" ev:event="DOMActivate"/>
                            </xf:trigger>
                            <xf:trigger class="btn btn-secondary svSubTrigger">
                                <xf:label>Subscribers</xf:label>
                                <xf:setvalue ref="instance('i-control-center')/*:header" value="'Subscribers'"/>
                                <xf:send submission="s-get-subscribers"/>
                                <xf:toggle case="t-subscribers" ev:event="DOMActivate"/>
                            </xf:trigger>
                </div>
            </td>
        </tr>
        <tr>
            <td>
                    <strong><xf:output ref="instance('i-control-center')/*:header"/></strong>
            </td>
        </tr>
        <tr>
            <td colspan="3">
                <xf:switch>
                    <xf:case id="t-agendas">
                        { sched:agendas() }
                    </xf:case>
                    <xf:case id="t-events">
                        { sched:events() }
                    </xf:case>
                    <xf:case id="t-subscribers">
                        { sched:subscribers() }
                    </xf:case>
                </xf:switch>
            </td>
        </tr>
    </table>
</xf:group>
)
};

declare %private function sched:subscribers()
{
<xf:group ref="instance('i-subscribers')" class="svFullGroup bordered">
    <xf:action ev:event="xforms-value-changed">
    </xf:action>
    <table>
        <tr>
            <td rowspan="2">
                <xf:repeat id="r-subscribers-id" ref="./*:cal" appearance="compact" class="svRepeat">
                    <xf:output ref="./*:owner/*:display/@value"/>
                </xf:repeat>
            </td>
            <td>
                <xf:trigger  ref="./*:cal" class="svDelTrigger">
                    <xf:label>Entfernen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-del-subscription"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td>
                <script type="text/javascript" defer="defer" src="../eNahar/cal/cal-owner.js"/>
                <select class="caladmin-select" name="owner-hack">
                    <option></option>
                </select>
                <xf:trigger class="svAddTrigger" >
                    <xf:label>Add</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:action if="string-length(instance('i-search')/*:owner)=0">
                            <xf:message level="modal">nothing to add</xf:message>
                        </xf:action>
                        <xf:action if="string-length(instance('i-schedules')/schedule[index('r-schedules-id')]/*:id/@value)&gt;0 and string-length(instance('i-search')/*:owner)&gt;0">
                            <xf:send submission="s-add-subscription"/>
                        </xf:action>
                        <xf:action if="string-length(instance('i-schedules')/schedule[index('r-schedules-id')]/*:id/@value)=0">
                            <xf:message level="modal">save schedule before adding subscriber</xf:message>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</xf:group>
};

declare %private function sched:agendas()
{
<xf:group class="svFullGroup">
    <xf:action ev:event="xforms-value-changed">
        <xf:setvalue ref="instance('i-control-center')/*:dirty" value="'true'"/>
    </xf:action>
    <table>
        <tr>
            <td>
                <xf:group id="agendas"  ref="instance('i-schedules')/*:schedule[index('r-schedules-id')]" class="svFullGroup bordered">
                <table>
                    <tr>
                        <td colspan="3">
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
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svAddTrigger" >
                                <xf:label>Neu</xf:label>
                                <xf:action ev:event="DOMActivate">
                                    <xf:insert position="after" at="index('r-agendas-id')"
                                        nodeset="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda"
                                        context="instance('i-schedules')/schedule[index('r-schedules-id')]"
                                        origin="instance('i-calInfos')/bricks/agenda"/>
                                </xf:action>
                            </xf:trigger>
                        </td>
                        <td>
                            <xf:trigger class="svAddTrigger" ref="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda">
                                <xf:label>Clone</xf:label>
                                <xf:action ev:event="DOMActivate">
                                    <xf:insert position="after" at="index('r-agendas-id')"
                                        nodeset="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda"
                                        origin="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda[index('r-agendas-id')]"/>
                                </xf:action>
                            </xf:trigger>
                        </td>
                        <td>
                            <xf:trigger  ref="instance('control-center')/delete-agenda-trigger" class="svDelTrigger">
                                <xf:label>Entfernen</xf:label>
                                    <xf:delete ev:event="DOMActivate" 
                                        nodeset="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda"
                                        at="index('r-agendas-id')"/>
                                    <xf:setvalue ref="instance('control-center')/*:dirty" value="'true'"/>
                            </xf:trigger>
                        </td>
                    </tr>
                    </table>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-schedules')/*:schedule[index('r-schedules-id')]/*:agenda[index('r-agendas-id')]" class="svFullGroup bordered">
                    <xf:label>Gültigkeit</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('control-center')/*:dirty" value="'true'"/>
                    </xf:action>
                    <table>
                    <tr>
                        <td>
                            <strong>Von:</strong>
                        </td>
                        <td>
                            <xf:input id="agd-start" ref="./period/start/@value">
                                <xf:alert>a valid date is required</xf:alert>
                            </xf:input>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <strong>Bis:</strong>
                        </td>
                        <td>
                            <xf:input id="agd-end" ref="./period/end/@value">
                                <xf:alert>a valid date is required</xf:alert>
                            </xf:input>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <strong>Ort</strong>
                        </td>
                        <td>
                <xf:select1 ref="instance('i-schedules')/*:schedule[index('r-schedules-id')]/*:agenda[index('r-agendas-id')]/*:location/*:reference/@value">
                    <xf:itemset ref="instance('i-locations')/*:Location">
                        <xf:label ref="./*:description/@value"/>
                        <xf:value ref="./*:identifier/*:value/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue 
                            ref="instance('i-schedules')/schedule[index('r-schedules-id')]/*:location/*:display/@value"
                            value="instance('i-locations')/*:Location[*:identifier/*:value/@value=instance('i-schedules')/schedule[index('r-schedules-id')]/*:location/*:reference/@value]/*:name/@value"/>
                        <xf:setvalue ref="instance('i-control-center')/*:dirty" value="'true'"/>
                    </xf:action>
                </xf:select1>
                <xf:trigger ref="instance('i-schedules')/*:schedule[index('r-schedules-id')]/*:agenda[index('r-agendas-id')][not(*:location)]" class="svAddTrigger">
                    <xf:label>Ort ändern</xf:label>
                    <xf:action>
                        <xf:insert ref="instance('i-schedules')/*:schedule[index('r-schedules-id')]/*:agenda[index('r-agendas-id')]/*:location" 
                                context="instance('i-schedules')/*:schedule[index('r-schedules-id')]/*:agenda[index('r-agendas-id')]"
                                origin="instance('i-scheduleInfos')/*:location"/>
                    </xf:action>
                </xf:trigger>
                        </td>
                    </tr>
                </table>
                </xf:group>
            </td>
        </tr>
    </table>
</xf:group>
};

declare function sched:events()
{
<xf:group class="svFullGroup">
    <xf:action ev:event="xforms-value-changed">
        <xf:setvalue ref="instance('i-control-center')/*:dirty" value="'true'"/>
    </xf:action>
    <table>
        <tr>
            <td>
                <xf:group id="events" ref="instance('i-schedules')/schedule[index('r-schedules-id')]" class="svFullGroup bordered">
                    <xf:repeat id="r-events-id" nodeset="./agenda[index('r-agendas-id')]/event" appearance="compact" class="svRepeat">
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
                                        <xf:insert position="after" at="index('r-events-id')"
                                            nodeset="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda[index('r-agendas-id')]/event"
                                            context="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda[index('r-agendas-id')]"
                                            origin="instance('i-calInfos')/bricks/event"/>
                                <!--
                                        <xf:setvalue 
                                            ref="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda[index('r-agendas-id')]/event[index('r-events-id')+1]"
                                            value="current-dateTime()"/>
                                -->
                                    </xf:action>
                                </xf:trigger>
                            </td>
                            <td>
                                <xf:trigger  ref="instance('control-center')/delete-event-trigger" class="svDelTrigger">
                                    <xf:label>Entfernen</xf:label>
                                    <xf:delete ev:event="DOMActivate" 
                                        nodeset="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda[index('r-agendas-id')]/event"
                                        at="index('r-events-id')"/>
                                    <xf:setvalue ref="instance('control-center')/*:dirty" value="'true'"/>
                                </xf:trigger>
                            </td>
                            </tr>
                        </table>
                    </xf:group>
                </xf:group>
            </td>
            <td>
                <xf:group  ref="instance('i-schedules')/schedule[index('r-schedules-id')]/agenda[index('r-agendas-id')]/event[index('r-events-id')]"
                        class="svFullGroup bordered">
                    <xf:label>Zeiten</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('control-center')/*:dirty" value="'true'"/>
                    </xf:action>
                    <table>
                        <tr>
                            <td>
                                <xf:input ref="./name/@value" class="medium-input">
                                    <xf:label class="svListHeader">Name:</xf:label>
                                </xf:input>
                            </td>
                            <td>
                                <xf:select1 ref="./location/@value">
                                </xf:select1>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <xf:input id="evt-start" ref="./start/@value" appearance="bf:time" class="medium-input">
                                    <xf:label class="svListHeader" >Von:</xf:label>
                                    <xf:alert>a valid time is required</xf:alert>
                                </xf:input>
                            </td>
                            <td>
                                <xf:input id="evt-end" ref="./end/@value" appearance="bf:time" class="medium-input">
                                    <xf:label  class="svListHeader">Bis:</xf:label>
                                    <xf:alert>a valid time is required</xf:alert>
                                </xf:input>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <strong>Ort ändern</strong>
                            </td>
                            <td>
                <xf:select1 ref="./*:location/*:reference/@value">
                    <xf:itemset ref="instance('i-locations')/*:Location">
                        <xf:label ref="./*:description/@value"/>
                        <xf:value ref="./*:identifier/*:value/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue 
                            ref="instance('i-schedules')/schedule[index('r-schedules-id')]/*:location/*:display/@value"
                            value="instance('i-locations')/*:Location[*:identifier/*:value/@value=instance('i-schedules')/schedule[index('r-schedules-id')]/*:location/*:reference/@value]/*:name/@value"/>
                        <xf:setvalue ref="instance('i-control-center')/*:dirty" value="'true'"/>
                    </xf:action>
                </xf:select1>
                <xf:trigger ref="instance('i-schedules')/*:schedule[index('r-schedules-id')]/*:agenda[index('r-agendas-id')]/event[index('r-events-id')][not(*:location)]" class="svAddTrigger">
                    <xf:label>Ort</xf:label>
                    <xf:action>
                        <xf:insert ref="instance('i-schedules')/*:schedule[index('r-schedules-id')]/*:agenda[index('r-agendas-id')]/event[index('r-events-id')]/*:location" 
                                context="instance('i-schedules')/*:schedule[index('r-schedules-id')]/*:agenda[index('r-agendas-id')]/event[index('r-events-id')]"
                                origin="instance('i-scheduleInfos')/*:location"/>
                    </xf:action>
                </xf:trigger>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <xf:textarea class="fullareashort" ref="./note">
                                    <xf:label id="evt-note" class="svListHeader">Hinweise:</xf:label>
                                </xf:textarea>
                            </td>
                        </tr>
                    </table><br/>
                    { sched-util:rrules() }
                    { sched-util:rdates() }
                    { sched-util:exdates() }
                    { sched-util:trigger()}
                    { sched-util:help() }
                </xf:group>
            </td>
        </tr>
    </table>
</xf:group>
};

