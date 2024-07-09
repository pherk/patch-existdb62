xquery version "3.1";

module namespace sched-util  = "http://enahar.org/exist/apps/eNahar/sched-util";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

declare function sched-util:trigger()
{
    <xf:group appearance="minimal" class="svTriggerGroup">
            <table>
                <tr>
                    <td>
                        <xf:trigger ref=".[count(rrule)=0]" class="svAddTrigger">
                            <xf:label>RRules</xf:label>
                            <xf:hint>fügt RRule hinzu</xf:hint>
                            <xf:action ev_event="DOMActivate">
                                <xf:insert ref="./rrule" context="." origin="instance('i-calInfos')/bricks/rrule"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref=".[count(rrule)>0]" class="svDelTrigger">
                            <xf:label>RRules</xf:label>
                            <xf:hint>löscht RRule</xf:hint>
                            <xf:action ev_event="DOMActivate">
                                <xf:delete ref="./rrule"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref=".[count(rdate)=0]" class="svAddTrigger">
                            <xf:label>RDates</xf:label>
                            <xf:hint>fügt Liste mit zusätzlichen Tagen hinzu</xf:hint>
                            <xf:action ev_event="DOMActivate">
                                <xf:insert ref="./rdate" context="." origin="instance('i-calInfos')/bricks/rdate"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref=".[count(rdate)>0]" class="svDelTrigger">
                            <xf:label>RDates</xf:label>
                            <xf:hint>löscht Liste mit zusätzlichen Tagen</xf:hint>
                            <xf:action ev_event="DOMActivate">
                                <xf:delete ref="./rdate"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref=".[count(exdate)=0]" class="svAddTrigger">
                            <xf:label>ExDates</xf:label>
                            <xf:hint>fügt Liste mit Ausnahme-Tagen hinzu</xf:hint>
                            <xf:action ev_event="DOMActivate">
                                <xf:insert ref="./exdate" context="." origin="instance('i-calInfos')/bricks/exdate"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref=".[count(exdate)>0]" class="svDelTrigger">
                            <xf:label>ExDates</xf:label>
                            <xf:hint>löscht Liste mit Ausnahme-Tagen</xf:hint>
                            <xf:action ev_event="DOMActivate">
                                <xf:delete ref="./exdate"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                </tr>
            </table>
    </xf:group>
};

declare function sched-util:rrules()
{
<xf:group>
    <xf:group ref="./rrule"  class="svFullGroup lined">
        <xf:label>RRules:</xf:label>
        <xf:group class="svFullGroup">
            <xf:select1 id="rrule-freq" ref="./freq/@value" class="short-input">
                <xf:label id="l-rrule-freq" class="svListHeader" >Frequenz:</xf:label>
                <xf:itemset nodeset="instance('i-calInfos')/rrule/freq">
                    <xf:label ref="./@label"/>
                    <xf:value ref="./@value"/>
                </xf:itemset>
                <xf:alert>a string is required</xf:alert>
            </xf:select1>
            <xf:input id="rrule-byWeekNo" ref="./byWeekNo/@value" class="short-input">
                <xf:label id="l-rrule-byWeekNo" class="svListHeader" >byWeekNo:</xf:label>
                <xf:alert>even,odd or a weekno</xf:alert>
            </xf:input>
            <xf:input id="rrule-byDay" ref="./byDay/@value" class="short-input">
                <xf:label id="l-rrule-byDay" class="svListHeader" >byDay:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
        </xf:group>
    </xf:group>
    <xf:group ref=".[count(rrule)=0]" class="svFullGroup lined">
        <xf:output value="'RRules nicht definiert'"/>
    </xf:group>
</xf:group>
};

declare function sched-util:rdates()
{
<xf:group>
    <br/>
    <xf:group ref="./rdate"  class="svHalfGroup lined">
        <xf:label>RDates am:</xf:label>
        <table>
            <tr>
                <td>
                    <xf:repeat id="r-rdates1-id" ref="./*:date" class="svRepeatBlank">
                        <xf:input id="rdates1-date" ref="./@value" >
                            <xf:alert>a valid date is required</xf:alert>
                        </xf:input>
                    </xf:repeat>
                </td>
            </tr>
            <tr>
                    <td>
                        <xf:trigger class="svAddTrigger">
                            <xf:label>Neu</xf:label>
                                <xf:action ev:event="DOMActivate">
                                    <xf:insert at="last()"
                                        nodeset="./*:date"
                                        context="."
                                        origin="instance('i-calInfos')/bricks/date"/>
                                </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref="./date" class="svDelTrigger">
                            <xf:label>Entf</xf:label>
                                <xf:delete ev:event="DOMActivate" 
                                    nodeset="."
                                    at="index('r-rdates1-id')"/>
                        </xf:trigger>
                    </td>
                </tr>
            </table>
    </xf:group>
    <xf:group ref=".[count(rdate)=0]" class="svHalfGroup lined">
        <xf:output value="'RDates nicht definiert'"/>
    </xf:group>
</xf:group>
};

declare function sched-util:exdates()
{
<xf:group>
    <xf:group ref="./exdate"  class="svHalfGroup lined">
        <xf:label>ExDates am:</xf:label>
        <table>
            <tr>
                <td>
                    <xf:repeat id="r-exdates1-id" ref="./*:date[(position() mod 3)=1]" class="svRepeatBlank">
                        <xf:input id="exdates1-date" ref="./@value" >
                            <xf:alert>a valid date is required</xf:alert>
                        </xf:input>
                    </xf:repeat>
                </td>
            </tr>
            <tr>
                    <td>
                        <xf:trigger class="svAddTrigger">
                            <xf:label>Neu</xf:label>
                                <xf:action ev:event="DOMActivate">
                                    <xf:insert at="last()"
                                        nodeset="./*:date"
                                        context="."
                                        origin="instance('i-calInfos')/bricks/date"/>
                                </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger ref="./date" class="svDelTrigger">
                            <xf:label>Entfernen</xf:label>
                                <xf:delete ev:event="DOMActivate" 
                                    nodeset="."
                                    at="index('r-exdates1-id')"/>
                        </xf:trigger>
                    </td>
                </tr>
            </table>
    </xf:group>
    <xf:group ref=".[count(exdate)=0]" class="svHalfGroup lined">
        <xf:output value="'ExDates nicht definiert'"/>
    </xf:group>
</xf:group>
};

declare function sched-util:help()
{
    <xf:switch>
        <xf:case id="nohelp">
            <table>
                <tr>
                    <td>
                        <xf:trigger class="svSubTrigger">
                            <xf:label>Hilfe</xf:label>
                            <xf:toggle case="help"/>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger class="svSaveTrigger">
                            <xf:label>Validieren WIP</xf:label>
                            <xf:send submission="s-validate"/>
                        </xf:trigger>
                    </td>
                </tr>
            </table>
        </xf:case>
        <xf:case id="help">
            <table>
                <tr>
                    <td>
                        <xf:trigger class="svUpdateMasterTrigger">
                            <xf:label>Schließen</xf:label>
                            <xf:action ev_event="DOMActivate">
                                <xf:toggle case="nohelp"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                </tr>
                <tr>
                    <td>
                        <div class="scroll">
                        <ul>
                        <li>Ein Erbringer kann mehrere Subkalender besitzen (Schedules).</li>
                        <li>Schedules erben Eigenschaft von 'globalen' Kalendern. Ein Schedule ist für einen bestimmten Zeitraum definiert (Agendas)</li>
                        <li>Eine Agenda umfasst beliebig viele Slots (Events)</li>
                        <li>Ein Kalender ist also eine verzweigte Baumstruktur: Cal->Schedules->Agendas-Events</li>
                        <li>Ein Event hat einen Namen sowie Anfang und Ende Zeitpunkte</li>
                        <li>Sich wiederholende Events können sowohl durch Regeln (RRule) als auch durch eine Liste von Daten (RDate) definiert werden</li>
                        <li>Events aus der berechneten Menge (RRule+RDate) können durch eine Liste von Daten ausgeschlossen werden (ExDate)</li>
                        <li>Pro Event ist nur eine RRule vorgesehen. Dagegen können beliebig viele RDate/ExDate definiert werden.</li>
                        <li>ExDate haben eine höhere Priorität; ExDate, die nicht zu einem RRule/RDate-Datum passen, werden ignoriert. Duplikate werden eliminiert</li>
                        </ul>
                        <a href="https://tools.ietf.org/html/rfc5545#page-120">Weitere Infos im RFC5545</a>
                        </div>
                    </td>
                </tr>
            </table>
        </xf:case>
    </xf:switch>
};
