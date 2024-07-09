xquery version "3.0";

module namespace cpmigr = "http://enahar.org/exist/apps/nabu/careplan-migration";

declare namespace fhir= "http://hl7.org/fhir";

declare function cpmigr:update-1.0-1(
      $c as element(fhir:CarePlan)
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

declare function cpmigr:update-1.0-0(
      $c as element(fhir:CarePlan)
    )
{
    if ($c/fhir:meta/fhir:lastUpdated)
    then ()
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
 : migrates Order 0.8 to 0.8-26
 : status value-set change for compatiblity with Request FHIR 3.0.1 
 : insert status in details analog to the status in Appointment 
 : and update value from Encounter
 : TODO: eliminate extension e.g. analog to RequestGroup
 :)
declare function cpmigr:update-0.8-26($cp as element(fhir:CarePlan))
{
        system:as-user('vdba', 'kikl823!',
            (
              update delete $cp/fhir:activity/fhir:status
            ))
};