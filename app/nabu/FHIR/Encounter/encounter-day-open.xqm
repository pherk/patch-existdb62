xquery version "3.1";

module namespace enc-open = "http://enahar.org/exist/restxq/nabu/encounter-open";
declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

declare function enc-open:list()
{
<xf:group>
    <xf:group id="openencs" ref="instance('i-openencs')/*:Encounter" class="svFullGroup">
        <xf:label>Bitte die Offenen Termine abschließen</xf:label>
        <xf:repeat id="r-openencs-id" ref="instance('i-openencs')/*:Encounter" appearance="compact" class="svRepeat">
            <xf:output value="tokenize(./*:period/*:start/@value,'T')[1]">
                <xf:label class="svListHeader">Datum:</xf:label>                        
            </xf:output>
            <xf:output value="concat(format-dateTime(./*:period/*:start/@value, '[H1]:[m01]'),'-',format-dateTime(./*:period/*:end/@value, '[H1]:[m01]'))">
                <xf:label class="svListHeader">Von-Bis:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:subject/*:display/@value">
                <xf:label class="svListHeader">Patient:</xf:label>
            </xf:output>
            <xf:output ref="./*:reasonCode/*:text/@value">
                <xf:label class="svListHeader">Info</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant/*:type/*:coding/*:code/@value">
                <xf:label class="svListHeader">Service:</xf:label>                        
            </xf:output>
            <xf:output value="./*:status/@value">
                <xf:label class="svListHeader">Status:</xf:label>                        
            </xf:output>
        </xf:repeat>
    </xf:group>
    <xf:group ref="instance('i-openencs')/*:Encounter[count(.)=0]">
        <xf:label>Glückwunsch! Keine Offenen Termine mehr</xf:label>
    </xf:group>
    <table>
        <tr>
            <td></td>
            <td></td>
            <td>
                <xf:trigger ref="instance('i-wf')/*:dirty[.='false']" class="svUpdateMasterTrigger">
                    <xf:label>./. Tagesliste</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                        <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                        <xf:toggle case="enc-main"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td colspan="2">
                <xf:trigger ref="instance('i-wf')/*:dirty[.='false']" class="svUpdateMasterTrigger">
                    <xf:label>Liste akt.</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                        <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                        <xf:send submission="s-get-openencs"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <th>Aktion</th>
            <td>
                    <xf:select1 id="openenc-event" ref="instance('i-wf')/*:event" class="" incremental="true">
                         <xf:item>
                            <xf:label>beendet</xf:label>
                            <xf:value>finished</xf:value>
                        </xf:item>
                         <xf:item>
                            <xf:label>nicht wahrgenommen</xf:label>
                            <xf:value>noshow</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>abgesagt (Pat)</xf:label>
                            <xf:value>cancelled-pat</xf:value>
                        </xf:item>
                         <xf:item>
                            <xf:label>abgesagt (SPZ)</xf:label>
                            <xf:value>cancelled-spz</xf:value>
                        </xf:item>
                    <!--
                        <xf:itemset ref="instance('i-e-infos')/*:event-planned/*:code">
                            <xf:label ref="./@label-ger"/>
                            <xf:value ref="./@value"/>
                        </xf:itemset>
                    -->
                        <xf:action ev:event="xforms-value-changed">
                            <xf:action if="instance('i-wf')/*:event='finished'">
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'true'"/>
                                <xf:insert at="last()"
                                    ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory"
                                    context="instance('i-openencs')/*:Encounter[index('r-openencs-id')]"
                                    origin="instance('i-e-infos')/*:bricks/*:statusHistory"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]/*:status/@value"
                                    value="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:status/@value"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]//*:code/@value"
                                    value="instance('i-wf')/*:event"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]/*:period/*:start/@value"
                                    value="adjust-dateTime-to-timezone(current-dateTime())"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:status/@value"
                                    value="'finished'"/>
                                <xf:message level="modal">Besuch beendet. Bitte noch Kommentar eingeben (CarePlan Ergebnis!).</xf:message>
                            </xf:action>
                            <xf:action if="instance('i-wf')/*:event=('noshow','cancelled-pat','cancelled-spz')">
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'true'"/>
                                <xf:insert at="last()"
                                    ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory"
                                    context="instance('i-openencs')/*:Encounter[index('r-openencs-id')]"
                                    origin="instance('i-e-infos')/*:bricks/*:statusHistory"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]/*:status/@value"
                                    value="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:status/@value"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]//*:code/@value"
                                    value="instance('i-wf')/*:event"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]//*:text/@value"
                                    value="instance('i-e-infos')/*:event-planned/*:code[@value=instance('i-wf')/*:event]/@label-ger"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]/*:period/*:start/@value"
                                    value="adjust-dateTime-to-timezone(current-dateTime())"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:status/@value"
                                    value="'cancelled'"/>
                                <xf:message level="modal">Termin cancelled. Bitte noch Kommentar ergänzen (CarePlan Ergebnis!) und gfls. neuen Termin veranlassen.</xf:message>
                            </xf:action>
                        </xf:action>
                    </xf:select1>
            </td>
            <td>
                <xf:trigger ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]" class="svSaveTrigger">
                    <xf:label>./. Patient</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:load show="new">
                            <xf:resource value="concat('/exist/apps/nabu/index.html?action=listPatients&amp;id=',substring-after(instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
                        </xf:load>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
    <table>
        <tr>
            <td>
                <xf:group ref="instance('i-wf')/*:event[.=('finished','noshow','cancelled-pat','cancelled-spz')]">
                    <strong>Kommentar</strong>
                </xf:group>
            </td>
            <td colspan="4">
                <xf:group ref="instance('i-wf')/*:event[.=('finished','noshow','cancelled-pat','cancelled-spz')]">
                        <xf:input ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]//*:text/@value" class="long-input">
                        </xf:input>
                </xf:group>
            </td>
            <td>
                <xf:trigger class="svUpdateMasterTrigger" ref="instance('i-wf')/*:event[.='finished']">
                            <xf:label>Fertig</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                                <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                                <xf:send submission="s-submit-openenc"/>
                                <!-- encounter is already deleted via s-submit-openenc
                                <xf:send submission="s-get-openencs"/>
                                -->
                            </xf:action>
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svUpdateMasterTrigger" ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                            <xf:label>Canceln oWV</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                                <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                                <xf:send submission="s-submit-openenc"/>
                                <!-- encounter is already deleted via s-submit-openenc
                                <xf:send submission="s-get-openencs"/>
                                -->
                            </xf:action>
                </xf:trigger>
            </td>
        </tr>
        <tr>
            <td>
                <xf:group ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                    <strong>ReOrder</strong>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                    <xf:select1 ref="instance('i-wf')/*:prio">
                        <xf:itemset nodeset="instance('i-o-infos')/*:when/*:code">
                            <xf:label ref="./@label-de"/>
                            <xf:value ref="./@value"/>
                        </xf:itemset>
                        <xf:action>
                                <xf:setvalue ref="instance('i-wf')/*:prio-display" 
                                  value="instance('i-o-infos')/*:when/*:code[@value=instance('i-wf')/*prio]/@label-de"/>
                            </xf:action>
                    </xf:select1>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                    <xf:input ref="instance('i-wf')/*:date" class="medium-input"></xf:input>
                </xf:group>
            </td>
            <td>
                <xf:trigger class="svUpdateMasterTrigger" ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                            <xf:label>ReOrder</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:send submission="s-submit-openencs-order"/>
                                <xf:insert at="last()"
                                    ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory"
                                    context="instance('i-openencs')/*:Encounter[index('r-openencs-id')]"
                                    origin="instance('i-e-infos')/*:bricks/*:statusHistory"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]/*:status/@value"
                                    value="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:status/@value"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]//*:code/@value"
                                    value="instance('i-wf')/*:event"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]//*:text/@value"
                                    value="'Termin reordered'"/>
                                <xf:setvalue ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]/*:period/*:start/@value"
                                    value="adjust-dateTime-to-timezone(current-dateTime())"/>
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                                <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                                <xf:send submission="s-submit-openenc"/>
                                <!-- encounter is already deleted via s-submit-openenc
                                <xf:send submission="s-get-openencs"/>
                                -->
                            </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</xf:group>

};

