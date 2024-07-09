xquery version "3.0";

module namespace patmigr = "http://enahar.org/exist/apps/nabu/patient-migration";

import module namespace patutils = "http://enahar.org/exist/apps/nabu/patutils" at "/db/apps/nabu/FHIR/Patient/patutils.xqm";

declare namespace fhir= "http://hl7.org/fhir";

declare function patmigr:repair-1.0-3(
      $patient as element(fhir:Patient)
    )
{
    if ($patient/fhir:address/fhir:preferred)
    then
        system:as-user('vdba', 'kikl823!',
            (
                update delete $patient/fhir:address/fhir:preferred
            ))
    else ()
};

declare function patmigr:repair-1.0-2(
      $patient as element(fhir:Patient)
    )
{
    let $ext := $patient/fhir:contact/fhir:extension[@url='#patient-contact-preferred']
    return
    if ($ext)
    then
        system:as-user('vdba', 'kikl823!',
            (
              if ($contact/fhir:extension[@url="#patient-contact-preferred"]/fhir:valueBoolean)
              then
                update delete $contact/fhir:preferred
              else ()
            , update replace $ext with
                        <extension  xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension/patient-contact-preferred">
                            <valueBoolean value="{$ext/fhir:valueBoolean/@value/string()}"/>
                        </extension>
            ))
    else ()
};


declare function patmigr:repair-1.0-1(
      $patient as element(fhir:Patient)
    )
{
    let $ext := $patient/fhir:contact/fhir:extension[@url='#contact-note']
    return
    if ($ext/fhir:note)
    then
        system:as-user('vdba', 'kikl823!',
            (
                if ($ext/fhir:note/@value='')
                then
                    update delete $ext
                else
                    update replace 
                                $ext
                            with 
                        <extension  xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension/contact-note">
                            <valueString value="{$ext/fhir:note/@value/string()}"/>
                        </extension>
            ))
    else ()
};

declare function patmigr:repair-0.9.11-6(
      $patient as element(fhir:Patient)
    )
{
    let $ext := $patient/fhir:meta/fhir:extension[@url='#lastUpdatedBy']
    return
    if ($ext/fhir:reference)
    then

        let $ref := $ext/fhir:reference/@value/string()
        let $disp := $ext/fhir:display/@value/string()
        return
        system:as-user('vdba', 'kikl823!',
            (
              update replace 
                    $patient/fhir:meta/fhir:extension[@url='#lastUpdatedBy']
                    with 
                    <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                        <valueReference>
                                <reference value="{$ref}"/>
                                <display value="{$disp}"/>
                        </valueReference>
                    </extension>
            ))
    else ()
};


(: 
 : 493 Patients with double text property??
 :)
declare function patmigr:repair-0.9-11-5(
      $patient as element(fhir:Patient)
    )
{
    if (count($patient/fhir:text)>1)
    then
        let $ltxt := $patient/fhir:text[2]
        return
            system:as-user('vdba', 'kikl823!',
            (
              update delete $ltxt
            ))
    else ()
};

(: 
 : two patients had spurious text/@value property from language coding
 :)
declare function patmigr:repair-0.9-11-4(
      $patient as element(fhir:Patient)
    )
{
    if ($patient/fhir:text/@value and $patient/fhir:communication)
    then
        let $ltxt := $patient/fhir:text[@value='Deutsch']
        return
            system:as-user('vdba', 'kikl823!',
            (
                (:
                update insert $ltxt following $patient/fhir:communication/fhir:language/fhir:coding
                :)
              update delete $ltxt
            ))
    else ()
};

declare function patmigr:update-0.9-11-3(
      $patient as element(fhir:Patient)
    )
{
    system:as-user('vdba', 'kikl823!',
            (
                update delete $patient/fhir:careProvider
            ,   update delete $patient/fhir:lastModified
            ,   update delete $patient/fhir:lastModifiedBy
            ,   update delete $patient/fhir:telecom/fhir:preferred
            ,   update delete $patient/fhir:contact/fhir:telecom/fhir:preferred
            ))
};

declare function patmigr:update-0.9-11-2(
      $patient as element(fhir:Patient)
    )
{
    let $gps := 
        for $cp in $patient/fhir:careProvider
        return
            <generalPractitioner xmlns="http://hl7.org/fhir">
                {$cp/fhir:reference}
                {$cp/fhir:display}
                <extension url="#patient-gp-preferred">
                    <valueBoolean value="{$cp/fhir:preferred/@value/string()}"/>
                </extension>
                <extension url="#patient-gp-specialty">
                    <valueString value="{$cp/fhir:specialty/@value/string()}"/>
                </extension>
                <extension url="#patient-gp-period">
                    <valuePeriod>
                        <start value="{$cp/fhir:period/fhir:start/@value/string()}"/>
                        <end value="{$cp/fhir:period/fhir:end/@value/string()}"/>
                    </valuePeriod>
                </extension>
            </generalPractitioner>
    let $upd := 
            system:as-user('vdba', 'kikl823!',
            (
              for $gp in $gps
                return
                      update insert $gp
                        following $patient/fhir:careProvider
            , for $t in $patient/fhir:telecom
              return
                  if ($t/fhir:preferred/@value='true')
                  then update insert <rank xmlns="http://hl7.org/fhir" value="1"/> into $t
                  else update insert <rank xmlns="http://hl7.org/fhir" value="0"/> into $t
            , for $t in $patient/fhir:contact/fhir:telecom
              return
                  if ($t/fhir:preferred/@value='true')
                  then update insert <rank xmlns="http://hl7.org/fhir" value="1"/> into $t
                  else update insert <rank xmlns="http://hl7.org/fhir" value="0"/> into $t
            , for $c in $patient/fhir:contact
              return
                  update insert 
                            <extension xmlns="http://hl7.org/fhir" url="#patient-contact-preferred">
                              <valueBoolean value="{$c/fhir:preferred/@value/string()}"/>
                            </extension>
                         into $c
            ))
    return
        $patient
};


declare function patmigr:update-0.9-11-1(
      $patient as element(fhir:Patient)
    )
{
    let $text := patutils:generateText($patient)
    return
        system:as-user('vdba', 'kikl823!',
            (
              update insert $text following $patient/fhir:meta
            , update insert <lastUpdated xmlns="http://hl7.org/fhir" value="{$patient/fhir:lastModified/@value/string()}"/>
                        into $patient/fhir:meta
            , update insert <extension xmlns="http://hl7.org/fhir" url="#lastUpdatedBy">
                                <reference value="{$patient/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                                <display value="{$patient/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                            </extension>
                        into $patient/fhir:meta
            ))
};

declare function patmigr:update-0.9-00(
      $patient as element(fhir:Patient)
    )
{
        system:as-user('vdba', 'kikl823!',
            (
                update delete $patient/fhir:extension[@url="#patient-presenting-problem"] 
            ))
};

declare function patmigr:update-0.8-31($patient as element(fhir:Patient))
{
    system:as-user('vdba', 'kikl823!',
        (
              update value $patient/fhir:name[fhir:use/@value='official']/fhir:given/@value with 
                normalize-space($patient/fhir:name[fhir:use/@value='official']/fhir:given/@value)
        ))
};

(:~
 : migrates Patient pre Nabu 0.8 to Patient v3.0.1 
 : pre 0.8
    <communication>
        <language>
            <coding>
            <system value="urn:ietf:bcp:47"/>
            <code value="de"/>
            <display value="Deutsch"/>
        </coding>
            <text value="Deutsch"/>
        </language>
        <preferred value="true"/>
    </communication>
    <extension url="#patient-presenting-problem">
        <presenting-problem value="..."/>
    </extension>
    <extension url="#patient-insurance">
        <medical-insurance>
            <type value="gkv"/>
            <name value="MH plus"/>
        </medical-insurance>
    </extension>
    
    delete empty identifier???
 :)
 
declare function patmigr:update-0.8($patient as element(fhir:Patient))
{
    let $comm := $patient/fhir:communication
    let $ext-problem := $patient/fhir:extension[@url='#patient-presenting-problem']
    let $ext-ins     := $patient/fhir:extension[@url='#patient-insurance']
    return
        system:as-user('vdba', 'kikl823!',
            (
              update replace $patient/fhir:meta/fhir:versionID with
                <versionId xmlns="http://hl7.org/fhir" value="{$patient/fhir:meta/fhir:versionID/@value/string()}"/>
            , update replace $patient/fhir:communication with 
                <communication xmlns="http://hl7.org/fhir">
                    <language>
                        {$comm/fhir:coding}
                        {$comm/fhir:text}
                    </language>
                    <preferred value="true"/>
                </communication>
            , update replace $patient/fhir:extension[@url="#patient-presenting-problem"] with 
                <extension  xmlns="http://hl7.org/fhir" url="#patient-presenting-problem">
                    <valueAnnotation>
                        <authorReference>
                            <reference value=""/>
                            <display value=""/>
                        </authorReference>
                        <time value=""/>
                        <text value="{$ext-problem/fhir:presenting-problem/@value/string()}"/>
                    </valueAnnotation>
                </extension>
            , update replace $patient/fhir:extension[@url="#patient-insurance"] with 
                <extension xmlns="http://hl7.org/fhir" url="#patient-medical-insurance">
                    <valueCodeableConcept>
                        <coding>
                            <system value="#patient-medical-insurance"/>
                            <code value="{$ext-ins//fhir:type/@value/string()}"/>
                            <display value="{$ext-ins//fhir:name/@value/string()}"/>
                        </coding>
                    </valueCodeableConcept>
                </extension>
            , update value $patient/fhir:name[fhir:use/@value='official']/fhir:family/@value with 
                normalize-space($patient/fhir:name[fhir:use/@value='official']/fhir:family/@value)
            ))
};
