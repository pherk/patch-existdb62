xquery version "3.1";
module namespace enc-accept = "http://enahar.org/exist/apps/nabu/encounter-accept";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"   at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

declare variable $enc-accept:restxq-encounters   := "/exist/restxq/nabu/encounters";

declare variable $enc-accept:encounter-infos-uri := "/exist/apps/nabu/FHIR/Encounter/encounter-infos.xml";

declare %private function enc-accept:formatFHIRName($logu)
{
    string-join(
        (
              string-join($logu/fhir:name[fhir:use/@value='official']/fhir:family/@value, '')
            , $logu/fhir:name[fhir:use/@value='official']/fhir:given/@value
        ), ', ')
};

(:~
 : show tentative encounters
 : 
 : @return html
 :)
declare function enc-accept:accept()
{
    let $status := <status>tentative</status>
    let $date   := adjust-date-to-timezone(current-date(),())
    let $start  := dateTime($date,xs:time("08:00:00"))
    let $end    := $start + xs:yearMonthDuration("P1Y")
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $group  := 'spz-arzt'
    let $realm  := "kikl-spz"
    let $head   := 'Termin-Anfragen' 
    let $lll := util:log-app("TRACE","apps.nabu",$uid)
    let $lll := util:log-app("TRACE","apps.nabu",$unam)
return
(<div style="display:none;">
    <xf:model id="m-encounter" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance  xmlns="" id="i-encs">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-encounters"
                    ref="instance('i-search')"
                	instance="i-encs"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$enc-accept:restxq-encounters}?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">error get-encounters</xf:message>
        </xf:submission>

        <xf:submission id="s-submit-encounter"
                				   ref="instance('i-encs')/*:Encounter[index('r-encs-id')]"
								   method="put"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/encounters?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit encounter!</xf:message>
        </xf:submission>
        
        <xf:submission id="s-update-encounter-status"
					method="post"
					replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/encounters/',instance('i-encs')/*:Encounter[index('r-encs-id')]/*:id/@value,'/status/',instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value,'?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update encounter status!</xf:message>
        </xf:submission>
        <xf:submission id="s-update-careplan-action"
								   method="post"
								   replace="none">
a                <xf:resource value="concat('/exist/restxq/nabu/careplans/',substring-after(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:basedOn/*:reference/@value,'nabu/careplans/'),'/actions/',tokenize(tokenize(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:appointment/*:reference/@value,'\?')[1],'/')[3],'?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),choose(string-length(instance('i-wf')/*:progress)>0,concat('&amp;progress=',encode-for-uri(instance('i-wf')/*:progress)),''),choose(string-length(instance('i-wf')/*:outcome)>0,concat('&amp;outcome=',encode-for-uri(instance('i-wf')/*:outcome)),''))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update careplan action outcome!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-order"
                    ref="instance('i-encs')/*:Encounter[index('r-encs-id')]"
					method="post"
					replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/orders?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;reason=rejected')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot clone order!</xf:message>
        </xf:submission>
           <xf:submission id="s-submit-encletter" method="get" replace="none">
            <xf:resource value="concat('/exist/restxq/nabu/encounters/',substring-after(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:subject/*:reference/@value,'nabu/patients/'),'/letter?status=in-progress&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">encletter submitted</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-done">Terminbrief -&gt; Druckliste</xf:message>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">An error occurred (encletter).</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>15</length>
                <uid>{$uid}</uid>
                <group></group>
                <sched/>
                <patient/>
                <rangeStart>{$start}</rangeStart>
                <rangeEnd>{$end}</rangeEnd>
                { $status }
                <_sort>date:asc</_sort>
                <date>{$date}</date>
            </parameters>
        </xf:instance>
        <xf:bind ref="instance('i-search')/*:date" type="xs:date"/>

        <xf:instance id="i-e-infos" xmlns="" src="{$enc-accept:encounter-infos-uri}"/>
        
        <xf:instance id="views">
            <data xmlns="">
                <ListNotEmpty/>
                <ListTooLong/>
                <TriggerPrevActive/>
                <TriggerNextActive/>
                <TriggerSaveActive/>
                <EncountersToSelect/>
                <EncounterNew/>
                <today/>
            </data>
        </xf:instance>

        <xf:bind id="ListNotEmpty"
            ref="instance('views')/*:ListNotEmpty"
            readonly="count(instance('i-encs')/*:Encounter) &lt; 1"/>
        <xf:bind id="ListTooLong"
            ref="instance('views')/*:ListTooLong"
            readonly="instance('i-encs')/length &gt; instance('i-encs')/count"/>
        <xf:bind id="TriggerPrevActive"
            ref="instance('views')/*:TriggerPrevActive"
            readonly="(instance('i-encs')/start &lt; 2) or (instance('i-encs')/length &gt; instance('i-encs')/start)"/>
        <xf:bind id="TriggerNextActive"
            ref="instance('views')/*:TriggerNextActive"
            readonly="instance('i-encs')/*:start &gt; (instance('i-encs')/*:count - instance('i-encs')/*:length)"/>
        <xf:bind id="EncountersToSelect"
            ref="instance('views')/*:EncountersToSelect"
            relevant="count(instance('i-encs')/*:Encounter) &gt; 0"/>
        <xf:bind id="EncounterNew"
            ref="instance('views')/*:EncounterNew"
            relevant="count(instance('i-encs')/*:Encounter) = 0"/>
        <xf:bind id="today"
            ref="instance('views')/*:today"
            relevant="instance('i-search')/*:date = adjust-date-to-timezone(current-date(),())"/>
            
        <xf:instance id="i-wf">
            <data xmlns="">
                <event></event>
                <reorder>true</reorder>
                <dirty>false</dirty>
                <progress/>
                <outcome/>
            </data>
        </xf:instance>
        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-encounters"/>
        </xf:action>
    </xf:model>
</div>,
<div>
    <h2>{$head}</h2>
    <table class="svTriggerGroup">
        <tr>
            <td colspan="1">
                <xf:select1 ref="instance('i-search')/*:_sort" class="medium-input" incremental="true">
                    <xf:label>Sortiert nach</xf:label>
                    <xf:itemset ref="instance('i-e-infos')/*:sort/*:code">
                        <xf:label ref="./@label"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:send submission="s-get-encounters"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr>
        <tr>
            <td colspan="7"><div class="divider"></div></td>
        </tr>
    </table>
        <xf:group id="encounters" class="svFullGroup">
                <xf:repeat id="r-encs-id" ref="instance('i-encs')/*:Encounter" appearance="compact" class="svRepeat">
                    <xf:output value="format-dateTime(./*:period/*:start/@value, '[Y0001]-[M01]-[D01]')">
                        <xf:label class="svListHeader">Datum:</xf:label>                        
                    </xf:output>
                    <xf:output value="concat(format-dateTime(./*:period/*:start/@value, '[H1]:[m01]'),'-',format-dateTime(./*:period/*:end/@value, '[H1]:[m01]'))">
                        <xf:label class="svListHeader">Von-Bis:</xf:label>                        
                    </xf:output>
                    <xf:output ref="./*:subject/*:display/@value">
                        <xf:label class="svListHeader">Patient:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:reasonCode/*:text/@value">
                        <xf:label class="svListHeader">Anlass</xf:label>                        
                    </xf:output>
                    <xf:output ref="./*:participant/*:individual/*:role/@value">
                        <xf:label class="svListHeader">Service:</xf:label>                        
                    </xf:output>
                    <xf:output value="./*:status/@value">
                        <xf:label class="svListHeader">Status:</xf:label>                        
                    </xf:output>
<!--
                    <xf:trigger>
                        <xf:label class="svSubTrigger">Bearbeiten</xf:label>
                        <xf:toggle case="EditOrphan" ev:event="DOMActivate"/>
                    </xf:trigger>
                    <xf:switch>
                        <xf:case id="DoNothing">
                        </xf:case>
                        <xf:case id="EditOrphan">
                        <xf:select1 ref="./*:status/@value">
                            <xf:label>Status</xf:label>
                                <xf:item>
                                    <xf:label>Cancel</xf:label>
                                    <xf:value>cancelled</xf:value>
                                </xf:item>
                        </xf:select1>
                </xf:case>
            </xf:switch>
-->
                </xf:repeat>
        </xf:group>
    <table>
        <tr>
            <td colspan="2">
            <xf:group ref="instance('views')/*:ListTooLong">
                <xf:trigger ref="instance('views')/*:TriggerPrevActive">
                <xf:label>&lt;&lt;</xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start - instance('i-search')/*:length"/>
                    <xf:send submission="s-get-encounters"/>
                </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance('i-encs')/*:start &gt; instance()/*:count),instance()/*:count,instance()/*:start)"/>-
                <xf:output value="choose((instance('i-encs')/*:start + instance()/*:length &gt; instance()/*:count),instance()/*:count,instance()/*:start + instance()/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance('i-encs')/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/*:TriggerNextActive">
                <xf:label>&gt;&gt;</xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start + instance('i-search')/*:length"/>
                    <xf:send submission="s-get-encounters"/>
                </xf:action>
                </xf:trigger>
            </xf:group>
            </td><td>
                <xf:group>
                    <xf:group ref="instance('views')/*:EncountersToSelect">
                    <xf:input id="enc-reason"
                            ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:reasonCode/*:coding[*:system/@value='#encounter-reason']/*:display/@value"
                            class="">
                        <xf:label>Anlass:</xf:label>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:message level="ephemeral">Anlass gespeichert</xf:message>
                            <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:reasonCode/*:text/@value" value="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:reasonCode/*:coding[*:system/@value='#encounter-reason']/*:display/@value"/>
<!--
                            <xf:send submission="s-submit-encounter"/>
-->
                        </xf:action>
                    </xf:input>
                    </xf:group>
                </xf:group>
            </td><td>
                <xf:group id="action">
                    <xf:action ev:event="appendStatusHistory">
                        <xf:insert at="last()"
                                    ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory"
                                    context="instance('i-encs')/*:Encounter[index('r-encs-id')]"
                                    origin="instance('i-e-infos')/*:bricks/*:statusHistory"/>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]/*:status/@value"
                                    value="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"/>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:code/@value"
                                    value="'tentative'"/>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:text/@value"
                                    value="'zurückgewiesen, reordered'"/>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]/*:period/*:start/@value"
                                    value="adjust-dateTime-to-timezone(current-dateTime())"/>
                    </xf:action>
                    <xf:group ref="instance('views')/*:EncountersToSelect">
                    <xf:select1 id="enc-status" ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"
                            class="medium-input" selection="closed">
                        <xf:label>Status:</xf:label>
                        <xf:item>
                            <xf:label>Annehmen, Buchen</xf:label>
                            <xf:value>planned</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>Ablehnen</xf:label>
                            <xf:value>cancelled</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>lassen</xf:label>
                            <xf:value>tentative</xf:value>
                        </xf:item>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:action if="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value='planned'">
                                <xf:message level="ephemeral">Termin gebucht</xf:message>
                                <xf:send submission="s-update-encounter-status"/>
                                <xf:setvalue ref="instance('i-wf')/*:progress" value="'Vorläufiger Termin angenommen'"/>
                                <xf:send submission="s-update-careplan-action"/>
                                <xf:send submission="s-submit-encletter"/>
                            </xf:action>
                            <xf:action if="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value='cancelled'">
                                <xf:dispatch name="appendStatusHistory" targetid="action"/>
                                <xf:message level="ephemeral">Termin zurückgewiesen</xf:message>
                                <xf:setvalue ref="instance('i-wf')/*:progress" value="'Vorläufiger Termin zurückgewiesen, reordered'"/>
                                <xf:send submission="s-update-careplan-action"/>
                                <xf:send submission="s-submit-order"/>
                                <xf:send submission="s-submit-encounter"/>
                            </xf:action>
                        </xf:action>
                    </xf:select1>
                    </xf:group>
                </xf:group>
            </td><td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:EncountersToSelect">
                    <xf:label>Aktualisieren</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-get-encounters"/>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td>
            <td>
                <xf:trigger ref="instance('i-encs')/*:Encounter[index('r-encs-id')]" class="svSaveTrigger">
                <xf:label>./. Patient</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:load show="new">
                            <xf:resource value="concat('/exist/apps/nabu/index.html?action=listPatients&amp;id=',substring-after(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
                            </xf:load>
                        </xf:action>
                    </xf:trigger>
                </td>
        </tr>
    </table>
</div>
)
};

