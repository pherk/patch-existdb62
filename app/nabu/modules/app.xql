xquery version "3.0";

module namespace app="http://enahar.org/exist/apps/nabu";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace jquery   ="http://exist-db.org/xquery/jquery"         at "resource:org/exist/xquery/lib/jquery.xql";

import module namespace config   ="http://enahar.org/exist/apps/nabu/config"  at "config.xqm";
import module namespace help     ="http://enahar.org/exist/apps/nabu/help"    at "help.xqm";
(: 
import module namespace meeting  ="http://enahar.org/exist/apps/nabu/meeting"          at "../meeting/meeting.xqm";
:)
(: FHIR Resources :)
import module namespace pat         = "http://enahar.org/exist/apps/nabu/patient"       at "../FHIR/Patient/patient.xqm";

import module namespace enc-day     = "http://enahar.org/exist/apps/nabu/encounter-day"      at "../FHIR/Encounter/encounter-day.xqm";
import module namespace enc-accept  = "http://enahar.org/exist/apps/nabu/encounter-accept"   at "../FHIR/Encounter/encounter-accept.xqm";
import module namespace enc-orphans = "http://enahar.org/exist/apps/nabu/encounter-orphans"  at "../FHIR/Encounter/encounter-orphans.xqm";
import module namespace enc-view    = "http://enahar.org/exist/apps/nabu/encounter-view"     at "../FHIR/Encounter/encounter-view.xqm";

import module namespace comm        = "http://enahar.org/exist/apps/nabu/communication" at "../FHIR/Communication/communication.xqm";
import module namespace task        = "http://enahar.org/exist/apps/nabu/task"          at "../FHIR/Task/task.xqm";
import module namespace review      = "http://enahar.org/exist/apps/nabu/review"        at "../FHIR/review/review.xqm";

import module namespace goalrv      = "http://enahar.org/exist/apps/nabu/goalrv"        at "../FHIR/Goal/goal-review.xqm";
import module namespace goal-regrv  = "http://enahar.org/exist/apps/nabu/goal-regrv"    at "../FHIR/Goal/goal-reg-review.xqm";
(: Cross function with MetisID :)
import module namespace practitioner = "http://enahar.org/exist/apps/metis/practitioner" at "/db/apps/metis/FHIR/Practitioner/practitioner.xqm";
import module namespace practrole = "http://enahar.org/exist/apps/metis/practrole" at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole.xqm";
import module namespace organization ="http://enahar.org/exist/apps/metis/organization"  at "/db/apps/metis/FHIR/Organization/organization.xqm";
import module namespace r-practrole       = "http://enahar.org/exist/restxq/metis/practrole"
                          at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
(: 

import module namespace order       = "http://enahar.org/exist/apps/nabu/order"         at "../FHIR/Order/order.xqm";
:)
declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

(:~
 : This is a templating function. It will be called by the templating module if
 : it encounters an HTML element with a class attribute: class="app:test". The function
 : has to take exactly 3 parameters.
 : 
 : @param $node the HTML node with the class attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function app:main($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic)
{
    let $server := request:get-header('host')
    (:  let $log := util:log-app('DEBUG','apps.nabu', ($server,"?", $action, ":", $id, ":", $filter, ":", $self, ":", $status, ":", $topic)) :)
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $perms   := r-practrole:perms($prid)/fhir:perm

    let $isGuest :='perm_get-patient-only' = $perms
    return
        if ($isGuest)
        then pat:listPatients($id)
        else
    switch ($action)
        case "listTasks"    return  task:listTasks($filter)
        case "newTask"      return  task:newTask($self,$topic)
        case "editTask"     return  task:editTask($id,$self,$topic)
        case 'help'         return  help:help($topic)
(: 
        case 'listMeetings' return  meeting:listMeetings($node, $model, $id)
        case 'showMeeting'  return  meeting:showMeeting($node, $model, $id)
        case 'newMeeting'   return  meeting:newMeeting($node, $model, $id)
:)
        case 'listPatients' return  pat:listPatients($id)
        
        case 'listContacts' return  practitioner:listContacts()
        case 'listOrganizations' return  organization:listOrganizations()
        case 'listUsers' return  practrole:listUsers()
(:         
        case 'listOrders'   return  order:listOrders($filter)
        case 'editOrders'    return  order:editOrdersByPID($id)
:)        
        case 'listEncounters'   return enc-day:list()
        case 'viewCalendar'     return enc-view:view()
        case 'acceptEncounters' return enc-accept:accept()

        case 'listGoals'    return goalrv:review($id,$topic,$filter)
        
        case "showComms"    return  comm:showComms($filter)
        
        default
            return task:listTasks('open')
        
};

declare function app:info($node as node(), $model as map(*), $action, $id, $topic)
{
    let $today := adjust-date-to-timezone(current-date(),())
    return
(<div style="display:none;">
    <xf:model id="m-infos" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance id="i-control-center">
            <data xmlns="">
                <currentForm/>
                <changed>false</changed>
                <language>de</language>
            </data>
        </xf:instance>
    </xf:model>
    <xf:group id="controlCenter" model="m-infos">
        <xf:action ev:event="unload-subform" model="m-infos" if="string-length(bf:instanceOfModel('m-infos','i-control-center')/*:currentForm) &gt; 0">
            <xf:send submission="s-submit-subject" if="bf:instanceOfModel('m-infos','i-control-center')/*:changed='true'"/>
            <xf:message level="ephemeral">unloading subform...</xf:message>
            <xf:load show="none" targetid="infopane"/>
            <xf:setvalue ref="bf:instanceOfModel('m-infos','i-control-center')/*:currentForm" value="''"/>
        </xf:action>
        <xf:action ev:event="clear-currentform" model="m-infos">
            <xf:setvalue ref="bf:instanceOfModel('m-infos','i-control-center')/*:currentForm" value="''"/>
        </xf:action>
    </xf:group>
</div>
,<div>
    <xf:group class="svFullGroup bordered">
        <xf:label>Übersicht</xf:label><br/>
        <table>
        <tr>
            <td colspan="1">
                <xf:trigger class="svAddTrigger">
                    <xf:label>nSPZ KiKl</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-infos','i-control-center')/*:currentForm" value="'info-spz-synopsis'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'xforms-snippets/info-spz-synopsis.xml'"/>
                        </xf:load>
                        <xf:toggle case="t-spzMenue"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td colspan="1">
                <xf:trigger class="svAddTrigger">
                    <xf:label>Erbringer</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-infos','i-control-center')/*:currentForm" value="'info-user-synopsis'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'xforms-snippets/info-user-synopsis.xml'"/>
                        </xf:load>
                        <xf:toggle case="t-userMenue"/>
                    </xf:action>
                </xf:trigger>
            </td>
            </tr>
        <tr>
            <td>
                <xf:switch>
                    <xf:case id="t-spzMenue">
                        { app:info-spz-menue() }
                    </xf:case>
                    <xf:case id="t-userMenue">
                        { app:info-user-menue() }
                    </xf:case>
                </xf:switch>
            </td>
            <td colspan="5" rowspan="5">
                <br/>
                <xf:group id="infopane" class="svSubForm bordered"></xf:group>
            </td>
        </tr>
        </table>
    </xf:group>
</div>
)
};

declare function app:info-spz-menue()
{
    <xf:group>
        <table>
                <thead>
                    <th>nSPZ</th>
                </thead>
                <tbody>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Allg. Info</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-infos','i-control-center')/*:currentForm" value="'info-spz-synopsis'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'xforms-snippets/info-spz-synopsis.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Sprechstunden</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-infos','i-control-center')/*:currentForm" value="'info-spz-ambulanz'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'xforms-snippets/info-spz-ambulanz.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                </tbody>
            </table>
    </xf:group>
};

declare function app:info-user-menue()
{
    <xf:group>
        <table>
                <thead>
                    <th>Erbringer</th>
                </thead>
                <tbody>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Allg. Info</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-infos','i-control-center')/*:currentForm" value="'info-user-synopsis'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'xforms-snippets/info-user-synopsis.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Präsenz</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-infos','i-control-center')/*:currentForm" value="'info-user-online'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'xforms-snippets/info-user-online.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                </tbody>
            </table>
    </xf:group>
};

declare function app:main-review($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic) {
let $server := request:get-header('host')
(:  let $log := util:log-app('DEBUG','apps.nabu', ($server,"?", $action, ":", $id, ":", $filter, ":", $self, ":", $status, ":", $topic)) :)
return
    switch ($action)
        case "reviewTagged"    return  review:tagged($filter)
        default
            return review:tagged('')
};     

declare function app:main-print-queue($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic) {
let $server := request:get-header('host')
(:  let $log := util:log-app('DEBUG','apps.nabu', ($server,"?", $action, ":", $id, ":", $filter, ":", $self, ":", $status, ":", $topic)) :)
return
    switch ($action)
        case "listComms"    return  comm:listComms($filter)
        default
            return comm:listComms('open')
        
};

declare function app:main-orphan-appointments($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic)
{
    enc-orphans:orphan-view() 
};

declare function app:main-print-daylist($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic)
{
    let $today := adjust-date-to-timezone(current-date(),())
    return
(<div style="display:none;">
    <xf:model id="m-appointment" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance xmlns="" id="i-dateTime">
            <data>
                <startdate>{$today}</startdate>
                <enddate>{$today}</enddate>
                <nofd>1</nofd>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-dateTime')/*:startdate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:enddate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:nofd" type="xs:integer" constraint=". &gt; 0"/>
    </xf:model>
</div>
,<div>
    <xf:group class="svFullGroup bordered">
        <xf:label>Listen</xf:label><br/>
        <xf:input ref="instance('i-dateTime')/*:startdate" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'">
            <xf:label class="svListHeader">Start:</xf:label>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-dateTime')/*:nofd"
                    value="(xs:date(instance('i-dateTime')/*:enddate) - xs:date(instance('i-dateTime')/*:startdate)) div xs:dayTimeDuration('P1D') + 1"/>
                </xf:action>
        </xf:input>
        <xf:input ref="instance('i-dateTime')/*:enddate" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'">
            <xf:label class="svListHeader">Ende:</xf:label>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-dateTime')/*:nofd"
                    value="(xs:date(instance('i-dateTime')/*:enddate) - xs:date(instance('i-dateTime')/*:startdate)) div xs:dayTimeDuration('P1D') + 1"/>
                </xf:action>
        </xf:input>
        <xf:output ref="instance('i-dateTime')/*:nofd">
            <xf:label>Anzahl Tage</xf:label>
        </xf:output>
        <table>
            <tr>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Archiv</xf:label>
                        <xf:load show="new">
                            <xf:resource value="concat('/exist/restxq/nabu/encs2pdf?realm=kikl-spz&amp;loguid=u-admin&amp;lognam=print-bot&amp;rangeStart=',instance('i-dateTime')/*:startdate,'&amp;rangeEnd=',instance('i-dateTime')/*:enddate,'&amp;status=planned&amp;status=tentative&amp;_sort=archive')"/>
                        </xf:load>
                    </xf:trigger>
                </td>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Termine</xf:label>
                        <xf:load show="new">
                            <xf:resource value="concat('/exist/restxq/nabu/encs2pdf?realm=kikl-spz&amp;loguid=u-admin&amp;lognam=print-bot&amp;rangeStart=',instance('i-dateTime')/*:startdate,'&amp;rangeEnd=',instance('i-dateTime')/*:enddate,'&amp;status=planned&amp;status=tentative&amp;_sort=perDay')"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
        </table>
    </xf:group>
</div>
)
};

declare function app:news($node as node(), $model as map(*)) {
<div>
    <h3>Aktuelles (v1.3, FHIR 4.3)</h3>
    <dl>
        <dt>15.03.2024 Update auf FHIR R4.3 ("Iden des März")</dt>
        <dd><ul>
              <li>14 Ressourcen wurden überarbeitet und die entsprechenden Daten migriert (ca. 700.000 Objekte).</li>
              <li>Aktuell keine neue Funktionalität auf Nutzerseite.</li>
            </ul>
        </dd>
    </dl>
    <dl>
        <dt>15.11.2022 Cave-Eintrag, Patienten über 18 Jahre</dt>
        <dd>
            <ul>
                <li>Seit heute besteht die Möglichkeit einen oder mehrere Cave-Eintrag in der Demographie zu erstellen (Demographie->Infos).
                    Der Eintrag kann klassifiziert werden (Select-Feld links oben) und besitzt einen Status (Select-Feld links unten; default: active).
                    <span style='color:red;'>Nur aktive Cave-Einträge</span> werden in der Patienten-Synopsis oberhalb des Namen in <span style='color:red;'>rot</span> dargestellt.</li>
                <li>Für Patienten über 18 Jahre wird die Dauer der Genehmigung durch die Versicherung angezeigt.
                    Die Anträge werden von der Verwaltung administrativ bearbeitet (per script)</li>
            </ul>
        </dd>
        <dt>30.09.2020 Patienten-Ziele aktiv</dt>
        <dd>
            <ul>
                <li>Im Workflow-Menue->Ziele können individuelle Ziel für Patienten verfolgt werden. Alle Ziele eines Erbringers sind über das Side-Menue (Ziele) erreichbar, alle Ziele aller Patienten über neue administrative Seite. Auch der Anmelde-Worklflow wird jetzt über Ziele gesteuert.</li>
                <li>Account- und User Management: Probleme sollten beseitigt sein</li>
            </ul>
        </dd>
<!--
        <dt>10.07.2020 FHIR 4.0.1</dt>
        <dd>
            <ul>
                <li>Die Nabu&amp;Co-Daten basieren bekanntlich auf dem internationalen FHIR-Standard. In den letzten Wochen wurden die einzelnen Resourcen (aktuell n=24) von v3 auf v4.04 umstrukturiert und die Web-Oberfläche angepasst. Das meiste geschah inkrementell im Produktionsbetrieb. Die Account- und Nutzer-Daten sind komplett neu aufgebaut.</li>
                <li>Wenn noch Merkwürdigkeiten beobachtet werden oder Verbesserungen gewünscht sind, bitte den Admin informieren</li>
            </ul>
        </dd>
-->
        <dt>17.10.2019 Sozial-Infos</dt>
        <dd>
            <ul>
                <li>Sozialdaten können in einem Befundformular eingegeben werden (unter Workflow)</li>
                <li>Ob Sozialdaten vorhanden sind, kann in der Synopsis abgefragt werden</li>
            </ul>
        </dd>
<!--
        <dt>15.04.2019 Kalender</dt>
        <dd>
            <ul>
                <li>jetzt auch durch Komma-getrennte KW-Liste definierbar: zB. byWeekNo=25,29,33</li>
                <li>Martakis-Kalender ab 1.6.19 freigeschaltet</li>
            </ul>
        </dd>
-->
        <dt>10.03.2019 Update v0.9.15 Briefimport</dt>
        <dd>
            <ul>
                <li>Mysteriöses "Abbrechen" von Briefen aufgeklärt und beseitigt. Betraf wohl nur Briefe von 2018.</li>
                <li>greedy merging von Paragraphen reduziert (zB nach "Kindergarten:", "Anamnese:")</li>
                <li>ReImport wieder möglich, um bereits importierte Briefe zu verbessern</li>
            </ul>
        </dd>
        <dt>02.12.2018 Update v0.9.12</dt>
        <dd>
            <ul>
                <li>Patientensuche 3-5x schneller</li>
                <li>neue Plan- und Activity-Definitions</li>
                <li>intern: Conformance zum FHIR-Standard 3.0.1, JSON-Schnittstelle</li>
            </ul>
        </dd>
        <dt>25.08.2018 weitere Neuerungen</dt>
        <dd>
            <ul>
                <li>Orphanet, Human Phentotype Ontology (HPO) und ICFnl-Daten verfügbar</li>
                <li>Termine klassifiziert: Kombi, Neu</li>
                <li>Listen (Archiv,Tagesliste): Generierung optimiert, provisorische Termine fehlten</li>
                <li>Shortcuts to Patient</li>
                <li>Golem lives!</li>
                <li>Q/QR handling updated</li>
                <li>EpisodeOfCare, CareTeam: CareManager, Problemhistorie</li>
            </ul>
        </dd>
        <dt>10.04.2018 Neuerungen (v0.9alpha)</dt>
        <dd>
            <ul>
                <li>Offene Besuche als Liste sichtbar und einfacher zu bearbeiten</li>
                <li>CarePlan Activities cancellable, Status Sichtbarkeit verbessert, Anlass Änderungen in CarePlan sichtbar</li>
                <li>ReOrder'd Filter in eNahar</li>
                <li>Spontanbesuch mit CarePlan verlinkt</li>
                <li>Guest account mit eingeschränkter Funktionalität</li>
                <li>Patient über 18.LJ in Info/Demographie</li>
            </ul>
        </dd>
<!--
        <dt>2.11.2017 (Workflow update)</dt>
        <dd>
            <ul>
                <li>CarePlan Info verbessert:<br/>Terminvereinbarungen -> Progress-Notes<br/>Besuch/Ticket Kommentar -> Outcome</li>
                <li>Interaktion der Workflow-Resourcen zum zweiten Mal neue Strukturen, viele Code-Änderungen</li>
            </ul>
        </dd>
        <dt>11.10.2017 (Patentensuche, Workflow update)</dt>
        <dd>
            <ul>
                <li>Patientensuche erheblich beschleunigt. Suche mit RegExp aktuell nur noch mit voller Spec (Geburtsdatum mindestens Jahr plus '-')</li>
                <li>Interaktion der Workflow-Resourcen neu strukturiert, viele Code-Änderungen</li>
                <li>Nicht alle Funktionen im Produktivsystem testbar; neue Fehler möglich/wahrscheinlich, bitte um Infos</li>
                <li>Leere CarePlans gelöscht</li>
                <li>Alte offene Anforderungen sowie Anforderungen mit geplanten Termin in Default-CarePlans importiert (Titel: 'Request Import', n=4050)</li>
                <li>Datenbank Update auf eXistDB v3.6</li>
            </ul>
        </dd>
        <dt>21.08.2017 (Codename "Freak Out")</dt>
        <dd>
            <ul>
                <li>CarePlan als zentrale Koordinationsstelle für Aktivitäten rund um den Patienten:
                  <ul>
                    <li>Diagnosen (Condition), Ziele (Goal) und Patientengruppen (Condition/Tag)</li>
                    <li>Anforderungen (Order)</li>
                    <li>Tickets (Task)</li>
                  </ul>
                </li>
                <li>Neue Infrastruktur:
                  <ul>
                    <li>Tickets jetzt Tasks</li>
                    <li>Termine (Appointment) mit Besuch (Encounter) vereint</li>
                    <li>FHIR-Resourcen: CarePlan, PlanDefinition, ActivityDefinition, Goal, Task, ClinicalImpression, Observation, Questionnaire und QuestionnaireResponse implementiert</li>
                  </ul>
                </li>
                <li>NeoDat und BayleIII-Import; 285 resp. 1500 Datensätze. Daten unter Workflow/Befunde sichtbar. Weitere Formular-Daten bei Bedarf möglich</li>
                <li>Namenwechsel und Suche nach alten Patientennamen ('\' vor Familiennamen) sowie nach ORBIS-PNR möglich (':')</li>
                <li>Neue Patienten automatisch als "neu" getagged (Anmelderunde, Review)</li>
                <li>Anforderung: FaFue und Schedule verfügbar</li>
                <li>Briefe von 2000-heute importiert</li>
                <li>Weitere Schnittstellen (JSON, Download aller Daten eines Patienten)</li>
            </ul>
        </dd>
        <dt>20.09.2016 Druckliste</dt>
        <dd>
            <ul>
                <li>Infobriefe unter Dokumente einsehbar</li>
                <li>zusätzliche Info für Brief; Standardtexte verfügbar, Text frei editierbar</li>
                <li>interne Notiz -zB. tel Info an Eltern-</li>
                <li>Briefe müssen vom Ersteller vidiert oder gelöscht werden</li>
                <li>Verwaltung durckt diese dann ohne weitere Prüfung aus und verschickt per Post.</li>
            </ul>
        </dd>
        <dt>08.08.2016</dt>
        <dd>Kleine Verbesserungen:
            <ul>
                <li>Patientensuche jetzt auch als <strong>Name,Vorname#GebDat</strong> möglich. Dauert etwas länger als Suche nur nach Name.</li>
                <li>Ticket zu Patient auch über Patient->Workflow möglich.</li>
            </ul>
        </dd>
        <dt>27.06.2016</dt>
        <dd>
            Erbringerwechsel über Terminbearbeitung (im Trend zur Zeit ;-):<br/>
            <ul>
                <li>bitte jetzt neu auch den Anlass bearbeiten (fehlte bisher)</li>
            </ul>
        </dd>
        <dt>25.06.2016 ReOrder</dt>
        <dd>
            <ul>
                <li>Bei älteren Terminen, die ge-cancelled werden, wird das Anforderungsdetail nicht automatisch geöffnet, sondern steht als erledigt in der Liste.</li>
                <li>Kombi-Details werden (noch) nicht automatisch reordered.</li>
            </ul>
        </dd>
        <dt>3.06.2016:</dt>
        <dd>
            <ul>
                <li>Patienten
                    <ul>
                        <li>Neues Design, Formulare ohne Contextverlust</li>
                        <li>Komplett neu programmiert.</li>
                    </ul>
                </li>
                <li>Tickets
                    <ul>
                        <li>neue Tickets sind mit "+" markiert</li>
                        <li>Tickets per Patient jetzt über Synopsis sichtbar</li>
                    </ul>
                </li>
                <li>bitte beachten:
                    <ul>
                        <li>Patientensuche schneller und Sortierung nach Name, Vorname<br/>
                            sucht allerdings nur noch von Anfang des Nachnamens<br/>
                            Reguläre Ausdrücke nur noch in Kombi mit Geburtsdatum
                            </li>
                    </ul>
                </li>
            </ul>
        </dd>
        <dt>22.04.2016:</dt>
        <dd>
            <ul>
                <li>Fälligkeitsdatum für Tickets (Bug)</li>
                <li>Ticket-Liste zeigt deutsches Fälligkeitsdatum und Assigned-Status</li>
            </ul>
        </dd>
        <dt>14.03.2016:</dt>
        <dd>
            <ul>
                <li>Datum in Filtern eingedeutscht, Uhrzeit in Halbstunden-Raster</li>
                <li>Ablehnen von Terminanfragen öffent alte Anforderung</li>
                <li>Termin "reorder": akt.Termin canceln, neue Anforderung</li>
                <li>Besuch eintragen</li>
                <li>Drucken von Listen in Nabu Admin per Button (Archiv, Tagesliste</li>
            </ul>
        </dd>
        <dt>14.02.2016:</dt>
        <dd>
            <ul>
                <li>Uhrzeit von Termin editierbar (Terminliste -&gt; Bearbeiten)</li>
                <li>Termine in Kalenderansicht</li>
            </ul>
        </dd>
        <dt>31.01.2016:</dt>
        <dd>
            <ul>
                <li>Fertige und gestrichene Termine in Liste sichtbar (Status-Filter)</li>
                <li>Druck-Jobs: Einzeldruck jetzt mit Abschluss.</li>
                <li>Provisorische Termine (zB in RegAZ) müssen vidiert werden</li>
                <li>Vidierte Termine und Extrabriefe in Druckjobs rot markiert</li>
            </ul>
        </dd>
-->
    </dl>
</div>
};

declare function app:dashboard($node as node(), $model as map(*), $action, $cal) {
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $perms  := r-practrole:perms($prid)/fhir:perm
    let $loggrp := $logu/fhir:specialty/fhir:coding[fhir:system/@value="http://hl7.org/fhir/vs/practitioner-specialty"]/fhir:code/@value/string()
    let $isGuest :='perm_get-patient-only' = $perms
    return
        if ($isGuest)
        then
            <div><br/>
            <p>{$unam}; it is {current-dateTime()}</p>
            <p>Sie sind als Gast eingeloggt.</p>
            <p>Herzlich Willkommen!</p>
            <p>Bitte beachten Sie die Datenschutzbestimmungen der Unikliniken Köln.
            Insbesondere sind Sie nur dann berechtigt, Patienten-bezogene Informationen einzusehen, wenn eine Einverständnis dafür vorliegt und
            Sie an der Versorgung des Patienten beteiligt sind.</p>
            <p>Ihr SPZ Team</p>
            <p></p>
            <p>Hinweise zur flexiblen Patientsuche <a href="http://neuro-wiki.uk-koeln.lokal/spz/Patientensuche"> -> im Wiki</a></p>
            </div>
        else
            <div><br/>
                <p>{$unam}:{$loggrp}; {current-dateTime()}</p>
    {task:showFunctions()}
    {pat:showFunctions($uid)}

    {goalrv:showFunctions($uid)}

    {enc-day:showFunctions()}
    {comm:showFunctions()}
    {practitioner:showFunctions()}
<!--
    {meeting:showFunctions($uid)}

    <div class="ui-widget">
        <h3>Suche: </h3>
                  <jquery:input name="autotest" id="autotest" value="">
                    <jquery:autocomplete url="modules/autocomplete.xql"
                        width="300" multiple="false"
                        matchContains="false"
                        paramsCallback="autocompleteCallback">
                    </jquery:autocomplete>
                </jquery:input>
    </div>
-->
    {help:showFunctions()}
</div>
};

declare function app:goalreview($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic) {
let $server := request:get-header('host')
let $log := util:log-app('DEBUG','apps.nabu', ($server,"?", $action, ":", $id, ":", $filter, ":", $self, ":", $status, ":", $topic))
return
    switch ($topic)
        case "topic"    return  goalrv:review($id,$topic,$filter)
        default
            return goalrv:review($id,'',$filter)
};     

declare function app:goal-regreview($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic) {
let $server := request:get-header('host')
let $log := util:log-app('DEBUG','apps.nabu', ($server,"?", $action, ":", $id, ":", $filter, ":", $self, ":", $status, ":", $topic))
return
    switch ($topic)
        case "topic"    return  goal-regrv:review($topic)
        default
            return goal-regrv:review('')
};     
