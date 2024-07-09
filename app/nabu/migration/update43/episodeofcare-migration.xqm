xquery version "3.1";

module namespace eocmigr = "http://enahar.org/exist/apps/nabu/episodeofcare-migration";

declare namespace fhir= "http://hl7.org/fhir";

(: 
 : v4.0.1
 : subject -> patient
 : diagnosis/use -> diagnosis/role
 : system	http://hl7.org/fhir/ValueSet/diagnosis-role
 : extension full url
 : v5.0
 : team -> careteam

 :)
declare function eocmigr:update-1.0-3(
      $eo as element(fhir:EpisodeOfCare)
    )
{
    if ($eo/fhir:patient)
    then ()
    else
        let $sref := $eo/fhir:subject/fhir:reference/@value/string()
        let $sdisp := $eo/fhir:subject/fhir:display/@value/string()
        return
        system:as-user('vdba', 'kikl823!',
            (
              update replace $eo/fhir:subject    with 
                <patient xmlns="http://hl7.org/fhir">
                    <reference value="{$sref}"/>
                    <display value="{$sdisp}"/>
                </patient>
            ))
};

declare function eocmigr:update-1.0-2(
      $ct as element(fhir:EpisodeOfCare)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
              update value $ct/*/fhir:extension[@url='#eoc-workflow-change']/@url        with 'http://eNahar.org/nabu/extension#eoc-workflow-change'
            , update value $ct/*/fhir:extension/*/fhir:system/@url  with 'http://eNahar.org/nabu/ValueSet/eoc-workflow-change-reason'
            , update value $ct/*/fhir:extension[@url='#eoc-workflow-change-author']/@url with 'http://eNahar.org/nabu/extension#eoc-workflow-change-author'
            ))
};

declare function eocmigr:update-1.0-1(
      $ct as element(fhir:EpisodeOfCare)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
                update delete $ct/fhir:lastModified
            ,   update delete $ct/fhir:lastModifiedBy
            ))
};



declare function eocmigr:update-1.0-0(
      $ct as element(fhir:EpisodeOfCare)
    )
{
    if ($ct/fhir:lastModified)
    then
        system:as-user('vdba', 'kikl823!',
            (
              update insert <lastUpdated xmlns="http://hl7.org/fhir" value="{$ct/fhir:lastModified/@value/string()}"/>
                        into $ct/fhir:meta
            , update insert <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                                <valueReference>
                                    <reference value="{$ct/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                                    <display value="{$ct/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                                </valueReference>
                            </extension>
                        into $ct/fhir:meta
            ))
    else ()
};