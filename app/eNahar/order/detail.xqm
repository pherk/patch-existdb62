xquery version "3.0";
(: ~
 : slot
 : 
 : @author Peter Herkenrath
 : @version 0.1
 : 2015-07-23
 : 
 : 
 :)
module namespace detail = "http://enahar.org/exist/apps/enahar/detail";

declare namespace ev  = "http://www.w3.org/2001/xml-events";
declare namespace xf  = "http://www.w3.org/2002/xforms";
declare namespace bf = "http://betterform.sourceforge.net/xforms";
declare namespace bfc = "http://betterform.sourceforge.net/xforms/controls";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";


(:~
 :  structure for order details
 :  not component for FHIR
 :  example:
        <detail id="1">
            <process value="true"/>
            <info value=" nur Dienstags WV meta"/>
            <actor>
                <role value="arzt"/>
                <reference value="metis/practitioners/u-pmh"/>
                <display value="Herkenrath"/>
                <required value="true"/>
            </actor>
            <schedule ref="enahar/schedules/amb-spz-arzt"/>
            <search>
                <start value="3M"/>
                <end value=""/>
            </search>
            <duration value="30"/>
            <proposal>
                <display value=""/>
                <acq value="open"/>
            </proposal>
        </detail>
        <detail id="2">
            <process value="true"/>
            <info value=" nur Dienstags WV meta"/>
            <actor>
                <role value="spz-eeg"/>
                <reference value=""/>
                <display value="EEG"/>
                <required value="true"/>
            </actor>
            <schedule ref="enahar/schedules/fun-spz-eeg"/>
            <search>
                <start value="3M"/>
                <end value=""/>
            </search>
            <duration value="90"/>
            <proposal>
                <display value=""/>
                <acq value="open"/>
            </proposal>
        </detail>
:)


declare function detail:mkDetailListGroup()
{
    <xf:group id="detaillist" ref="instance('i-all')/*:Order[index('r-orders-id')]">
        <table>
            <thead>
                <tr>
                    <td colspan="7"><h4><xf:output ref="*:subject/*:display/@value"/><xf:output value="' - angefordert von '"/><xf:output ref="*:source/*:display/@value"/><xf:output value="concat(' am ',format-date(xs:date(tokenize(*:date/@value,'T')[1]),'[D01].[M01].[Y0001]'))"/></h4></td>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td colspan="1">
                        <xf:trigger class="svUpdateMasterTrigger">
                            <xf:label>./. Liste</xf:label>
<!--
                        <xf:send submission="s-get-orders"/>
-->
                            <xf:toggle case="listOrders"/>
                        </xf:trigger>
                    </td>
                    <td colspan="1">
                        <xf:trigger class="svSaveTrigger">
                            <xf:label>Speichern ./.</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:dispatch name="resetDetailProposals" targetid="model"/>
                                <xf:send submission="s-submit-order"/>
                                <xf:toggle case="listOrders"/>
                                <xf:dispatch name="resetGlobalProposals" targetid="model"/>
                                <xf:action>
                                    <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                                    <xf:send submission="s-search"/>
                                </xf:action>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td colspan="1">
                        <xf:trigger class="svSaveTrigger">
                            <xf:label>./. Patient</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:load show="new">
                                    <xf:resource value="concat('/exist/apps/nabu/index.html?action=listPatients&amp;id=',substring-after(instance('i-all')/*:Order[index('r-orders-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
                                </xf:load>
                            </xf:action>
                        </xf:trigger>
                    </td>
                </tr><tr>
                    <td colspan="7">
                        { detail:plannedEncounters() }
                    </td>
                </tr><tr>
                    <td>
                        <strong>Wichtigkeit:</strong>
                    </td>
                    <td>
                        <xf:select1 ref="./*:when/*:code/*:coding/*:code/@value" class="medium-input">
                            <xf:itemset nodeset="instance('i-o-infos')/*:when/*:code">
                                        <xf:label ref="./@label-de"/>
                                        <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:setvalue ref="instance('i-all')/*:Order[index('r-orders-id')]/*:when/*:code/*:coding/*:display/@value" value="instance('i-o-infos')/*:when/*:code[@value=instance('i-actions')/*[xs:int(instance('i-control-center')/*:rasid)]/*:when/*:code/*:coding/*:code/@value]/@label-de"/>
                                <xf:setvalue ref="instance('i-all')/*:Order[index('r-orders-id')]/*:when/*:code/*:text/@value" value="instance('i-o-infos')/*:when/*:code[@value=instance('i-all')/*:Order[index('r-orders-id')]/*:when/*:code/*:coding/*:code/@value]/@label-de"/>
                            </xf:action>
                        </xf:select1>
                    </td>
                </tr><tr>
                   <td>
                        <strong>Anlass</strong>
                    </td>
                    <td>
                        <xf:textarea ref="./*:description/@value" class="fullareashort">
                        </xf:textarea>
                    </td>
                </tr><tr>
                    <td>
                        <strong>FaFue</strong>
                    </td>
                    <td>
                        <xf:output id="oa-fafue" ref="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-memo')/*:eocs-id)]/*:careManager/*:display/@value" class=""/>
                    </td>
                </tr><tr>
                    <td colspan="7"><hr/></td>
                </tr><tr>
                    <td colspan="7">
                        { detail:closedDetails() }
                    </td>
                </tr><tr>
                    <td colspan="7">
                        { detail:openDetails() }
                    </td>
                </tr>
                <tr>
                    <td colspan="4">
                        <xf:group ref="instance('views')/ProposalAccepted">
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Vereinbaren</xf:label>
                                <xf:action ev:event="DOMActivate">
                                    <xf:setvalue 
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:status/@value"
                                        value="'active'"/>
                                    <xf:action if="count(instance('i-all')/*:Order[index('r-orders-id')]/*:detail/*:status[@value='active']) = 0">
                                        <xf:action if="count(distinct-values(instance('i-all')/*:Order[index('r-orders-id')]/*:detail/*:status/@value)) = 1">
                                            <xf:setvalue 
                                                ref="instance('i-all')/*:Order[index('r-orders-id')]/*:status/@value"
                                                value="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[1]/*:status/@value"/>
                                        </xf:action>
                                        <xf:action if="count(distinct-values(instance('i-all')/*:Order[index('r-orders-id')]/*:detail/*:status[@value!='cancelled'])) = 1">
                                            <xf:setvalue 
                                                ref="instance('i-all')/*:Order[index('r-orders-id')]/*:status/@value"
                                                value="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value!='cancelled'][1]/*:status/@value"/>
                                        </xf:action>
                                    </xf:action>
                                    <xf:setvalue
                                        ref="instance('i-memo')/*:progress"
                                        value="concat('Termin',choose(count(instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('accepted','tentative')])=1,'','e'),': ',string-join(instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('accepted','tentative')]/*:proposal/*:start/@value,'-'))"/>
                                    <xf:action>
                                        <!-- submits Order too -->
                                        <xf:send submission="s-submit-enc"/>
                                    </xf:action>
                                    <xf:message  level="ephemeral">Termin vereinbart</xf:message>
                                </xf:action>
                            </xf:trigger>
                        </xf:group>
                    </td>
                </tr>
            </tbody>
            <tfooter>
                <tr>
                    <td colspan="7">
                        <xf:switch id="search-help">
                            <xf:case id="nohelp">
                            </xf:case>
                            <xf:case id="showhelp">
                                <table>
                                    <tr>
                                        <td colspan="2">
                                            <xf:trigger class="svUpdateMasterTrigger">
                                                <xf:label>Schließen</xf:label>
                                                <xf:toggle case="nohelp" ev:event="DOMActivate"/>
                                            </xf:trigger>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td colspan="2">
                                               <strong>Hilfe</strong>
                                        </td>
                                        <td colspan="5">
                                                <strong>Suchmodi</strong>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td colspan="2">
                                            <xf:group>
 
                                    <p>Zunächst wird der Einkaufskorb analysiert. Anhand der eingegebenen Kriterien wird entschieden, wie die Suche
                                       durchgeführt wird ('Kombi') und mit wieviel Aufwand ('Suchzeitraum'). Die Suchmodi erlauben eine Feinkontrolle.</p>
                                            </xf:group>
                                        </td>
                                        <td colspan="2">
                                            <xf:group>

                                    <dl>
                                        <dt>Normal</dt>
                                        <dd>Nur 'freie' Slots werden selektiert.</dd>
                                        <dt>BisTermin</dt>
                                        <dd>Die normale Suche wird fortgesetzt, bis ein Termin gefunden wird (Limit: 6 Zyklen)</dd>
                                    </dl>
                                            </xf:group>
                                        </td>
                                        <td colspan="3">
                                            <xf:group>
                                    <dl>
                                        <dt>Parallel</dt>
                                        <dd>Ermöglicht Termine parallel zu vergeben, z.B. 3 zur vollen und 2 zur halben Stunde</dd>
                                        <dt>Pressing</dt>
                                        <dd>Normale Suche plus Check auf 'lange' Termine bei WV-Patienten. Voraussetzung Kalender ist als überbuchbar gekennzeichnet (z.B. Arzt). Wenn kein 'freier' Slot gefunden wird, wird ein Termin parallel am Ende eines 'langen' Termins angeboten</dd>
                                    </dl>
                                            </xf:group>
                                        </td>
                                    </tr>
                                </table>
                            </xf:case>
                        </xf:switch>
                    </td>
                </tr>
            </tfooter>
        </table>
    </xf:group>
};

declare %private function detail:plannedEncounters()
{
    <xf:group class="svFullGroup bordered">
        <xf:label>Offene Termine</xf:label>
        <xf:group ref="instance('i-planned-encs')/*:Encounter">
            <xf:repeat id="r-openenc-ids" ref="instance('i-planned-encs')/*:Encounter" appearance="compact" class="svRepeat">
                <xf:output id="oa-date" value="tokenize(./*:period/*:start/@value,'T')[1]" class="short-input">
                    <xf:label class="svRepeatHeader">Datum</xf:label>
                </xf:output>
                <xf:output id="oa-time" value="tokenize(./*:period/*:start/@value,'T')[2]" class="short-input">
                    <xf:label class="svRepeatHeader">Uhrzeit</xf:label>
                </xf:output>
                <xf:output id="oa-actors" value="string-join(./*:participant/*:individual/*:display/@value,', ')" class="">
                    <xf:label class="svRepeatHeader">Teilnehmer</xf:label>
                </xf:output>
                <xf:output id="oa-status" value="*:status/@value" class="">
                    <xf:label class="svRepeatHeader">Status</xf:label>
                </xf:output>
            </xf:repeat>
        </xf:group>
    </xf:group>
};

declare %private function detail:closedDetails()
{
    <xf:group id="closed-details" class="svFullGroup bordered">
        <xf:label>Schon vereinbarte Details</xf:label>
        <xf:repeat id="r-closed-id" ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('completed','cancelled')]" appearance="compact" class="svRepeat">
                    <xf:output id="cdet-role" value="./*:actor/*:role/@value" class="short-input">
                        <xf:label class="svRepeatHeader">Service</xf:label>
                    </xf:output>
                    <xf:output id="cdet-actor" ref="./*:actor/*:display/@value" class="short-input">
                        <xf:label class="svRepeatHeader">Erbringer</xf:label>
                    </xf:output>
                    <xf:output id="cdet-ical" ref="./*:schedule/*:display/@value" class="short-input">
                        <xf:label class="svRepeatHeader">Kalender</xf:label>
                    </xf:output>
                    <xf:output id="cdet-dur" ref="./*:spec/*:duration/@value" class="short-input">
                        <xf:label class="svRepeatHeader">Dauer</xf:label>
                    </xf:output>
                    <xf:output id="cdet-start" ref="./*:proposal/*:start/@value" class="">
                        <xf:label class="svRepeatHeader">Termin</xf:label>
                    </xf:output>
                    <xf:output id="cdet-info" ref="./*:info/@value" class="">
                        <xf:label class="svRepeatHeader">Info</xf:label>
                    </xf:output>
        </xf:repeat>
    </xf:group>
};

declare %private function detail:openDetails()
{
    <xf:group id="details" class="bordered">
        <xf:label>Offene Details</xf:label>
        <table>
            <tr>
                <td colspan="4">
                    { detail:openDetailsList() }
                </td>
                <td>
                    <xf:trigger ref="instance('views')/ProposalsToSelect" class="">
                        <xf:label>&lt;&lt;</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('iiter')" value="'1'"/>
                            <xf:action while="instance('iiter') &lt;= count(instance('i-proposals')/proposal[1]/detail)">
                                <xf:action if="not(instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[xs:int(instance('iiter'))]/notprocessed)">
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[1]/detail[xs:int(instance('iiter'))]/@id]/*:proposal/*:start/@value"
                                        value="instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[xs:int(instance('iiter'))]//*:tp/@start"/>
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[1]/detail[xs:int(instance('iiter'))]/@id]/*:proposal/*:end/@value"
                                        value="instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[xs:int(instance('iiter'))]//*:tp/@end"/>
<!--
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[@id=instance('iiter')]/@id]/*:proposal/*:display/@value"
                                        value="tokenize(instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[@id=instance('iiter')]//display/@value,' ')[2]"/>
-->
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[1]/detail[xs:int(instance('iiter'))]/@id]/*:status/@value"
                                        value="choose((instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[xs:int(instance('iiter'))]/@id]/*:schedule/*:reference/@value='enahar/schedules/worktime'),'tentative','accepted')"/>
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[1]/detail[xs:int(instance('iiter'))]/@id]/*:process/@value"
                                        value="'false'"/>
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[1]/detail[xs:int(instance('iiter'))]/@id]/*:actor/*:reference/@value"
                                        value="instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[xs:int(instance('iiter'))]//*:actor/@ref"/>
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[1]/detail[xs:int(instance('iiter'))]/@id]/*:actor/*:display/@value"
                                        value="instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[xs:int(instance('iiter'))]//*:actor/@display"/>
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[1]/detail[xs:int(instance('iiter'))]/@id]/*:schedule/*:reference/@value"
                                        value="instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[xs:int(instance('iiter'))]//*:schedule/@ref"/>
                                    <xf:setvalue
                                        ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[@id = instance('i-proposals')/proposal[1]/detail[xs:int(instance('iiter'))]/@id]/*:schedule/*:display/@value"
                                        value="instance('i-proposals')/proposal[@id = instance('i-proposals')/index]/detail[xs:int(instance('iiter'))]//*:schedule/@display"/>
                                </xf:action>
                                <xf:setvalue ref="instance('iiter')" value="instance('iiter') + 1"/>
                            </xf:action>
                            <xf:message  level="ephemeral">Termin übernommen</xf:message>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td colspan="3" rowspan="2">
                    { detail:proposals()}
                </td>
            </tr>
            <tr>
                <td>
                    <xf:input ref="instance('i-memo')/*:lfdno" class="tiny-input">
                        <xf:label>LfdNo</xf:label>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue
                                ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:spec/*:combination/@value"
                                value="instance('i-memo')/*:lfdno"/>
                        </xf:action>
                    </xf:input>
                </td>
                <td colspan="1">
                    <label for="fafue-hack" class="xfLabel aDefault xfEnabled">Fafü:</label>
                    <select class="order-select" name="fafue-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="order/fafue.js"/>
                </td>
                <td colspan="1">
                    <label for="ownerservice-hack" class="xfLabel aDefault xfEnabled">Kalender:</label>
                    <select class="order-select" name="ownerservice-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="order/ownerservices.js"/>
                </td>
                <td colspan="1">
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Suchen</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-get-proposals"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td colspan="2">
                    <xf:group ref="instance('views')/ProposalsToSelect">
                        <xf:trigger ref="instance('views')/ProposalPrevActive">
                            <xf:label>&lt;</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-proposals')/index" value="instance('i-proposals')/index - 1"/>
                            </xf:action>
                        </xf:trigger>
                        <xf:output value="concat(instance('i-proposals')/index,' (',instance('i-proposals')/count,')')"></xf:output>
                        <xf:trigger ref="instance('views')/ProposalNextActive">
                            <xf:label>&gt;</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-proposals')/index" value="instance('i-proposals')/index + 1"/>
                            </xf:action>
                        </xf:trigger>
                    </xf:group>
                </td>
            </tr>
            <tr>
                <td>
                    <xf:trigger class="svAddTrigger" >
                        <xf:label>Neu</xf:label>
                        <xf:insert ev:event="DOMActivate" position="after" at="last()"
                            nodeset="instance('i-all')/*:Order[index('r-orders-id')]/*:detail"
                            context="instance('i-all')/*:Order[index('r-orders-id')]"
                            origin="instance('i-o-infos')/*:bricks/*:detail"/>
                        <xf:setvalue
                            ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/@id"
                            value="generate-id()"/>
                        <xf:setvalue
                            ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:spec/*:combination/@value"                                 value="index('r-details-id')"/>
                        <xf:setvalue ref="instance('i-memo')/*:lfdno"
                                        value="index('r-details-id')"/>
                    </xf:trigger>
                </td>
                <td>
                    <xf:trigger class="svDelTrigger">
                        <xf:label>Detail löschen</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:delete nodeset="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')]" at="index('r-details-id')"/>
                            <xf:action if="count(distinct-values(instance('i-all')/*:Order[index('r-orders-id')]/*:detail/*:status/@value)) = 1">
                                <xf:setvalue ref="instance('i-all')/*:Order[index('r-orders-id')]/*:status/@value"
                                    value="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[1]/*:status/@value"/>
                            </xf:action>
                            <xf:action if="count(distinct-values(instance('i-all')/*:Order[index('r-orders-id')]/*:detail/*:status/@value)) = 0">
                                <xf:setvalue ref="instance('i-all')/*:Order[index('r-orders-id')]/*:status/@value"
                                    value="'cancelled'"/>
                            </xf:action>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                    <strong>Suchmodus</strong>
                </td>
                <td>
                    <xf:select1 ref="instance('i-memo')/*:search-mode" class="medium-input">

                        <xf:item>
                            <xf:label>Normal</xf:label>
                            <xf:value>normal</xf:value> 
                        </xf:item>
                        <xf:item>
                            <xf:label>BisTermin</xf:label>
                            <xf:value>uptodate</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>Parallel</xf:label>
                            <xf:value>parallel</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>Pressing</xf:label>
                            <xf:value>pressing</xf:value>
                        </xf:item>
                    </xf:select1>
                </td>
                <td>
                    <xf:trigger>
                        <xf:label>Hilfe</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:toggle case="showhelp"/>
                            </xf:action>
                    </xf:trigger>
                </td>
                <td>
<!--
                    <xf:trigger class="svCalTrigger">
                        <xf:action ev:event="DOMActivate">
                            <script type="text/javascript">
                                var date = $('#r-proposals-id .xfValue').text().split(' ')[0];
                                $('#calendar').fullCalendar('gotoDate', date);
                            </script>
                        </xf:action>
                    </xf:trigger>
-->
                </td>
            </tr>
        </table>
    </xf:group>
};

declare %private function detail:openDetailsList()
{
    <xf:group id="opendetails">
        <xf:action ev:event="betterform-index-changed">        
            <xf:dispatch name="resetGlobalProposals" targetid="model"/>
            <xf:message level="ephemeral">updateFaFue</xf:message>
            <xf:dispatch name="updateFaFue" targetid="model"/>
        </xf:action> 
    <xf:repeat id="r-details-id" ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')]" appearance="compact" class="svRepeat">
        <xf:input ref="./*:process/@value" class="xsdBoolean svRepeatBool">
            <xf:label class="svListHeader svRepeatBool"><img src="../nabu/resources/images/001_47.png" alt="Proc"/></xf:label>
        </xf:input>
        <xf:output ref="./*:spec/*:combination/@value">
            <xf:label class="svListHeader">No</xf:label>
        </xf:output>
        <xf:input ref="./*:spec/*:interdisciplinary/@value" class="xsdBoolean svRepeatBool">
            <xf:label class="svListHeader"><img src="../nabu/resources/images/link.png" alt="Kombi"/></xf:label>
        </xf:input>
        <xf:select1 ref="./*:actor/*:role/@value" class="medium-select" incremental="true">
            <xf:label class="svListHeader">Service</xf:label>
            <xf:itemset nodeset="instance('i-groups')/*:Group">
                <xf:label ref="./*:name/@value"/>
                <xf:value ref="./*:code/*:text/@value"/>
            </xf:itemset>
            <xf:hint>Bitte eine Funktion auswählen</xf:hint>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:service-code"
                    value="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:role/@value"/>
            </xf:action>
        </xf:select1>
        <xf:select1 ref="./*:actor/*:reference/@value" class="medium-select" incremental="true">
            <xf:label class="svListHeader">Erbringer</xf:label>
            <xf:itemset nodeset="instance('i-users')/*:user">
                <xf:label ref="./*:display/@value"/>
                <xf:value ref="./*:reference/@value"/>
            </xf:itemset>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue
                    ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:display/@value"
                    value="instance('i-users')/*:user[./*:reference/@value=instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:reference/@value]/*:display/@value"/>
                <xf:setvalue ref="instance('i-memo')/*:fafue-uid"
                    value="substring-after(instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:reference/@value,'metis/practitioners/')"/>
                <xf:setvalue ref="instance('i-memo')/*:fafue-display"
                    value="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:display/@value"/>
            </xf:action>
        </xf:select1>
        <xf:output id="det-ical" ref="./*:schedule/*:display/@value" class="medium-input">
            <xf:label class="svListHeader">Kalender</xf:label>
        </xf:output>
        <xf:select1 id="det-dur" ref="./*:spec/*:duration/@value" class="medium-input">
            <xf:label class="svListHeader">Dauer</xf:label>
            <xf:itemset ref="instance('i-calInfos')/duration/code">
                <xf:label ref="./@label"/>
                <xf:value ref="./@value"/>
            </xf:itemset>
        </xf:select1>
        <xf:input id="det-start" ref="./*:spec/*:begin/@value" incremental="true" class="short-input">
            <xf:label class="svListHeader">Wunsch</xf:label>
        </xf:input>
        <xf:output id="det-info" ref="./*:info/@value" class="">
            <xf:label class="svListHeader">Info</xf:label>
        </xf:output>
    </xf:repeat>
    </xf:group>
};

declare %private function detail:proposals()
{
(
    <xf:group id="proposals" ref="instance('i-proposals')/*:proposal[@id=instance('i-proposals')/*:index]" class="svHalfGroup">
        <xf:label>Vorschläge</xf:label>
        <xf:repeat id="r-proposals-id" ref="./*:detail" appearance="compact" class="svRepeat">
            <xf:output id="pro-date" ref="./*:display/@value">
                <xf:label class="svListHeader">Termin</xf:label>
            </xf:output>
            <xf:output id="pro-service" ref="./*:schedule/@display">
                <xf:label class="svListHeader">Service</xf:label>
            </xf:output>
            <xf:output id="pro-actor" ref="./*:actor/@display">
                <xf:label class="svListHeader">Erbringer</xf:label>
            </xf:output>
        </xf:repeat>
    </xf:group>
,   <xf:group ref="instance('views')/*:NoProposals" class="svHalfGroup bordered">
        <xf:label>Leider kein Vorschlag</xf:label>
        <table>
            <tr>
                <td>
                    <strong>Problem:</strong>
                </td>
                <td>
                    <xf:output ref="instance('i-proposals')/*:error"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Hinweis:</strong>
                </td>
                <td>
                    <xf:output ref="instance('i-proposals')/*:hint"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Start:</strong>
                </td>
                <td>
                    <xf:output id="cart-combi-start" value="choose(instance('i-proposals')/*:cart/*:sameday/*:period/*:start='', 'kein Kombi',concat(substring-before(instance('i-proposals')/*:cart/*:sameday/*:period/*:start,'T'),' bis ',substring-before(instance('i-proposals')/*:cart/*:sameday/*:period/*:end,'T')))"/>
                    <xf:repeat ref="instance('i-proposals')/*:cart/*:simple" appearance="compact" class="svRepeatBlank">
                        <xf:output id="cart-simple-start" value="concat(substring-before(./*:period/*:start,'T'),' bis ',substring-before(./*:period/*:end,'T'))"/>
                    </xf:repeat>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Stats:</strong>
                </td>
                <td>
                <xf:group ref="instance('i-proposals')/*:info/*:combi">
                    <xf:output id="pro-start" value="concat(substring-before(./*:request/*:start,'T'),' bis ',substring-before(./*:request/*:end,'T'))"/>
                    <xf:repeat ref="./*:rawSlots/*:detail" appearance="compact" class="svRepeatBlank">
                        <xf:output value="concat(./*:label,': ',./*:slots,' Slot', choose(./*:slots&gt;1,'s',''),' an ',./*:days,'d')"/>
                    </xf:repeat>
                </xf:group>
                </td>
            </tr>
        </table>
    </xf:group>
)
};

