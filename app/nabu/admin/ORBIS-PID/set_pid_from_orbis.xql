xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

(:~
 : NoMatch-from-ORBIS
 : setzt PID in Nabu, wenn
 : - Name
 : - Vorname
 : - GebDat (wird aktuell nicht genutzt, da es extrem unwahrscheinlich, dass eine Namensdublette am gleichen Tag auftaucht;
 :           Mehrlinge schon, aber die haben gewöhnlich gleiches Geburtdatum)
 : übereinstimmen
 : erzeugt Datei mit Patienten, die nicht gematcht werden können
 : 
 : @version 0.9
 :)
declare function local:setpid($p,$b)
{
    if (count($b)>0)
    then
        let $res :=
            for $single in $b
            return
            if ($single/Name=$p/fhir:name[fhir:use/@value='official']/fhir:family/@value and
                tokenize($single/Vorname,"[ \-]")[1]=tokenize($p/fhir:name[fhir:use/@value='official']/fhir:given/@value,"[ \-]")[1])
            then
                let $upd := system:as-user('vdba', 'kikl823!',
                    update value $p/fhir:identifier[fhir:type/@value='ORBIS-PNR']/fhir:value/@value
                    with $single/*:PID
                )
                return
                    <update>{$p/fhir:text/*:div/*:div/string()}</update>
            else ()
        return if (count($res)=1)
            then $res
            else if (count($b)>1)
                then
                <no-exact-match nabu="{$p/fhir:text/*:div/*:div/string()}">{
                  for $s in $b
                  return
                    <orbis>{string-join(($s/*:Name,$s/*:Vorname,$s/*:Geb-Dat,$s/*:PID),", ")}</orbis>
                }</no-exact-match>
                else 
                <no-exact-match nabu="{$p/fhir:text/*:div/*:div/string()}"
                    id="{$p/fhir:id/@value/string()}">{
                    <orbis>{string-join(($b/*:Name,$b/*:Vorname,$b/*:Geb-Dat,$b/*:PID),", ")}</orbis>
                }</no-exact-match>
    else
        <besuch-missing name="{$p/fhir:text/*:div/*:div/string()}"/>
};
let $year := '2024'
let $yearq := '2024Q1'
let $besuche := doc("/db/apps/nabuORBIS/Besuche-" || $yearq || ".xml")/*:dataroot/*
(: 
<Besuche-2020>
<Datum>2020-01-02 08:10</Datum> invalides ISO8601 Format; Uhrzeit wird einfach abgeschnitten
<Typ>EB</Typ>
<PID>6727304</PID>
<Fallnr>1001307569</Fallnr>
<Name>Geber</Name>
<Vorname>Sofiya</Vorname>
<Geb-Dat>2010-06-25</Geb-Dat>
<Geschlecht>W</Geschlecht>
<Status>ambulant</Status>
<Orgaeinheit>0734/SOZ.PÄD</Orgaeinheit>
<Diagnose>E70.1</Diagnose>
<Besuchsart>SP</Besuchsart>
<Falltyp>aktueller Fall</Falltyp>
</Besuche-2020>
:)
let $dates := distinct-values(for $b in $besuche return tokenize($b/*:Tag,' ')[1])

let $pc := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:active[@value="true"]]
let $ec := collection('/db/apps/nabuEncounter/data/' || $year)/fhir:Encounter
let $cc := collection('/db/apps/nabuCom/data/Conditions')/fhir:Condition
let $list :=
    <patients>
    {
        (: geht die Tage in der Besuchs-Liste/Fallübersicht durch
           - sucht beendeten Termine an dem Tag aus Nabu Encounter heraus
           - sucht Besuche aus ORBIS heraus
           - bildet Patienten-Liste aus Nabu für den Tag
           - geht die Patienten-Liste durch
             - falls Patient keine PatID hat, wird versucht diese zu setzen
                    <update> bei Success
                    <no-exact-match> bei Failure
                    <besuch-missing> falls gar kein Besuch in ORBIS
               falls er eine hat, prüfe auf Gleichheit
                    <pid-not-found-b> falls nicht
           - Ergebnis wird in Liste geschrieben "liste-$Year.xml"
        :)
    for $d in $dates
    let $es := $ec/../fhir:Encounter[fhir:period[fhir:start[starts-with(@value,$d)]]][fhir:status[@value='finished']]
    let $bs := $besuche[starts-with(*:Tag,$d)]
    let $pids := distinct-values(for $e in $es return substring-after($e/fhir:subject/fhir:reference/@value,'nabu/patients/'))
    order by $d
    return
        <tag date="{$d}">
        {
            for $pid in $pids
            let $p := $pc/../fhir:Patient[fhir:id[@value=$pid]]
            let $b := $bs[*:Geb-Dat=$p/fhir:birthDate/@value]
            return
                if ($p/fhir:identifier[fhir:type/@value='ORBIS-PNR']/fhir:value/@value='')
                then local:setpid($p,$b)
                else if ($p/fhir:identifier[fhir:type/@value='ORBIS-PNR']/fhir:value/@value=$b/*:PID)
                then ()
                else if (count($b)=1 and $p/fhir:name[fhir:use/@value='official']/fhir:family/@value=$b/Name and
                tokenize($p/fhir:name[fhir:use/@value='official']/fhir:given/@value,"[ \-]")[1]=tokenize($b/Vorname,"[ \-]")[1])
                        then
                    <incorrect-pid
                        pid-orbis="{$b/*:PID}" 
                        pid-nabu="{$p/fhir:identifier[fhir:type/@value='ORBIS-PNR']/fhir:value/@value/string()}">{$p/fhir:text/*:div/*:div/string()}</incorrect-pid>
                        else
                    (: TODO filter Spontanbesuch
                    <pid-not-found-b pid="{$p/fhir:identifier[fhir:type/@value='ORBIS-PNR']/fhir:value/@value/string()}">{$p/fhir:text/*:div/*:div/string()}</pid-not-found-b>
                    :) ()
        }</tag>
    }
    </patients>
    return
        system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabuORBIS","liste-" || $yearq || ".xml",$list))