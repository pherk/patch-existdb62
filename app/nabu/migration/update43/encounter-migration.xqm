xquery version "3.0";

module namespace encmigr = "http://enahar.org/exist/apps/nabu/encounter-migration";
import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace dbutil="http://exist-db.org/xquery/dbutil";
declare namespace fhir= "http://hl7.org/fhir";

declare function encmigr:update-1.0-7(
      $e as element(fhir:Encounter)
    )
{
    if ($e/fhir:fulfills)
    then
        system:as-user('vdba', 'kikl823!',
            (
                update delete $e/fhir:fulfills
            ))
    else ()
};

declare function encmigr:update-1.0-6(
      $e as element(fhir:Encounter)
    )
{
    if ($e/fhir:appointment)
    then ()
    else
        if ($e/fhir:fulfills)
        then if($e/fhir:fulfills/fhir:reference/@value="")
            then ()
            else
            system:as-user('vdba', 'kikl823!',
            (
                update insert <appointment xmlns="http://hl7.org/fhir">
                              { $e/fhir:fulfills/fhir:reference }
                              </appointment>
                        following $e/fhir:fulfills
            ))
        else ()
};


declare function encmigr:update-1.0-5(
      $e as element(fhir:Encounter)
    )
{
    if ($e/fhir:reason)
    then
        system:as-user('vdba', 'kikl823!',
            (
                update delete $e/fhir:reason
            ))
    else ()
};

declare function encmigr:update-1.0-4(
      $e as element(fhir:Encounter)
    )
{
    if ($e/fhir:reasonCode)
    then ()
    else
        system:as-user('vdba', 'kikl823!',
            (
                update insert <reasonCode xmlns="http://hl7.org/fhir">
                              { $e/fhir:reason/* }
                              </reasonCode>
                        following $e/fhir:reason
            ))
};

declare function encmigr:update-1.0-3(
      $e as element(fhir:Encounter)
    )
{
    if ($e/fhir:participant/fhir:actor)
    then
        system:as-user('vdba', 'kikl823!',
            (
                update delete $e/fhir:participant/fhir:actor
            ))
    else ()
};

declare function encmigr:update-1.0-2(
      $e as element(fhir:Encounter)
    )
{
    if ($e/fhir:participant/fhir:individual)
    then ()
    else
        system:as-user('vdba', 'kikl823!',
            (
              for $p in $e/fhir:participant
              return
                update insert <individual xmlns="http://hl7.org/fhir">
                                    <reference value="{$p/fhir:actor/fhir:reference/@value/string()}"/>
                                    <display value="{$p/fhir:actor/fhir:display/@value/string()}"/>
                              </individual>
                        into $p
            ))
};

declare function encmigr:update-1.0-1(
      $e as element(fhir:Encounter)
    )
{
    if ($e/fhir:lastModified)
    then
        system:as-user('vdba', 'kikl823!',
            (
                update delete $e/fhir:lastModified
            ,   update delete $e/fhir:lastModifiedBy
            ))
    else ()
};

declare function encmigr:update-1.0-0(
      $e as element(fhir:Encounter)
    )
{
    if ($e/fhir:meta/fhir:lastUpdated)
    then ()
    else
        system:as-user('vdba', 'kikl823!',
            (
              update insert <lastUpdated xmlns="http://hl7.org/fhir" value="{$e/fhir:lastModified/@value/string()}"/>
                        into $e/fhir:meta
            , update insert <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                                <valueReference>
                                    <reference value="{$e/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                                    <display value="{$e/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                                </valueReference>
                            </extension>
                        into $e/fhir:meta
            ))
};

declare variable $encmigr:collpath := '/db/apps/nabuEncounter/data';

(:~
 : create collections for Encounters per year
 : data
 :     - 1994
 :     - 1995
 :     ...
 :     - 2021
 :)
declare function encmigr:createDirs()
{

    let $years := for $year in (1994 to 2021)
        return
            (
              xdb:create-collection($encmigr:collpath, xs:string($year))
            , encmigr:fixPath(concat($encmigr:collpath,'/',$year))
            )
    let $planned :=
            (
              xdb:create-collection($encmigr:collpath, 'planned')
            , encmigr:fixPath(concat($encmigr:collpath,'/planned'))
            )
    let $invalid :=
            (
              xdb:create-collection($encmigr:collpath, 'invalid')
            , encmigr:fixPath(concat($encmigr:collpath,'/invalid'))
            )
    return
        ()
};

declare %private function encmigr:fixPath($path)
{
    sm:chown($path, 'admin'),
    sm:chgrp($path, 'spz'),
    sm:chmod($path, "rwxrwxr-x")
};

(:~
 : migrates Encounter pre Nabu 0.8 to 0.8
 : 
 :)
declare function encmigr:update-0.8($e as element(fhir:Encounter))
{
    ()
};

(:~
 : migrates Encounter Nabu 0.8 to 0.8.25 
 : 
 :)
declare function encmigr:update-0.8-25($e as element(fhir:Encounter))
{
    let $pathCurrent  := util:collection-name($e)
    let $nameCurrent  := util:document-name($e)
    let $year   := substring($e/fhir:period/fhir:start/@value,1,4)
    return
        if (xs:integer($year)>2003 and xs:integer($year)<2022)
        then
            if ($e/fhir:status/@value=('planned','tentative'))
            then
                let $target := concat($encmigr:collpath,'/planned')
                return
                    system:as-user('vdba', 'kikl823!', 
                        xmldb:copy($pathCurrent, $target, $nameCurrent)
                    )
            else
                let $target := concat($encmigr:collpath,'/',$year)
                return
                    system:as-user('vdba', 'kikl823!', 
                        xmldb:copy($pathCurrent, $target, $nameCurrent)
                    )
        else 
            system:as-user('admin', 'kikl968', 
                xmldb:copy($pathCurrent, '/db/apps/nabuEncounter/data/invalid', $nameCurrent)
            )
};

(:~
 : inserts missing basedOn property 
 : 
 :)
declare function encmigr:update-0.8-28($e as element(fhir:Encounter), $o as element(fhir:Order))
{
    let $basedOn := $o/fhir:basedOn
    return
            system:as-user('admin', 'kikl968', 
                update insert $basedOn following $e/fhir:lastModified
            )
};


(:~
 : migrates Appointment pre Nabu 0.8 to Encounter v3.0.1
 :)
declare function encmigr:a2e($app as element(fhir:Appointment))
{
    let $status := switch($app/fhir:status/@value)
        case "tentative" return "tentative"
        case "booked" return "planned"
        case "accepted" return "finished"
        case "arrived" return "finished"
        case "registered" return "finished"
        case "fulfilled" return "finished"
        case "noshow" return "cancelled"
        case "cancelled" return "cancelled"
        case "reorder" return "cancelled"
        default return "unknown"
    let $start   := $app/fhir:start/@value/string()
    let $end     := $app/fhir:end/@value/string()
    let $summary := $app/fhir:description/@value/string()
    let $tcode   := $app/fhir:type//fhir:code/@value/string()
    let $tdisp   := $app/fhir:type//fhir:display/@value/string()
    let $ttext   := $app/fhir:type/fhir:text/@value/string()
    let $pat     := $app/fhir:participant[fhir:type//fhir:code/@value='patient']
    let $pref    := $pat/fhir:actor/fhir:reference/@value/string()
    let $pnam    := $pat/fhir:actor/fhir:display/@value/string()
    let $actors :=    
        for $actor in $app/fhir:participant[fhir:type//fhir:code/@value != 'patient']
        let $rcode := $actor/fhir:type//fhir:code/@value/string()
        let $rdisp := $actor/fhir:type//fhir:display/@value/string()
        let $rtext := $actor/fhir:type/fhir:text/@value/string()
        let $aref  := $actor/fhir:actor/fhir:reference/@value/string()
        let $anam  := $actor/fhir:actor/fhir:display/@value/string()
        return
        <participant xmlns="http://hl7.org/fhir">
            <type>
                <coding>
                    <system value="#encounter-role"/>
                    <code value="{$rcode}"/>
                    <display value="{$rdisp}"/>
                </coding>
                <text value="{$rtext}"/>
            </type>
            <period>
                <start value="{$start}"/>
                <end value="{$end}"/>
            </period>
            <actor>
                <reference value="{$aref}"/>
                <display value="{$anam}"/>
            </actor>
        </participant>  
    let $rcode   := $app/fhir:reason/fhir:coding[fhir:system/@value=("#appointment-reason","#encounter-reason")]/fhir:code/@value/string()
    let $rdisp   := $app/fhir:reason/fhir:coding[fhir:system/@value=("#appointment-reason","#encounter-reason")]/fhir:display/@value/string()
    let $icdcode := $app/fhir:reason/fhir:coding[fhir:system/@value="#encounter-ICD-Code"]/fhir:code/@value/string()
    let $icddisp := $app/fhir:reason/fhir:coding[fhir:system/@value="#encounter-ICD-Code"]/fhir:display/@value/string()
    let $rtext   := $app/fhir:reason/fhir:text/@value/string()
    let $fulfills:= $app/fhir:order/fhir:reference/@value/string()
    return
<Encounter xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionId value="0"/>
    </meta>
    <status value="{$status}"/>
    {
        if ($app/fhir:status/@value = ('noshow','reorder'))
        then
            <statusHistory>
                <status value="planned"/>
                <extension url="#encounter-status-change-reason">
                    <valueCodeableConcept>
                        <coding>
                            <system value="#encounter-status-change-reason"/>
                            <code value="{$app/fhir:status/@value/string()}"/>
                        </coding>
                        <text value="{$app/fhir:status/@value/string()}"/>
                    </valueCodeableConcept>
                </extension>
                <period>
                    <start value=""/>
                    <end value="{$app/fhir:lastModified/@value/string()}"/>
                </period>
            </statusHistory>
        else ()
    }
    <class value="AMB"/>
    <type>
        <coding>
            <system value="#encounter-type"/>
            <code value="{$tcode}"/>
            <display value="{$tdisp}"/>
        </coding>
        <text value="{$ttext}"/>
    </type>
    <subject>
        <reference value="{$pref}"/>
        <display value="{$pnam}"/>
    </subject>
    { $actors }
    <appointment>
        <reference value="{$fulfills}"/>
    </appointment>
    <period>
        <start value="{$start}"/>
        <end value="{$end}"/>
    </period>
    <reason>
        <coding>
            <system value="#encounter-reason"/>
            <code value="{$rcode}"/>
            <display value="{$rdisp}"/>
        </coding>
        <text value="{concat($rtext,' - ',$summary)}"/>
    </reason>
    <serviceProvider>
        <reference value="metis/organizations/kikl-spz"/>
        <display value="SPZ Kinderklinik"/>
    </serviceProvider>
    <location>
        <location>
            <reference value="metis/locations/kikl-spz"/>
            <display value="SPZ KiKl"/>
        </location>
        <status value="planned"/>
        <period>
            <start value="{$start}"/>
            <end value="{$end}"/>
        </period>
    </location>
</Encounter>
};

