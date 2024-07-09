xquery version "3.0";

module namespace help = "http://enahar.org/exist/apps/nabu/help";


declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";


declare function help:showFunctions()
{
    <div>
        <h3>Hilfe:</h3>
        <ul>
            <li><a href="index.html?action=help&amp;topic=overview">Allgemein</a></li>
            <li><a href="index.html?action=help&amp;topic=tickets">Tickets</a></li>
            <li><a href="index.html?action=help&amp;topic=patients">Patienten</a></li>
            <li><a href="index.html?action=help&amp;topic=apps">Termine</a></li>
            <li><a href="index.html?action=help&amp;topic=contacts">Kontakte</a></li>
            <li><a href="index.html?action=help&amp;topic=bugs">Bugs, Anregungen</a></li>
        </ul>
    </div>
};

declare function help:help($topic)
{
    if ($topic='tickets')       then help:tickets()
    else if ($topic='patients') then help:patients()
    else if ($topic='apps')     then help:termine()
    else if ($topic='contacts') then help:contacts()
    else if ($topic='bugs')     then help:bugs()
    else                             help:overview()
};

declare function help:overview()
{
    <div><h3>Allgemeines</h3>
        <p>Der <strong>Nabu SPZ Partner</strong> ist das Nachfolgesystem zu "Paule", gewissermaßen "Paule2".</p>
        <p>Einige Funktionen von "Paule" wie Scheinverwaltung, Leistungserfassung sind auf ORBIS übertragen.</p>
        <p>Der Task-Manager basiert auf einem Ticket-System mit flexibler Rollenzuordnung.
           Damit können der interne Informationsaustausch, Wiedervorlagen und externe Anfragen digital abgebildet und effizient erledigt werden.
           Das Ticket-System ist bereits seit 2014 im Echtbetrieb.</p>
        <p>Die Paule-Daten wurden am 25.11.12015 in Nabu importiert:
            <ul><li>Patienten: vollständige Übernahme in die neue erweiterte Funktionalität</li>
                <li>Termine: aufgespalten in vergangene Termine (Besuche) und zukünftige Termine</li>
                <li>Warteliste: übertragen in die neue Anforderungsliste (ersetzt auch Papier-Laufzettel)</li>
                <li>Sondertermine: entfallen vorläufig, evtl. spätere Reimplemenierung</li>
                <li>Memofeld: ersetzt durch Ticketsystem</li>
                <li>Medizinisch-administrative Synopsis zu Patienten (Version 0.6)</li>
            </ul>
        </p>
        <p>In weiteren Ausbaustufen ("Roadmap") bietet das System:
            <ul>
               <li>Zugriff auf SPZ-Briefe (ab 10/2016; Version 0.7)</li>
               <li>Fallsupervision und Leitlinien-gerechte Surveillance der Patienten in den Spezialsprechstunden (z.B. Cerebralparese; Version 0.8)</li>
           </ul>
        </p>
        <div>
            <h4>Aktuelle Bugs</h4>
            <ul>
            <li>Patienten-Liste zeigt teils alle Zeilen gleichzeitig selektiert, kein Anclicken möglich ("All-Green-Bug").<br/>
               Abhilfe: in Name-Feld "#" oder Leerzeichen anhängen, kurz warten bis Liste aktualisiert, Zeichen wieder wegnehmen.<br/>
               Folgefehler: manchmal steht anschließend der Cursor bzw. selektierte Zeile nicht oben sondern unten, dann ist leider die falsche erste Zeile aktiviert.
               Abhilfe die Zweite: noch einmal Cursor durch Clicken bewegen.<br/>
                Fehler wird demnächst beseitigt</li>
            <li>Manchmal erscheint leeres blau-verlaufendes Browser-Fenster.<br/>
               Abhilfe: oben im Browser auf aktualisieren clicken
            </li>
            <li>In den Filtern wird nur eine begrenzte Anzahl angezeigt, zB 15 Patienten.<br/>
                Also Achtung, wenn ein Patient nicht darunter ist, die Suche verfeinern: NachName, Vorname#ISODatum<br/>
                zB Aslan#2007, sucht Aslan 2007 geboren. </li>
            </ul>
            <h4>Technische Hinweise</h4>
            <p>Groß- und Kleinschreibung durchgehend!!</p>
            <p>Datum wird häufig im ISO8601-Format dargestellt oder in der Eingabe gefordert: YYYY-MM-DD, zB 2015-11-25</p>
            <p>Es gibt in einem Teil der Formulare  keinen <strong>Zurück-Knopf</strong>.<br/>
               Um aus Formularen herauszugehen ohne zu speichern, gibt es zwei Möglichkeiten:<br/>
               - den <strong>Zurück-Button</strong> des Browsers oder<br/>
               - einen Link vom Dashboard (rechte Spalte) benutzen.</p>
            <p>Die <strong>Textfilter</strong> arbeiten mit <em>Reguläre Ausdrücke (regex)</em>.
                Bei einfachem Text passt das Filter auch innerhalb des Suchbegriffs;
                will man unbedingt am Anfang des Textes filtern, sollte man vorne  weg ein"^" benutzen.<br/>
                "Extrem"-Nutzer -kennen regex ohnehin ;-)-, andernfalls hilft der Link
                <a href="http://de.wikipedia.org/wiki/Regul%C3%A4rer_Ausdruck">Reguläre Ausdrücke </a>weiter.</p>
        </div>
    </div>
};

declare function help:tickets()
{
    <div><h3>Infos zum Ticket-System</h3>
        <p>Tickets sind in Grundzügen Emails ähnlich, können aber viel mehr leisten.<br/>
           Sie erfassen kurze Informationen zum Beispiel für Besprechungen, Anrufe, Probleme oder zu erledigende Aufgaben.
           Neue Tickets können für sich selbst (weniger Felder) oder für Andere angelegt werden.
           Wie Emails haben Tickets Felder für Absender, Empfänger, CC, Kurztitel, Freitext und Dringlichkeit.
           Anders als Emails können Tickets verschiedene Aufgaben (Typ) übernehmen, haben eine Fälligkeit,
           einen Bearbeitungsstatus, zusätzliche Ordnungsmerkmale (Tags) und ein Kommentarfeld.
           Sie werden normalerweise "one-way" erledigt. Anfrage-Tickets werden beantwortet.
           Tickets müssen einer Funktion (Queue) und können einer einzelnen Person zugeordnet werden.</p>
        <p>Typischer Ticket-Workflow (Status):<br/>
            - neu: initial, solange keine Rolle oder Person zugewiesen ist<br/>
            - zugewiesen: solange niemand das Ticket angenommen hat<br/>
            - angenommen: jemand will erledigen, hat aber noch nicht<br/>
            - geschlossen: Aufgabe gelöst<br/>
            - wieder geöffnet: kann nur Admin<br/></p>
        <p>Andere Workflows sind möglich (Tip: austesten ;-)</p>
        <p>Wer kann ein Ticket sehen?:<br/>
            - zugewiesene Person (Empfänger, Ass.).<br/>
            - alle Personen mit einer Funktion (Queue), wenn keine einzelne Person zugewiesen.<br/>
            - alle auf der CC-Liste.<br/>
            - der Erzeuger/Sender (Tickets mit Status: zugewiesen o. wieder geöffnet).</p>
        <p>Wer kann ein Ticket bearbeiten?:<br/>
            - alle können bearbeiten, ausser denen, die nur auf der CC-Liste stehen.<br/>
            - die für die Erzeugung relevanten Felder sollten nicht mehr verändert werden.</p>
        <p>Die Ticket-Übersicht zeigt die Eigenschaften:<br/>
            - Priorität, Fälligkeit, Betreff, Typ<br/>
            - Queue, Zugewiesen an, CC, <br/>
            - Tags<br/>
            Die Übersicht kann flexibel sortiert und gefiltert werden.
        </p>
        <p>Durch Anklicken des Tickets in der Übersicht öffnet sich das Ticket mit allen Feldern.<br/>
           Manche Felder sind nicht für alle Nutzer zu ändern.</p>
    </div>
};

declare function help:patients() 
{
    <div><h3>Patienten</h3>
        <p>Die elektronische Patienten-Akte entsteht laaangsam (aktuell 0.6v):</p>
        <dl>
            <dt>Synopsis:</dt>
            <dd>allg.Info, Diagnosen (ca. 10/2016), Besuche, Termine, Anforderungen, Tickets</dd>
            <dt>Demographische Daten</dt>
            <dd>derzeit etwa 27000 Patientendaten</dd>
            <dt>Workflow</dt>
            <dd>Anforderungen (alter Papier-Laufzettel), Besuch, Terminbrief, Ticket, (Diagnosen)</dd>
            <dt>Dokumente</dt>
            <dd>derzeit Infobrief an Eltern darstellbar<br/>
                alte Befunde und Arztbriefe (ca. 80.000 aus V-Laufwerk, ca 10/2016)<br/>
                Briefschreibung (0.9v Ende des Jahres)</dd>   
        </dl>
    </div>
};

declare function help:contacts()
{
    <div><h3>Kontakte/Adressen</h3>
        <p>Kontakte und Adressen können erfasst und abgerufen werden</p>
        <p>Wer kann Kontakte sehen?:<br/>
            - alle</p>
        <p>Wer kann Kontake bearbeiten?:<br/>
            - alle Mitarbeiter des SPZ (realm).</p>
        <p>Kontakte können nach Eigenschaften gefiltert bzw. gesucht werden:<br/>
            - Name (Familienname)<br/>
            - Ort<br/>
            - Tags<br/>
            - Kategorie<br/>
            Die Liste zeigt die <em>aktiven</em> Kontakte, sortiert nach <em>Name</em>.
        </p>
        <p><strong>Details</strong> zeigt die meisten Felder aus der Datenbank an.</p>
        <p><strong>Neuer Kontakt</strong> erzeugt einen leeren Kontakt in der Liste.</p>
        <p><strong>Bearbeiten</strong> öffnet ein -gfls. leeres- Formular mit den Daten des selektierten Listeneintrags
            zum Editieren der relevanten Eigenschaften. <strong>Speichern nicht vergessen!</strong></p>
        <p>Vorbelegungen von Eigenschaften:<br/>
            - Typ: "Person"<br/>
            - Region: "NW"<br/>
            - Land: "DE"<br/>
            - Kategorie: "neu"<br/>
            zur Vereinfachung der Eingabe</p>
        <p>Technischer Hinweis:<br/>
            Das <strong>Details</strong>-Feld zeigt den Kontakt formatiert im sog. <a href="http://microformats.org/wiki/hcard">hcard-Mikroformat</a>.
            Damit müsste per Copy/Paste eine Übernahme in andere vcard-aware Programme (MS-Outlook und andere Email-Programme) möglich sein.<br/>
            (nocht nicht ausprobiert ;-)
        </p>
    </div>
};

declare function help:termine()
{
    <div><h3>Termine</h3>
        <p>Tagesliste:
          <ul>
            <li>Tagestermine nach Datum, Erbringer und Status gefiltert. Verschiedene Sortierungen möglich.</li>
            <li>Status: vorläufig, gebucht, angekommen, aufgenommen, fertig, nicht erschienen, gestrichen</li>
            <li>Bearbeiten: Erbringerwechsel, Infos, Uhrzeit</li>
          </ul>
        </p>
        <p>Graphischer Kalender:
          <ul>
            <li>Filtern nach Service, Erbringer und Datum</li>
            <li>Farben markieren den Status</li>
          </ul>
        </p>
        <p>Anfragen: provisorische Termine, die noch vom Erbringer akzeptiert werden müssen oder auch nicht ;-).
            Ein Terminbrief wird erst nach Buchung erzeugt.
        </p>
    </div>
};

declare function help:bugs()
{
    <div><h3>Probleme, Probleme</h3>
        <p>Einige bekannte Probleme:</p>
        <ul>
            <li>Kontakte: keine?</li>
        </ul>
        <p>Neue Probleme, Anregungen oder Fragen gerne an den admin per Ticket ;-)</p>
    </div>
};