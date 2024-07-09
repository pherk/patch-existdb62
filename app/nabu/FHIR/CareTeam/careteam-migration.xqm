xquery version "3.1";

module namespace ctmigr = "http://enahar.org/exist/apps/nabu/careteam-migration";

declare namespace fhir= "http://hl7.org/fhir";

(: 
 : v4.3.0
 : category/@url 	http://hl7.org/fhir/ValueSet/care-team-category
 : participant/role/system http://eNahar.org/nabu/system#careteam-participant-role :: is set by regenerate-careteams script
 : date with timezone :: nd yet
 : v5.0.1
 : participant/period -> participant/coveragePeriod
 :)

declare function ctmigr:update-1.0-2(
      $ct as element(fhir:CareTeam)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
                update value $ct/fhir:category/@url with "http://hl7.org/fhir/ValueSet/care-team-category"
            ))
};


declare function ctmigr:update-1.0-1(
      $ct as element(fhir:CareTeam)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
                update delete $ct/fhir:lastModified
            ,   update delete $ct/fhir:lastModifiedBy
            ,   update delete $ct/fhir:context
            ))
};



declare function ctmigr:update-1.0-0(
      $ct as element(fhir:CareTeam)
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