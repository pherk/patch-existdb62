xquery version "3.1";

module namespace enc-details = "http://enahar.org/exist/restxq/nabu/encounter-details";
declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare function enc-details:details()
{
<xf:group ref="instance('i-encs')/*:Encounter[index('r-encs-id')]">
    <h2>Termin für <xf:output ref="*:subject/*:display/@value"></xf:output></h2>
    <table>
        <tr>
            <td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:EncountersToSelect" class="svUpdateMasterTrigger">
                    <xf:label>./. Tagesliste</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:toggle case="enc-main"/>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td><td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:EncountersToSelect" class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:action if="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:start/@value!='' and instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:end/@value!='' and instance('i-dateTime')/*:duration &gt; 0">
                            <xf:send submission="s-submit-encounter-only"/>
                        </xf:action>
                        <xf:action if="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:start/@value=''">
                            <xf:message level="modal">Bitte den Beginn des Termins auf gültigen Wert setzen</xf:message>
                        </xf:action>
                        <xf:action if="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:end/@value=''">
                            <xf:message level="modal">Bitte das Ende des Termins auf gültigen Wert setzen</xf:message>
                        </xf:action>
                        <xf:action if="instance('i-dateTime')/*:duration &lt; 1">
                            <xf:message level="modal">Bitte Beginn vor Ende des Termins legen</xf:message>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td>
        </tr>                    
    </table>
    <hr style="border: none; height: 1px; color: blue; background: blue;"/>
    <table>
        <tr>
            <th>Typ</th>
            <td colspan="3">
                <xf:output id="enc-reasonCode-display" ref="./*:reasonCode/*:coding/*:display/@value"/>
            </td>
        </tr>
        <tr>
            <th>Anlass</th>
            <td colspan="3">
                <xf:textarea id="enc-reasonCode-text" ref="./*:reasonCode/*:text/@value" class="fullareashort">
                </xf:textarea>
            </td>
        </tr>
        <tr>
            <th>Kombi</th>
            <td>
                <xf:output value="choose(string-length(./*:partOf/*:display/@value)&gt;0,./*:partOf/*:display/@value,'nein')"/>
            </td>
        </tr>
        <tr><td colspan="4"><hr style="border: none; height: 1px; color: blue; background: blue;"/></td></tr>
        <tr>
            <th style="font-size: 130%;">Erbringer-Liste</th>
        </tr>
        <tr>
            <td colspan="2">
    <table>
        <thead>
            <tr>
                <th>Bereich</th>
                <th>Rolle</th>
                <th>Erbringer</th>
            </tr>
        </thead>
        <tbody id="r-actors-id" xf:repeat-nodeset="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant">
            <tr>
                <td><xf:output ref="./*:type/*:text/@value"/></td>
                <td><xf:output ref="./*:type/*:coding/*:code/@value"/></td>
                <td><xf:output ref="./*:individual/*:display/@value"/></td>
            </tr>
        </tbody>
    </table>
            </td>
        <td colspan="2">
            <table>
                <tr>
            <th style="vertical-align: middle;">Kalender</th>
            <td colspan="3">
                <xf:select1 ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:type/*:coding/*:code/@value" class="" incremental="true">
                    <xf:itemset nodeset="instance('i-schedules')/*:schedule">
                        <xf:label ref="./*:name/@value"/>
                        <xf:value ref="./*:id/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue
                            ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:type/*:coding/*:display/@value"
                            value="instance('i-schedules')/*:schedule[./*:id/@value=instance('i-encs')/*:Encounter[index('r-encs-id')]/*:type/*:coding/*:code/@value]/*:name/@value"/>
                        <xf:setvalue
                            ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:type/*:text/@value"
                            value="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:type/*:coding/*:display/@value"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr>
        <tr>
            <th style="vertical-align: middle;">Rolle</th>
            <td colspan="3">
                <xf:select1 ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant[index('r-actors-id')]/*:type/*:coding/*:code/@value" class="" incremental="true">
                    <xf:itemset nodeset="instance('i-services')/*:Group">
                        <xf:label ref="./*:name/@value"/>
                        <xf:value ref="./*:code/*:text/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue
                            ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant[index('r-actors-id')]/*:type/*:coding/*:display/@value"
                            value="instance('i-services')/*:Group[./*:code/*:text/@value=instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant[index('r-actors-id')]/*:type/*:coding/*:code/@value]/*:name/@value"/>
                        <xf:setvalue
                            ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant[index('r-actors-id')]/*:type/*:text/@value"
                            value="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant[index('r-actors-id')]/*:type/*:coding/*:display/@value"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr>
        <tr>
            <th style="vertical-align: middle;">Erbringer</th>
            <td colspan="3">
                <xf:select1 ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant[index('r-actors-id')]/*:individual/*:reference/@value" class="" incremental="true">
                    <xf:itemset nodeset="instance('i-users')/*:user">
                        <xf:label ref="./*:display/@value"/>
                        <xf:value ref="./*:reference/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue
                            ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant[index('r-actors-id')]/*:individual/*:display/@value"
                            value="instance('i-users')/*:user[./*:reference/@value=instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant[index('r-actors-id')]/*:individual/*:reference/@value]/*:display/@value"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr>
            </table>
            </td>
        </tr>
        <tr><td colspan="4"><hr style="border: none; height: 1px; color: blue; background: blue;"/></td></tr>
        <tr>
            <th>Datum:</th>
            <td style="vertical-align: middle;">
                <xf:output ref="instance('i-dateTime')/*:date"/>
            </td>
            <th>Dauer (min)</th>
            <td>
                <xf:input ref="instance('i-dateTime')/*:duration" class="medium-input"/>
            </td>
        </tr><tr>
            <th>Beginn:</th>
            <td>
                <xf:select1 ref="instance('i-dateTime')/*:starttime" class="medium-input">
                    <xf:itemset ref="instance('i-e-infos')/*:time/*:code">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                    </xf:itemset>  
                    <xf:action ev:event="xforms-value-changed">
                        <xf:action if="instance('i-dateTime')/*:starttime =''">
                            <xf:setvalue ref="instance('i-dateTime')/*:starttime" value="'08:00:00'"/>
                        </xf:action>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:start/@value"
                            value="concat(instance('i-dateTime')/*:date,'T',instance('i-dateTime')/*:starttime)"/>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant/*:period/*:start/@value"
                            value="concat(instance('i-dateTime')/*:date,'T',instance('i-dateTime')/*:starttime)"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:duration"
                            value="(xs:time(instance('i-dateTime')/*:endtime) - xs:time(instance('i-dateTime')/*:starttime)) div xs:dayTimeDuration('PT1M')"/>
                    </xf:action>
                </xf:select1>
            </td>
            <th>Ende:</th>
            <td>
                <xf:select1 ref="instance('i-dateTime')/*:endtime" class="medium-input">
                    <xf:itemset ref="instance('i-e-infos')/*:time/*:code">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                    </xf:itemset>      
                    <xf:action ev:event="xforms-value-changed">
                        <xf:action if="instance('i-dateTime')/*:endtime =''">
                            <xf:setvalue ref="instance('i-dateTime')/*:endtime" value="'17:00:00'"/>
                        </xf:action>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:end/@value"
                            value="concat(instance('i-dateTime')/*:date,'T',instance('i-dateTime')/*:endtime)"/>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant/*:period/*:end/@value"
                            value="concat(instance('i-dateTime')/*:date,'T',instance('i-dateTime')/*:endtime)"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:duration"
                            value="(xs:time(instance('i-dateTime')/*:endtime) - xs:time(instance('i-dateTime')/*:starttime)) div xs:dayTimeDuration('PT1M')"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr><tr>
            <th>Status</th>
            <td>
                <xf:output id="detail-status" ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value" class=""/>
            </td>
                <!--
                <xf:select1 id="detail-status" ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"
                        class="medium-input">
                    <xf:label>Status:</xf:label>
                    <xf:itemset ref="instance('i-e-infos')/*:status-fhir/*:code">
                        <xf:label ref="./@label-ger"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                    <xf:action if="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value =''">
                        <xf:message level="modal">Leeren Status auf "geplant" zurückgesetzt</xf:message>
                        <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value" value="'planned'"/>
                    </xf:action>
                </xf:select1>
                -->
            <td colspan="2">
                <b>
                <xf:group ref="instance('i-dateTime')/*:duration[.&lt;1]">
                    <xf:output value="'Beginn muss vor Ende liegen!'"
                        style="margin: 10px 0; padding: 10px; border-radius: 3px 3px 3px 3px; color: #D8000C; background-color: #FFBABA;"/>
                </xf:group>
                <xf:group ref="instance('i-dateTime')/*:duration[. &gt; 120]">
                    <xf:output value="'Termin länger als 2 Stunden?!'"
                        style="margin: 10px 0; padding: 10px; border-radius: 3px 3px 3px 3px; color: #9F6000; background-color: #FEEFB3;"/>
                </xf:group>
                </b>
            </td>
        </tr>
    </table>
</xf:group>
};
