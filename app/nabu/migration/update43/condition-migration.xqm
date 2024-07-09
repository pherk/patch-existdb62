xquery version "3.0";

module namespace condmigr = "http://enahar.org/exist/apps/nabu/condition-migration";

declare namespace fhir= "http://hl7.org/fhir";
declare variable $condmigr:infos := doc('db/apps/nabu/FHIR/Condition/condition-infos.xml');

declare function condmigr:migrate-1.0-7(
          $condition as element(fhir:Condition)
        )
{
    system:as-user('vdba', 'kikl823!',
        (
          update delete $condition/fhir:identifier
        , update delete $condition/fhir:evidence/fhir:detail
        ))
};

declare function condmigr:migrate-1.0-6(
          $condition as element(fhir:Condition)
        )
{
    if ($condition/fhir:onsetDateTime)
    then ()
    else
        system:as-user('vdba', 'kikl823!',
            (
              update replace $condition/fhir:onsetDatetime
                    with
                    <onsetDateTime value="{$condition/fhir:onsetDatetime/@value/string()}"/>
            ))
};

declare function condmigr:migrate-1.0-5(
          $condition as element(fhir:Condition)
        )
{
    if ($condition/fhir:encounter)
    then ()
    else
        system:as-user('vdba', 'kikl823!',
            (
              update replace $condition/fhir:context
                    with
                    <encounter xmlns="http://hl7.org/fhir">
                        <reference value="{$condition/fhir:context/fhir:reference/@value/string()}"/>
                        <display value="{$condition/fhir:context/fhir:display/@value/string()}"/>
                    </encounter>
            ))
};

(:~
 :  FHIR 4.0.1
 :   
 :  clinicalStatus -> CodeableConcept
 :  verificationStatus -> CodeableConcept 
 :  assertedDate -> recordedDate
 :  asserter -> recorder
 : 
 :)
declare function condmigr:migrate-1.0-4(
          $condition as element(fhir:Condition)
        )
{
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update value $condition/fhir:code/fhir:coding[fhir:system[@value='#nabu-finding']]/fhir:system/@value 
                    with 'http://eNahar.org/nabu/extension#nabu-finding'
        (:
              update value $condition/fhir:code/fhir:coding[fhir:system[@value='#terminology-mas']]/fhir:system/@value 
                    with 'http://eNahar.org/nabu/extension#terminology-mas'
            , update value $condition/fhir:code/fhir:coding[fhir:system[@value='#nabu-diagnosis-category']]/fhir:system/@value 
                    with 'http://eNahar.org/nabu/extension#nabu-diagnosis-category'
        :)
            ))
    return
        $condition
};

declare function condmigr:migrate-1.0-3(
          $condition as element(fhir:Condition)
        )
{
    let $csc := $condition/fhir:clinicalStatus/@value/string()
    let $csd := $condmigr:infos/clinicalStatus/code[@value=$csc]/@label-de/string()
    let $vsc := switch ($condition/fhir:verificationStatus/@value)
        case "unknown" return "unconfirmed"
        default return $condition/fhir:verificationStatus/@value/string()
    let $vsd := $condmigr:infos/verificationStatus/code[@value=$condition/fhir:verificationStatus/@value]/@label-de/string()
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update replace $condition/fhir:clinicalStatus 
                    with
                    <clinicalStatus xmlns="http://hl7.org/fhir">
                        <coding>
                            <code value="{$csc}"/>
                            <display value="{$csd}"/>
                        </coding>
                        <text value="{$csd}"/>
                    </clinicalStatus>
            ,   update replace $condition/fhir:verificationStatus 
                    with
                    <verificationStatus xmlns="http://hl7.org/fhir">
                        <coding>
                            <code value="{$vsc}"/>
                            <display value="{$vsd}"/>
                        </coding>
                        <text value="{$vsd}"/>
                    </verificationStatus>
            ))
    return
        $condition
};

declare function condmigr:migrate-1.0-2(
          $condition as element(fhir:Condition)
        )
{
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update delete $condition/fhir:lastModified
            , update delete $condition/fhir:lastModifiedBy
            , update delete $condition/fhir:assertedDate
            ))
    return
        $condition
};

declare function condmigr:migrate-1.0-1(
          $condition as element(fhir:Condition)
        )
{
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update insert <lastUpdated xmlns="http://hl7.org/fhir" value="{$condition/fhir:lastModified/@value/string()}"/>
                            into $condition/fhir:meta
            , update insert <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                                <valueReference>
                                    <reference value="{$condition/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                                    <display value="{$condition/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                                </valueReference>
                            </extension>
                            into $condition/fhir:meta
            , update insert <recordedDate xmlns="http://hl7.org/fhir" value="{$condition/fhir:assertedDate/@value/string()}"/>
                    following $condition/fhir:assertedDate
            , update insert <recorder xmlns="http://hl7.org/fhir">
                                {$condition/fhir:asserter/*}
                            </recorder>
                    following $condition/fhir:asserter
            ))
    return
        $condition
};

(:~
 : migrates pre Nabu 0.8 to FHIR v3.0.1 
 : pre 0.8
 : versionID -> versionId
 : note/@value -> Annotation
 : axis -> code
 :)
declare function condmigr:update-0.8($condition as element(fhir:Condition))
{
    system:as-user('vdba', 'kikl823!',
            (
              update replace $condition/fhir:meta/fhir:versionID with
                <versionId  xmlns="http://hl7.org/fhir" value="{$condition/fhir:meta/fhir:versionID/@value/string()}"/>
            , update replace $condition/fhir:note with 
                <note xmlns="http://hl7.org/fhir">
                    <authorReference>
                        <reference value="{$condition/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                        <display value="{$condition/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                    </authorReference>
                    <time value="{$condition/fhir:lastModified/@value/string()}"/>
                    <text value="{$condition/fhir:note/@value/string()}"/>
                </note>
            , update replace $condition/fhir:onset with 
                <onsetDatetime xmlns="http://hl7.org/fhir" value="{$condition/fhir:onset/@value/string()}"/>
            , update replace $condition/fhir:abatement with 
                <abatementDateTime xmlns="http://hl7.org/fhir" value="{$condition/fhir:abatement/@value/string()}"/>
            , update delete $condition/fhir:stage
            , update replace $condition/fhir:code/fhir:coding[fhir:system/@value='#nabu-diagnosis-category']/fhir:axis with 
                <code xmlns="http://hl7.org/fhir" value="{$condition/fhir:code/fhir:coding[fhir:system/@value='#nabu-diagnosis-category']/fhir:axis/@value/string()}"/>
            , update replace $condition/fhir:code/fhir:coding[fhir:system/@value='#terminology-mas']/fhir:axis with 
                <code xmlns="http://hl7.org/fhir" value="{$condition/fhir:code/fhir:coding[fhir:system/@value='#terminology-mas']/fhir:axis/@value/string()}"/>
            ))
};
