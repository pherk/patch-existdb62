xquery version "3.0";
module namespace letter = "http://enahar.org/exist/apps/nabu/letter";


import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace tei = "http://www.tei-c.org/ns/1.0";




declare variable $letter:test-body-appinfo :=
            <body xmlns="http://www.tei-c.org/ns/1.0" type="letter">
                <opener>
                    <address>
                        <addrLine>Familie Anhelm,</addrLine>
                        <addrLine>Georgstr. 36</addrLine>
                        <addrLine>50374 Erftstadt</addrLine>
                    </address>
                    <dateline>
                        <name type="place">Köln, </name>
                        <date when="2015-10-19">19. Oktober 2015</date>/Nabu</dateline>
                    <subject>Aktuelle Terminübersicht: Anhelm, Nadine *1998-03-25</subject>
                    <salute>Sehr geehrte Familie Anhelm,</salute>
                </opener>
                <div type="letter-body">
                    <p>für Sie sind folgende Termine reserviert:</p>
                    <div>
                    <list type="gloss">
                            <label>
                                <hi rend="bold">Bereits vereinbarte Termine</hi>
                            </label>
                            <item>
                                <list rend="bulleted">
                                    <item>21. Oktober 2015 - 14:00 - Neurogenetik</item>
                                </list>
                            </item>
                            <label>
                                <hi rend="bold">Neue Termine:</hi>
                            </label>
                            <item>
                                <list rend="bulleted">
                                    <item>3. Dezember 2015 - 8:00 - EEG</item>
                                    <item>3. Dezember 2015 - 9:30 - Ambulanz</item>
                                </list>
                            </item>
                    </list>
                    </div>
                    <p>Wichtig für Gesetzlich Versichterte: Ohne Überweisungsschein für "Sozialpädiatrisches Zentrum"
                        können wir Sie leider nicht behandeln (gültig für das aktuelle Quartal)!</p>
                    <p>Bitte melden Sie sich an dem Tag in der Anmeldung der Kinderklinik an (unten im Erdgeschoss).
                       Kommen Sie wegen der Anmeldung etwas früher (ca. 15min), damit Sie rechtzeitig zum Termin oben im SPZ sind.</p>
                    <p>Bringen Sie bitte alle Unterlagen zu den Problemen des Kindes mit.</p>
                </div>
                <closer>
                    <salute>mit freundlichen Grüßen</salute>
                    <signed>
                        <p>
                            <name nymRef="#kikl-spz">SPZ der Kinderklinik</name>
                        </p>
                    </signed>
                </closer>
                <postscript/>
            </body>;
            
declare variable $letter:test-body-arzt :=
    <body xmlns="http://www.tei-c.org/ns/1.0" type="letter">
        <opener>
            <address>
                <addrLine>Dr.med. Schreck</addrLine>
                <addrLine>Ebertplatz 13</addrLine>
                <addrLine>50777 Köln</addrLine>
            </address>
            <dateline><name type="place">Köln, </name><date when="2013-10-18">18.10.2013</date>/PH</dateline>
            <subject>Beta, Alfredo *1.01.2012</subject>
            <salute>Sehr geehrter Herr Dr.med. Schreck,</salute>
        </opener>
        <div type="letter-body">
            <p>ich berichte über die ambulante Vorstellung vom <date when="2013-10-18">18.10.2013</date> zur EEG-Kontrolle.</p>
            <p><list type="gloss">
                <label><hi rend="bold">Diagnosen:</hi></label>
                <item>
                    <list rend="bulleted">
                        <item><name nymRef="#icd-G40.3">V.a.Rolando-Epilepsie (G40.3)</name></item>
                        <item>SES</item>
                    </list>
                </item>
                <label><hi rend="bold">Medikamente:</hi></label>
                <item>
                    <list rend="bulleted">
                        <item><name nymRef="#s-sultiam">Sultiam (Ospolot)</name> 3 x 200mg</item>
                    </list>
                </item>
                <label><hi rend="bold">Therapie:</hi></label>
                <item>
                    <list rend="bulleted">
                        <item>Logopädie</item>
                    </list>
                </item>
                </list>
            </p>
            <p>Die Eltern berichten, dass ...</p>
            <p><name nymRef="#dx-eeg">EEG</name> vom <date when="2015-03-13">13.03.2015</date>: unauffällig ohne Nachweis von <name nymRef="#n-ETP">ETP</name>.</p>
            <p>blublablabla</p>
            <p>Im übrigen empfehle ich ....</p>
        </div>
        <closer>
            <salute>mit freundlichen Grüßen</salute>
            <signed>
                <p><name nymRef="#u-pmh">Peter Herkenrath</name></p>
                <p>Leiter der Neuro- und Sozialpädiatrie</p>
            </signed>
            <signed>
                <p><name nymRef="#u-vkr">PD Dr.med. von Kleist-Retzow</name></p>
                <p>Oberarzt</p>
            </signed>
            <signed>
                <p><name nymRef="">Willi Winzig</name></p>
                <p>Arzt</p>
            </signed>
        </closer>
        <postscript>
            <p>Familie Beta, Gottesweg 12, 50777 Köln</p>
        </postscript>
    </body>;   


(:~
 : content
 : make TEI content for Communication resource
 : 
 : @param $template
 : @param $address
 : @param $subject
 : @praam $oldapps existing appointments (as bundle)
 : @param $newapps new appointments (as sequence!)
 : 
 : @return contentTEI 
 :)

declare function letter:content(
          $apps as element(letterinfo)
        , $address as element(tei:address)
        , $subject as xs:string
        , $salute as xs:string
        ) as element(fhir:contentTEI)
{
    let $lll := util:log-app('TRACE','apps.nabu',namespace-uri($apps))
    let $date    := current-date()
    let $headline := concat("Aktuelle Terminübersicht für: ", $subject)
    return
        <contentTEI xmlns="http://hl7.org/fhir">
            <body xmlns="http://www.tei-c.org/ns/1.0" type="letter">
                <opener>
                    { $address }
                    <dateline>
                        <name type="place">Köln, </name>
                        <date when="{adjust-date-to-timezone($date,())}">{format-date($date, "[D]. [MNn] [Y]", "de", (), ())}</date>/Nabu</dateline>
                    <subject>{$headline}</subject>
                    <salute>{$salute}</salute>
                </opener>
                <div type="letter-body">
                    <p>für Sie sind folgende Termine reserviert:</p>
                    { letter:applist($apps/*:old/fhir:Encounter, $apps/*:new/fhir:Encounter) }
                    { $apps/*:info/tei:div }
                </div>
                { letter:closer() }
                { letter:postscript() }
            </body>
        </contentTEI>
};

(:~
 : infoAddress
 : 
 : @param $contact
 : @param $default (e.g. Patient), used if $contact/fhir:address is missing 
 : 
 : @return tei:address
 :)
declare function letter:infoAddress(
          $contact as item()
        , $default as element(fhir:Patient)
        ) as element(tei:address)
{
    let $name := letter:addressName($contact)
    let $address := ($contact/fhir:address, $default/fhir:address)[1]
    let $street := for $l in $address/fhir:line
        return
            <addrLine  xmlns="http://www.tei-c.org/ns/1.0">{$l/@value/string()}</addrLine>
    let $plz-city := concat($address/fhir:postalCode/@value, " ", $address/fhir:city/@value)
    return
        <address xmlns="http://www.tei-c.org/ns/1.0">
            <addrLine>{$name}</addrLine>
            { $street }
            <addrLine>{$plz-city}</addrLine>
        </address>
};

declare %private function letter:addressName(
          $contact as item()
        ) as xs:string
{
    let $name := switch ($contact/fhir:gender/@value)
        case 'male' return concat("Herr ", letter:formatFHIRName($contact/fhir:name[fhir:use/@value='official']))
        case 'female'  return concat("Frau ", letter:formatFHIRName($contact/fhir:name[fhir:use/@value='official']))
        default return letter:formatFHIRName($contact/fhir:name[fhir:use/@value='official'])
    return
    switch ($contact/fhir:relationship/fhir:coding/fhir:code/@value)
    case '' return $name
    default return $name
};

declare function letter:salute(
          $contact as item()
        ) as xs:string
{
    let $name := switch ($contact/fhir:gender/@value)  
        case 'male' return concat("Sehr geehrter Herr ", letter:formatFHIRName($contact/fhir:name[fhir:use/@value='official']))
        case 'female'  return concat("Sehr geehrte Frau ", letter:formatFHIRName($contact/fhir:name[fhir:use/@value='official']))
        default return concat('Sehr geehrte Herr/Frau ', letter:formatFHIRName($contact/fhir:name[fhir:use/@value='official']))
    return 
        $name
};

(:~
 : formatFHIRName
 : 
 : TODO evaluate @use, @period 
 : @param $name
 : 
 : @return string
 :)
declare %private function letter:formatFHIRName(
          $name as element(fhir:name)
        ) as xs:string
{
    string-join($name/fhir:family/@value, ' ')
};

declare %private function letter:closer(
        ) as element(tei:closer)
{
    <closer xmlns="http://www.tei-c.org/ns/1.0">
        <salute>mit freundlichen Grüßen</salute>
        <signed>
            <p>
                <name nymRef="#kikl-spzn">SPZ der Kinderklinik</name>
            </p>
        </signed>
    </closer>
};

declare %private function letter:postscript(
        ) as element(tei:postscript)
{
    <postscript xmlns="http://www.tei-c.org/ns/1.0">
    </postscript>
};

declare %private function letter:applist(
          $oldapps as element(fhir:Encounter)*
        , $newapps as element(fhir:Encounter)*
        ) as element(tei:p)
{
    let $today   := current-dateTime()
    return
        <p xmlns="http://www.tei-c.org/ns/1.0">
            <list rend="bulleted">
            {
                let $olist := 
                    if ($oldapps and $oldapps[fhir:period/fhir:start/@value>$today])
                    then
                    (
                          <label xmlns="http://www.tei-c.org/ns/1.0"><hi rend="bold">Bereits vereinbarte Termine:</hi></label>
                        , <item xmlns="http://www.tei-c.org/ns/1.0"><list rend="bulleted">
                        {
                            for $oa in $oldapps[fhir:period/fhir:start/@value>$today]
                            let $reason := letter:mapCalendarLabel($oa/fhir:type/fhir:text/@value)
                            let $odate := string-join(
                                ( format-dateTime($oa/fhir:period/fhir:start/@value, "[FNn], [D].[M01].[Y] um [H01]:[m01]", "de", (), ())
                                , $reason),
                                ' - ')
                            order by $oa/fhir:period/fhir:start/@value/string()
                            return
                                <item xmlns="http://www.tei-c.org/ns/1.0" >{$odate}</item>
                        }</list></item>
                    )
                    else
                        ()
                let $nlist :=
                    if ($newapps and count($newapps)>0)
                    then
                    (
                          <label xmlns="http://www.tei-c.org/ns/1.0">
                            <hi rend="bold">
                            {
                                if ($oldapps)
                                then 'Weitere Termine:'
                                else 'Termine:'
                            }
                            </hi></label>
                        , <item xmlns="http://www.tei-c.org/ns/1.0"><list rend="bulleted">
                        {
                            for $na in $newapps
                            let $reason := letter:mapCalendarLabel($na/fhir:type/fhir:text/@value)
                            let $ndate := string-join(
                                ( format-dateTime($na/fhir:period/fhir:start/@value, "[FNn], [D].[M01].[Y] um [H01]:[m01]", "de", (), ())
                                , $reason),
                                ' - ')
                            order by $na/fhir:period/fhir:start/@value/string()
                            return
                                <item xmlns="http://www.tei-c.org/ns/1.0" >{$ndate}</item>
                        }</list></item>
                    )
                    else 
                        ()
                return
                    if  ($olist or $nlist)
                    then
                        ($olist,$nlist)
                    else
                        <item xmlns="http://www.tei-c.org/ns/1.0" ><hi rend="bulleted">keine Termine</hi></item>
            }
            </list>
        </p>
};

declare %private function letter:mapCalendarLabel(
          $orig as xs:string
    ) as xs:string
{
    switch ($orig)
        case ''               return 'Amb.'
        case 'regAZ'          return 'Amb.'
        case 'Reserve'        return 'Amb.'
        case 'Reguläre AZ'    return 'Amb.'
        case 'rAZ EEG'        return 'EEG'
        case 'rAZ EP-NLG'     return 'EP-NLG'
        case 'Psych Beratung'        return 'Psychologie'
        case 'Psych Diagnostik'      return 'psychologische Diagnostik'
        case 'Psych Diagnostik kurz' return 'psychologische Diagnostik'
        case 'Psychologie'           return 'Psychologie'
        case 'Praktikant'            return 'psychologische Diagnostik'
        default return $orig
};
