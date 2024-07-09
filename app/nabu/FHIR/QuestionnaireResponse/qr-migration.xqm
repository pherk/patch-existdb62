xquery version "3.0";

module namespace qrmigr = "http://enahar.org/exist/apps/nabu/qr-migration";

import module namespace date = "http://enahar.org/exist/apps/nabu/date" at "../../modules/date.xqm";
import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients" at "../../FHIR/Patient/patient-routes.xqm";

declare namespace fhir= "http://hl7.org/fhir";

declare function qrmigr:update-1.0-1(
      $c as element(fhir:QuestionnaireResponse)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
                update delete $c/fhir:lastModified
            ,   update delete $c/fhir:lastModifiedBy
            ))
};

declare function qrmigr:update-1.0-0(
      $c as element(fhir:QuestionnaireResponse)
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