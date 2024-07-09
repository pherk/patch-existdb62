xquery version "3.0";

module namespace app="http://enahar.org/exist/apps/enahar/app";

import module namespace config    = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";
import module namespace cal       = "http://enahar.org/exist/apps/enahar/edit"   at "../cal/cal.xqm";
import module namespace order     = "http://enahar.org/exist/apps/enahar/order"  at "../order/ical-order.xqm";
import module namespace new-order     = "http://enahar.org/exist/apps/enahar/order"  at "../order/new-order.xqm";
import module namespace sched = "http://enahar.org/exist/apps/enahar/schedule"   at "../schedule/schedules.xqm";

import module namespace r-practrole  = "http://enahar.org/exist/restxq/metis/practrole"   at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";


declare function app:news($node as node(), $model as map(*)) {
<div>
    <h3>Aktuelles v0.9.1</h3>
    <dl>
        <dt>07.03.2023 Spezialambulanzen</dt>
        <dd>
            <ul>
                <li>Bei der Terminsuche werden Spezialambulanzen mitberücksichtigt,
                wenn Slots innerhalb der nächsten zwei Wochen vorhanden sind.</li>
                <li>Die Suchmodi funktionieren für die Spezialambulanzen wie üblich.</li>
            </ul>
        </dd>
        <dt>22.08.2018 Nabu Workflow v0.9.7</dt>
        <dd>
            <ul>
                <li>Meetings in Kalender integriert, blockieren Terminierung</li>
                <li>Schedule, Meetings XForms revisited</li>
                <li>Neue Suchmodi: 'BisTermin', 'Parallel', 'Pressing'</li>
                <li>Switch to Patient Tab</li>
                <li>ReOrder'd Filter</li>
            </ul>
        </dd>
        <dt>02.11.2017 Nabu Workflow v0.8</dt>
        <dd>
            <ul>
                <li>Order structural update, workflow adaptation</li>
            </ul>
        </dd>
        <dt>18.12.2016 Bugs, Verbesserung</dt>
        <dd>
            <ul>
                <li>Abstand zwischen sequentiellen Kombiterminen auf eine Stunde reduziert</li>
                <li>Gleichzeitige Kombitermine mit unterschiedlicher Dauer teils nicht gefunden (Dank an Boeckmann)</li>
                <li>Termin nicht vereinbar bei partieller Abwesenheit (Dank an Flemming, Jansen)</li>
                <li>Clonen von Agendas (Admin)</li>
            </ul>
        </dd>
<!--
        <dt>14.09.2016 Bugs</dt>
        <dd>
            <ul>
                <li>Priorität nicht sichtbar</li>
                <li>Psych-Termine ohne Kalender gesucht, vereinzelt falsch</li>
            </ul>
        </dd>
        <dt>12.08.2016</dt>
        <dd>
            <ul>
                <li>Zahl der Vorschläge auf 15 erhöht, um Termine zu späteren Uhrzeiten ermöglichen</li>
                <li>Name,Vorname#GebDat Suche wie in Nabu</li>
                <li>Überbuchung bei 8:00 Uhr EEGs (beseitigt)</li>
                <li>Detail-ID nach Bearbeitung teils nicht eindeutig -> komplexe Folgefehler beim Terminieren, ReOrder (beseitigt)</li>
            </ul>
        </dd>
        <dt>02.06.2016</dt>
        <dd>
            <ul>
                <li>Terminsuche nur für Funktion, d.h. ohne Erbringer/Kalender-Vorgabe möglich
                    <ul>
                        <li>Suchdauer steigt proportional mit der Zahl der Details und der Erbringerkalender<br/>
                    (zB. bei 4 Details ohne Erbringer ca. 30s!)</li>
                        <li>ohne Kalenderangabe werden alle Kalender der angegebenen Erbringer (außer ReguläreAZ und Reserve) berücksichtigt;<br/>
                        daher sollte zumindest der Kalender angegeben werden, um die Suche einzugrenzen</li>
                    </ul>
                </li>
                <li>Terminvarianten erweitert:
                    <ul>
                        <li>Aktive Detail über Einkaufswagen auswählen</li>
                        <li>Termin an einem Tag ('KombiTermin') mit Haken ('Kettensymbol') versehen; daneben weitere Termine an anderen Tagen möglich.</li>
                        <li>Reihenfolge über Wunschdatum und Laufende Nummer ('LfdNo')<br/>
                            LfdNo wird nur bei Terminen an einem Tag berücksichtigt.<br/>
                            interdisziplinär (gleiche LfdNo) oder sequentiell (LfdNo).
                        </li>
                    </ul>
                </li>
            </ul>
        </dd>
        <dt>20.04.2016</dt>
        <dd>
            <ul>
                <li>Offene Termine sichtbar</li>
                <li>Berechnete Fälligkeit in Liste sichtbar</li>
                <li>Service und Erbringer Änderung lädt jetzt Erbringer-Kalender</li>
                <li>"Termin geht nicht trotz Lücke im Kalender"-Fehler gefunden und beseitigt!!</li>
            </ul>
        </dd>
        <dt>14.02.2016</dt>
        <dd>
            <ul>
                <li>mehr Platz mit 2-seitigen Layout ohne Kalender: Anforderungen - Details/Terminsuche</li>
                <li>Termine gibt Fehler und Info zurück</li>
            </ul>
        </dd>
        <dt>31.01.2016</dt>
        <dd>
            <ul>
                <li>Suche auf 14 Tage verlängert</li>
                <li>Provisorische Termine vidierbar</li>
            </ul>
        </dd>
-->
    </dl>
</div>
};

(:~
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function app:main($node as node(), $model as map(*)) 
{
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $perms := r-practrole:perms($loguid)/fhir:perm
    let $hasMA := 'perm_makeAppointment' = $perms
    let $isGuest := 'perm_get-patient-only' = $perms
    return
    if ($hasMA and not($isGuest))
    then
        order:listOrders()
    else <h4>Sie sind leider nicht authorisiert Termine zu vergeben</h4>
};

(:~
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function app:main2($node as node(), $model as map(*)) 
{
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $perms := r-practrole:perms($loguid)/fhir:perm
    let $hasMA := 'perm_makeAppointment' = $perms
    let $isGuest := 'perm_get-patient-only' = $perms
    return
    if ($hasMA and not($isGuest))
    then
        new-order:listOrders()
    else <h4>Sie sind leider nicht authorisiert Termine zu vergeben</h4>
};


declare function app:main-admin($node as node(), $model as map(*), $action as xs:string*, $what as xs:string*) 
{
    let $prefix := tokenize($what,'\-')[1]
    let $type   := tokenize($what,'\-')[2]
    return
        switch ($action)
        case "edit" return 
                switch($prefix)
                case 'cal' return cal:edit($type)
                case 'sched' return sched:schedules($type)
                default return app:admin()
        default return app:admin()
};

declare function app:admin() 
{
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $perms := r-practrole:perms($loguid)/fhir:perm
    let $hasUC := 'perm_updateCalendar' = $perms
    return
    if ($hasUC)
    then
        <div>
            <h4>Editieren von Resourcen</h4>
            <ul>
                <li>Calender von Personen und Funktionen
                    <ul>
                        <li>
                            <a href="./admin.html?action=edit&amp;what=cal-service">Sprechstunden</a>
                        </li>
                        <li>
                            <a href="./admin.html?action=edit&amp;what=cal-meeting">Meetings</a>
                        </li>
                        <li>
                            <a href="./admin.html?action=edit&amp;what=cal-worktime">Arbeitszeiten</a>
                        </li>
                    </ul>
                </li>
                <li>Globale Resourcen
                    <ul>
                        <li>
                            <a href="./admin.html?action=edit&amp;what=sched-service">Schedules</a>
                        </li>
                        <li>
                            <a href="./admin.html?action=edit&amp;what=sched-meeting">Meetings</a>
                        </li>
                    </ul>
                </li>
            </ul>
        </div>
    else
        <div>Sie haben keine Admin-Rechte für eNahar</div>
};
