xquery version "3.0";

module namespace enclist = "http://enahar.org/exist/apps/nabu/encounter-list";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
import module namespace xqtime = "http://enahar.org/lib/xqtime";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace r-respon = "http://enahar.org/exist/restxq/nabu/patient-responsibility"  at "../../FHIR/Patient/responsibility-routes.xqm";

declare namespace fhir= "http://hl7.org/fhir";

declare %private function enclist:sameDay($tmin,$tmax) as xs:boolean
{
    xs:date($tmin) = xs:date($tmax)
};

declare %private function enclist:quartal($date as xs:dateTime) as xs:string
{
    let $m := month-from-dateTime($date)
    return
        if ($m < 4)         then 'Q1'
        else if ($m < 7)    then 'Q2'
        else if ($m < 10)   then 'Q3'
        else                     'Q4'
        
};

declare function enclist:preparePerDayList(
      $encs as element(fhir:Encounter)*
    , $tmin as xs:dateTime
    , $tmax as xs:dateTime
    )
{

    let $nofd  := xs:integer(floor(($tmax - $tmin) div xs:dayTimeDuration('P1D')))
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header("Termine") }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                {
                    (: enumerate days in period :)
                    for $n in (0 to $nofd)
                    let $date  := $tmin + xs:dayTimeDuration('P1D')*$n
                    let $d := format-dateTime($date,'[Y0001]-[M01]-[D01]')
                    let $encsday := $encs[fhir:period[fhir:start[starts-with(@value,$d)]]]
                    return
                    <table rows="{count($encsday)}" cols="3.5:2:7:4"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <head>Termine vom {format-dateTime($date,'[D01].[M01].[Y01]')}</head>
                            <row role="label">
                                    <cell role="label">Uhrzeit</cell>
                                    <cell role="label">OE</cell>
                                    <cell role="label">Patient</cell>
                                    <cell role="label">Erbringer</cell>
                            </row>
                    {
                        for $a in $encsday
                        let $id := substring-after($a/fhir:subject/fhir:reference/@value,'nabu/patients/')
                        let $oe := r-respon:managingOrganizationByIDXML($id,'kikl-spz','u-admin','Admin')
                        let $time := concat(format-dateTime($a/fhir:period/fhir:start/@value,'[H01]:[m01]'),' - ',format-dateTime($a/fhir:period/fhir:end/@value,'[H01]:[m01]'))
                        order by $time
                        return
                        <row role="data">
                            <cell role="data">{$time}</cell>
                            <cell role="data">{substring-after($oe/fhir:reference/@value,'metis/organizations/ukk-oe')}</cell>
                            <cell role="data">{$a/fhir:subject/fhir:display/@value/string()}</cell>
                            <cell role="data">{$a/fhir:participant/fhir:individual/fhir:display/@value/string()}</cell>
                        </row>
                    }
                    </table>
                }
                </div>
            </body>
        </text>
    </TEI>
    return $result
};

declare function enclist:prepareArchiveList(
      $encs as element(fhir:Encounter)*
    , $tmin as xs:dateTime
    , $tmax as xs:dateTime
    , $realm as xs:string
    , $loguid as xs:string
    , $lognam as xs:string
    )
{
    let $lll := util:log-app('TRACE','apps.nabu',count($encs))
    let $prefs := distinct-values($encs/fhir:subject/fhir:reference/@value)
    let $files :=
                for $pref in $prefs
    let $lll := util:log-app('TRACE','apps.nabu',$pref)
                let $id       := substring-after($pref,'nabu/patients/')
    let $lll := util:log-app('TRACE','apps.nabu',$id)
                let $respon   := r-respon:responsibilitiesXML($id, $realm, $loguid, $lognam, '',  '1994-06-01T08:00:00', "2021-04-01T23:00:00", "team")
    let $lll := util:log-app('TRACE','apps.nabu',$respon)
                let $known    := count($respon/fhir:participant)>0
                let $lastDate := if ($known)
                    then xxpath:highest(function($p){$p/fhir:period/fhir:end/@value}, $respon/fhir:participant)[1]/fhir:period/fhir:end/@value/string()
                    else ''
                let $lastActors := if ($known)
                    then string-join($respon/fhir:participant[fhir:period[fhir:end[@value=$lastDate]]]/fhir:member/fhir:display/@value,', ')
                    else ''
                let $encByPat := $encs/../fhir:Encounter[fhir:subject[fhir:reference/@value=$pref]]
                let $enc      := head($encByPat)
    (:
    let $lll := util:log-app('TRACE','apps.nabu',$enc)
    :)
                let $patdsp   := $enc/fhir:subject/fhir:display/@value/string()
                let $newActors:= $encByPat/fhir:participant/fhir:individual/fhir:display/@value/string()
                let $date:=  $enc/fhir:period/fhir:start/@value/string()
                order by $patdsp
                return
                    if ($known)
                    then
                        let $q   := if ($lastDate < '2014-01-01')
                            then ''
                            else enclist:quartal(xs:dateTime($lastDate))
                        return
                        <file>
                            <lastEncounterDate value="{$lastDate}"/>
                            <quartal value="{$q}"/>
                            <encDate value="{$date}"/>
                            <name value="{$patdsp}"/>
                            <lastActors value="{$lastActors}"/>
                            <newActors value="{string-join($newActors,', ')}"/>
                        </file>
                    else <nofile>
                            <encDate value="{$date}"/>
                            <name value="{$patdsp}"/>
                            <newActors value="{string-join($newActors,', ')}"/>
                        </nofile>
    let $lll := util:log-app('TRACE','apps.nabu',$files)
    let $years :=
            for $f in $files 
            return
                tokenize(tokenize($f/*:lastEncounterDate/@value,'T')[1],'-')[1]
    let $range := if ($tmin=$tmax)
        then
            format-dateTime($tmin,'[D01].[M01].[Y01]')
        else
            concat(format-dateTime($tmin,'[D01].[M01]'),'-', format-dateTime($tmax,'[D01].[M01].[Y01]'))
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header("Aktenliste für Archiv") }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                    <table rows="{count($files)}" cols="1:1:0.5:3.5:1.5:7:4"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <head>Aktenliste vom {$range}</head>
                            <row role="label">
                                    <cell role="label">Jahr</cell>
                                    <cell role="label">Datum</cell>    
                                    <cell role="label">Q</cell>
                                    <cell role="label">Letzte Erbringer</cell>
                                    <cell role="label">Termin</cell>
                                    <cell role="label">Patient</cell>
                                    <cell role="label">Erbringer</cell>
                            </row>
                    {
                        for $y in distinct-values($years)
                        order by $y
                        return
                            if ($y < '2014')
                            then
                                let $fInYear := $files[starts-with(*:lastEncounterDate/@value,$y)]
                                for $f at $i in $fInYear
                                return
                            <row role="data">
                                    <cell role="label">{if ($i=1) then $y else ''}</cell>
                                    <cell role="data">{format-dateTime($f/*:lastEncounterDate/@value,'[D01].[M01].')}</cell>    
                                    <cell role="data">{''}</cell>
                                    <cell role="data">{$f/*:lastActors/@value/string()}</cell>
                                    <cell role="data">{format-dateTime($f/*:encDate/@value,'[D01].[M01].')}</cell>
                                    <cell role="data">{$f/*:name/@value/string()}</cell>
                                    <cell role="data">{$f/*:newActors/@value/string()}</cell>
                            </row>
                            else
                                let $fInYear := $files[starts-with(*:lastEncounterDate/@value,$y)]
                                let $qs      := 
                                    for $q in distinct-values($fInYear/*:quartal/@value)
                                    order by $q
                                    return
                                        $q
                                for $q  in $qs
                                let $fInQ := $fInYear[*:quartal/@value=$q]
                                return
                                    let $fs := 
                                        for $fq in $fInQ
                                        order by $fq/*:name/@value/string()
                                        return
                                            $fq
                                    for $f at $i in $fs
                                    return
                            <row role="data">
                                    <cell role="label">{if ($i=1) then $y else ''}</cell>
                                    <cell role="data">{format-dateTime($f/*:lastEncounterDate/@value,'[D01].[M01].')}</cell>
                                    <cell role="data">{if ($i=1) then $f/*:quartal/@value/string() else ''}</cell>
                                    <cell role="data">{$f/*:lastActors/@value/string()}</cell>
                                    <cell role="data">{format-dateTime($f/*:encDate/@value,'[D01].[M01].')}</cell>
                                    <cell role="data">{$f/*:name/@value/string()}</cell>
                                    <cell role="data">{$f/*:newActors/@value/string()}</cell>
                            </row>
                    }
                    {
                        for $f at $i in $files[local-name(.)='nofile']
                        return
                            <row role="data">
                                    <cell role="label">{if ($i=1) then 'Ohne' else ''}</cell>
                                    <cell role="data">{if ($i=1) then 'Akte' else ''}</cell>    
                                    <cell role="data"></cell>
                                    <cell role="data"></cell>
                                    <cell role="data">{format-dateTime($f/*:encDate/@value,'[D01].[M01].')}</cell>
                                    <cell role="data">{$f/*:name/@value/string()}</cell>
                                    <cell role="data">{$f/*:newActors/@value/string()}</cell>
                            </row>
                    }
                    </table>
                </div>
            </body>
        </text>
    </TEI>
    return $result
};
