xquery version "3.0";

module namespace goalmigr = "http://enahar.org/exist/apps/nabu/goal-migration";

declare namespace fhir= "http://hl7.org/fhir";


declare function goalmigr:update-1.0-5(
      $g as element(fhir:Goal)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
             update value 
                $g/fhir:priority/fhir:coding[fhir:system/@value="http://hl7.org/fhir/ValueSet/priority-category"]/fhir:system/@value
                with 
                    "http://hl7.org/fhir/ValueSet/goal-priority"
            ))
};

declare function goalmigr:update-1.0-4(
      $g as element(fhir:Goal)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
              update value $g/fhir:category/fhir:coding/fhir:code/@value with "treatment"
            , update value $g/fhir:category/fhir:coding/fhir:display/@value with "Behandlung"
            , update value $g/fhir:category/fhir:text/@value with "Behandlung"
            ))
};

declare function goalmigr:update-1.0-3(
      $g as element(fhir:Goal)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
              update insert 
                    <coding xmlns="http://hl7.org/fhir">
                        <system value="http://eNahar.org/nabu/extension#nabu-finding"/>
                        <version value="2017"/>
                        <code value=""/>
                        <display value=""/>
                    </coding>
                    into  $g/fhir:description
            , update insert <display xmlns="http://hl7.org/fhir" value=""/>
                    into  $g/fhir:category/fhir:coding
            ))
};

declare function goalmigr:update-1.0-2(
      $g as element(fhir:Goal)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
                update delete $g/fhir:lastModified
            ,   update delete $g/fhir:lastModifiedBy
            , update insert 
                <achievementStatus xmlns="http://hl7.org/fhir">
                    <coding>
                        <system value="http://hl7.org/fhir/ValueSet/goal-achievement"/>
                        <code value="in-progress"/>
                    </coding>
                    <text value="in Arbeit"/>
                </achievementStatus>
                    following $g/fhir:lifecycleStatus
            ))
};

declare function goalmigr:update-1.0-1(
      $g as element(fhir:Goal)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
              update insert <lastUpdated xmlns="http://hl7.org/fhir" value="{$g/fhir:lastModified/@value/string()}"/>
                        into $g/fhir:meta
            , update insert <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                                <reference value="{$g/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                                <display value="{$g/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                            </extension>
                        into $g/fhir:meta
            , update replace $g/fhir:status with 
                        <lifecycleStatus xmlns="http://hl7.org/fhir" value="{$g/fhir:status/@value/string()}"/>
            ))
};

