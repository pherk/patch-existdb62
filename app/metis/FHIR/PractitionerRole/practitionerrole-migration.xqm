xquery version "3.0";

module namespace prmigr = "http://enahar.org/exist/apps/metis/pr-migration";




declare namespace fhir= "http://hl7.org/fhir";

declare function prmigr:update-1.0-2(
        $p as element(fhir:PractitionerRole)
      , $id as xs:string*
    )
{
    if ($id and $id!='')
    then
        let $upd :=
            system:as-user('vdba', 'kikl823!',
                (
                 update value $p/fhir:id/@value with $id
                ))
        return ()
    else $p
};
 

declare function prmigr:generate-1.0-1(
      $p as element(fhir:Practitioner)
    )
{
    let $identifier := $p/fhir:identifier[fhir:system/@value='http://eNahar.org/nabu/system#metis-account']
    let $name := string-join(($p/fhir:name/fhir:family/@value,$p/fhir:name/fhir:given/@value),",")
    let $code := <code xmlns="http://hl7.org/fhir">
        {for $c in $p/fhir:role/fhir:coding
         return
            $c
        }
        </code>
    let $specialty := $p/fhir:specialty
    let $telecom := $p/fhir:telecom[fhir:use/@value='work']
    let $pr :=
    <PractitionerRole xmlns="http://hl7.org/fhir">
        <id value="{$p/fhir:id/@value/string()}"/>
        <meta>
            <versionId value="0"/>
            <lastUpdated value=""/>
            <extension url="">
                <valueReference>
                    <reference value=""/>
                    <display value=""/>
                </valueReference>
            </extension>
        </meta>
            {$identifier}
            <active value="{$p/fhir:active/@value/string()}"/>
            <practitioner>
                <reference value="metis/practitioners/{$p/fhir:id/@value/string()}"/>
                <display value="{$name}"/>
            </practitioner>
            <organization>
                <reference value="metis/organizations/ukk-kikl-spzn"/>
                <display value="nSPZ Kinderklinik"/>                   
            </organization>
            {$code}
            {$specialty}
            {$telecom}
            <location>
                <reference value="metis/locations/ukk-kikl-spzn"/>
                <display value="SPZ Kinderklinik Haus70/CIO"/>                
            </location>
            <healthcareService>
                <reference value="metis/HealthcareService/ukk-kikl-spzn"/>
                <display value="nSPZ Kinderklinik UKK"/>
            </healthcareService>
        </PractitionerRole>
    return
        $pr
};
