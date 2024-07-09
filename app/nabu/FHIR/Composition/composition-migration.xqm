xquery version "3.0";

module namespace compmigr = "http://enahar.org/exist/apps/nabu/composition-migration";

import module namespace dl2tei         = "http://enahar.org/exist/apps/nabudocs/dl2tei"  at "/db/apps/nabudocs/modules/dl2tei.xqm";
import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace dbutil="http://exist-db.org/xquery/dbutil";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $compmigr:collpath := '/db/apps/nabuComposition/data';

declare function compmigr:update-1.0-2(
      $c as element(fhir:Composition)
    )
{
    if ($c/fhir:category)
    then
        ()
    else
        system:as-user('vdba', 'kikl823!',
            (
              update replace $c/fhir:class
                     with
                     <category xmlns="http://hl7.org/fhir">
                         <coding>
                             <system value="http://loinc.org"/>
                             <code value="173421-1"/>
                             <display value="Report"/>
                         </coding>
                         <text value="Arzt"/>
                     </category>
            ))
};


declare function compmigr:update-1.0-1(
      $c as element(fhir:Composition)
    )
{
    if ($c/fhir:lastModified)
    then
    system:as-user('vdba', 'kikl823!',
            (
                update delete $c/fhir:lastModified
            ,   update delete $c/fhir:lastModifiedBy
            ))
    else ()
};

declare function compmigr:update-1.0-0b(
      $c as element(fhir:Composition)
    )
{
    if ($c/fhir:extension//fhir:recipient)
    then
        system:as-user('vdba', 'kikl823!',
            (
             for $ext in $c/fhir:extension[@url="http://www.eNahar.org/exist/apps/nabu/composition-recipient"]
             let $r := $ext//fhir:recipient/*
             return
                if ($r)
                then update replace $ext with
                        <extension xmlns="http://eNahar.org/nabu/extension/composition-recipient">
                          <valueReference>
                            { $r }
                          </valueReference>
                        </extension>
                else ()
            ))
    else ()
};

declare function compmigr:update-1.0-0a(
      $c as element(fhir:Composition)
    )
{
    if ($c/fhir:meta/fhir:extension)
    then
        let $exs := $c/fhir:meta/fhir:extension/*
        return
        system:as-user('vdba', 'kikl823!',
            (
              update replace $c/fhir:meta/fhir:extension with
                        <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                          <valueReference>
                            { $exs }
                          </valueReference>
                        </extension>
            ))
    else ()
};

declare function compmigr:update-1.0-0(
      $c as element(fhir:Composition)
    )
{
    if ($c/fhir:meta/fhir:lastUpdated)
    then
        ()
    else
        system:as-user('vdba', 'kikl823!',
            (
              update insert <lastUpdated xmlns="http://hl7.org/fhir" value="{$c/fhir:lastModified/@value/string()}"/>
                        into $c/fhir:meta
            , update insert <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                              <valueReference>
                                <reference value="{$c/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                                <display value="{$c/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                              </valueReference>
                            </extension>
                        into $c/fhir:meta
            ))
};




(:~
 : create collections for Compositions per year
 : data
 :     - 1994
 :     - 1995
 :     ...
 :     - 2021
 :     - invaliddate
 :)
declare function compmigr:createDirs()
{

    let $years := for $year in (1994 to 2021)
        return
            (
              xdb:create-collection($compmigr:collpath, xs:string($year))
            , compmigr:fixPath(concat($compmigr:collpath,'/',$year))
            )
    let $invdate := 
            (
              xdb:create-collection($compmigr:collpath, '/invaliddate')
            , compmigr:fixPath(concat($compmigr:collpath,'/invaliddate'))
            )
    return
        ()
};

declare %private function compmigr:fixPath($path)
{
    sm:chown($path, 'admin'),
    sm:chgrp($path, 'spz'),
    sm:chmod($path, "rwxrwxr-x")
};

(:~
 : migrates Composition Nabu 0.8 to 0.8-sc
 : distributes Compositions into subcollections
 : 
 :)
declare function compmigr:update-0.8-sc($c as element(fhir:Composition))
{
    let $pathCurrent  := util:collection-name($c)
    let $nameCurrent  := util:document-name($c)
    let $year   := substring($c/fhir:date/@value,1,4)
    return
        if (xs:integer($year)>1994 and xs:integer($year)<2022)
        then
                let $target := concat($compmigr:collpath,'/',$year)
                return
                    system:as-user('vdba', 'kikl823!', 
                        xmldb:copy($pathCurrent, $target, $nameCurrent)
                    )
        else 
            system:as-user('admin', 'kikl968', 
                xmldb:copy($pathCurrent, '/db/apps/nabuComposition/data/invaliddate', $nameCurrent)
            )
};

declare function compmigr:group($path)
{
    let $ptoks := tokenize($path,'/')
    let $group := switch($ptoks[2])
        case 'Arzt' return 'Arzt'
        case 'Bayley3' return 'Bayley3'
        case 'Psychologie' return 'Psychologie'
        case 'Logopaedie' return 'Logopädie'
        case 'Logo' return 'Logopädie'
        case 'Ergotherapie' return 'Ergotherapie'
        case 'Ergo' return 'Ergotherapie'
        case 'Physiotherapie' return 'Physiotherapie'
        case 'Physio' return 'Physiotherapie'
        case 'Orthoptik' return 'Orthoptik'
        default return if ($ptoks[1]='Bayley3')
            then 'Bayley3'
            else 'Arzt'
    return
        $group
};
declare function compmigr:file($path)
{
    let $ptoks := tokenize($path,'/')
    return
        $ptoks[last()]
};

declare function compmigr:update-0.8($composition as element(fhir:Composition))
{
    let $lll := util:log-app('INFO','apps.nabu',$composition)
    let $base := '/apps/nabuCom/import/'
    let $path := $composition/fhir:section/fhir:code/fhir:coding[fhir:system/@value="#nabu-report-source"]/fhir:code/@value
    let $group := compmigr:group($path)
    let $file  := compmigr:file($path)
    let $fullpath := concat(
              $base
            , $path
            )
    let $l := doc($fullpath)
    let $lt   := dl2tei:ltrans($l,$file)
    return
    system:as-user('vdba', 'kikl823!',
            (
              update replace $composition/fhir:meta/fhir:versionID with
                <versionId xmlns="http://hl7.org/fhir" value="{$composition/fhir:meta/fhir:versionID/@value/string()}"/>
            , update replace $composition/fhir:section/fhir:text with 
                <text xmlns="http://hl7.org/fhir">
                    <status value="imported"/>
                    { $lt/tei:div }
                </text>
            , update replace $composition/fhir:section/fhir:title with 
                <title xmlns="http://hl7.org/fhir" value="{ $group }"/>
            , update delete $composition/fhir:author[not(./fhir:reference)] 
            ))
};
declare function compmigr:update-0.8-26($composition as element(fhir:Composition))
{
    let $rref := $composition/fhir:extension[@url="http://www.eNahar.org/exist/apps/nabu/composition"]/fhir:recipient/fhir:reference/@value/string()
    let $rdisp:= $composition/fhir:extension[@url="http://www.eNahar.org/exist/apps/nabu/composition"]/fhir:recipient/fhir:display/@value/string()
    return
    system:as-user('vdba', 'kikl823!',
            (
              update replace $composition/fhir:extension[@url="http://www.eNahar.org/exist/apps/nabu/composition"] with 
                <extension xmlns="http://hl7.org/fhir" url="http://www.eNahar.org/exist/apps/nabu/composition-recipient">
                    <valueReference>
                        <reference value="{$rref}"/>
                        <display value="{$rdisp}"/>
                    </valueReference>
                </extension>
            ))
};
