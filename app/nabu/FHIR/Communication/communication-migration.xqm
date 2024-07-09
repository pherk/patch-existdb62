xquery version "3.0";

module namespace commigr = "http://enahar.org/exist/apps/nabu/communication-migration";
import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace dbutil="http://exist-db.org/xquery/dbutil";
declare namespace fhir= "http://hl7.org/fhir";
declare variable $commigr:collpath := '/db/apps/nabuCommunication/data';

declare function commigr:update-1.0-3(
      $c as element(fhir:Communication)
    )
{
    if ($c/fhir:reason)
    then
        system:as-user('vdba', 'kikl823!',
            (
                update delete $c/fhir:reason
            ))
    else ()
};

declare function commigr:update-1.0-2(
      $c as element(fhir:Communication)
    )
{
    if ($c/fhir:reasonCode)
    then ()
    else
        system:as-user('vdba', 'kikl823!',
            (
                update insert <reasonCode xmlns="http://hl7.org/fhir">
                              { $c/fhir:reason/* }
                              </reasonCode>
                        following $c/fhir:reason
            ))
};

declare function commigr:update-1.0-1(
      $c as element(fhir:Communication)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
                update delete $c/fhir:lastModified
            ,   update delete $c/fhir:lastModifiedBy
            ))
};

declare function commigr:update-1.0-0(
      $c as element(fhir:Communication)
    )
{
    if ($c/fhir:lastModified)
    then
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
    else ()
};
(:~
 : create collections for Communications per year
 : data
 :     - 2016
 :     - 2017
 :     ...
 :     - 2026
 :)
declare function commigr:createDirs()
{

    let $years := for $year in (2016 to 2026)
        return
            (
              xdb:create-collection($commigr:collpath, xs:string($year))
            , commigr:fixPath(concat($commigr:collpath,'/',$year))
            )
    return
        ()
};

declare %private function commigr:fixPath($path)
{
    sm:chown($path, 'admin'),
    sm:chgrp($path, 'spz'),
    sm:chmod($path, "rwxrwxr-x")
};
declare function commigr:update-0.9($e as element(fhir:Communication))
{
    let $pathCurrent  := util:collection-name($e)
    let $nameCurrent  := util:document-name($e)
    let $year   := substring($e/fhir:sent/@value,1,4)
    return
        if (xs:integer($year)>2016 and xs:integer($year)<2027)
        then
            let $target := concat($commigr:collpath,'/',$year)
            return
                system:as-user('vdba', 'kikl823!', 
                    xmldb:copy($pathCurrent, $target, $nameCurrent)
                )
        else 
            let $target := concat($commigr:collpath,'/invalid')
            return
                system:as-user('vdba', 'kikl823!', 
                    xmldb:copy($pathCurrent, $target, $nameCurrent)
                )
};

(:~
 : migrates pre Nabu 0.8 to FHIR v3.0.1 
 : pre 0.8
 :)
declare function commigr:update-0.8($communication as element(fhir:Communication))
{
    system:as-user('vdba', 'kikl823!',
            (
              update replace $communication/fhir:meta/fhir:versionID with
                <versionId xmlns="http://hl7.org/fhir" value="{$communication/fhir:meta/fhir:versionID/@value/string()}"/>
            , update replace $communication/fhir:note with
                <note xmlns="http://hl7.org/fhir">
                    <text value="{$communication/fhir:note/@value/string()}"/>
                </note>
            ))
};
