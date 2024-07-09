xquery version "3.0";
module namespace condition = "http://enahar.org/exist/apps/nabu/condition";

declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";


declare function condition:fillTemplate(
          $csc as xs:string
        , $csd as xs:string
        , $vsc as xs:string
        , $vsd as xs:string 
        , $category as xs:string
        , $severity as xs:string
        , $icd as xs:string?
        , $icdtext as xs:string?
        , $dxtext as xs:string?
        , $subject as item()
        , $onset as xs:string?
        , $abatement as xs:string?
        , $recorder as item()
        , $asserter as item()
        , $evi-system as xs:string*
        , $evi-code as xs:string*
        , $evi-disp as xs:string*
        , $note as xs:string
        ) as item()
{
    let $catdisp := switch ($category)
        case 'diagnosis' return "Diagnose"
        case 'symptom' return 'Symptom'
        case 'complaint' return 'Beschwerde'
        case 'finding' return 'Befund'
        default return ''
    let $sevdisp := switch ($severity)
        case '399166001' return "Fatal"
        case '24484000' return 'Schwer'
        case '6736007' return 'Mittelgradig'
        case '255604002' return 'Milde'
        default return ''
    let $dateRecorded := current-dateTime()
    return
        <Condition xmlns="http://hl7.org/fhir">
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <clinicalStatus>
                <coding>
                    <code value="{$csc}"/>
                    <display value="{$csd}"/>
                </coding>
                <text value="{$csd}"/>
            </clinicalStatus>
            <verificationStatus>
                <coding>
                    <code value="{$vsc}"/>
                    <display value="{$vsd}"/>
                </coding>
                <text value="{$vsd}"/>
            </verificationStatus>
            <category>
                <coding>
                    <system value="http://hl7.org/fhir/condition-category"/>
                    <code value="{$category}"/>
                    <display value="{$catdisp}"/>
                </coding>
                <text value="{$catdisp}"/>
            </category>
            <severity>
                <coding>
                    <system value="http://snomed.info/sct"/>
                    <code value="{$severity}"/>
                    <display value="{$sevdisp}"/>
                </coding>
                <text value="{$sevdisp}"/>                
            </severity>
            { if ($category='diagnosis')
                then
                <code xmlns="http://hl7.org/fhir">
                    <coding>
                        <system value="http://hl7.org/fhir/sid/icd-10-de"/>
                        <version value="2016"/>
                        <code value="{$icd}"/>
                        <display value="{$icdtext}"/>
                    </coding>
                    <coding>
                        <system value="http://eNahar.org/nabu/extension#terminology-mas"/>
                        <version value="2016"/>
                        <code value=""/>
                        <display value=""/>
                    </coding>
                    <coding>
                        <system value="http://eNahar.org/nabu/extension#nabu-diagnosis-category"/>
                        <version value="2016"/>
                        <code value=""/>
                        <display value=""/>
                    </coding>
                    <text value="{$dxtext}"/>
                </code>
                else if ($category='finding')
                then
                <code xmlns="http://hl7.org/fhir">
                    <coding>
                        <system value="http://eNahar.org/nabu/extension#nabu-finding"/>
                        <version value="2017"/>
                        <code value="{$icd}"/>
                        <display value="{$dxtext}"/>
                    </coding>
                    <text value="{$dxtext}"/>
                </code>
                else ()
            }
            { $subject } 
            <encounter>
                <reference value=""/>
                <display value=""/>
            </encounter>
            <onsetDateTime value="{$onset}"/>
            <abatementDateTime value="{$abatement}"/>
            <recordedDate value="{$dateRecorded}"/>
            { $recorder }
            { $asserter }
            {
                if ($evi-system)
                then
                    <evidence>
                        <code>
                            <coding>
                                <system value="{$evi-system}"/>
                                <code value="{$evi-code}"/>
                                <display value="{$evi-disp}"/>
                            </coding>
                            <text value="{$evi-disp}"/>  
                        </code>
                        <detail>
                            <reference value=""/>
                        </detail>
                    </evidence>
                else ()
            }
            <note>
                <text value="{$note}"/>
            </note>
        </Condition>
};