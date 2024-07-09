xquery version "3.0";

module namespace qrimport = "http://enahar.org/exist/apps/nabu/qr-import";

import module namespace date = "http://enahar.org/exist/apps/nabu/date" at "../../modules/date.xqm";

import module namespace qrtf = "http://enahar.org/exist/apps/nabu/qr-transform" at "../../FHIR/QuestionnaireResponse/qrtf.xqm";
import module namespace cond = "http://enahar.org/exist/apps/nabu/condition" at "../../FHIR/Condition/condition.xqm";
import module namespace careplan = "http://enahar.org/exist/apps/nabu/careplan" at "../../FHIR/CarePlan/careplan.xqm";
import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients" at "../../FHIR/Patient/patient-routes.xqm";

declare namespace fhir= "http://hl7.org/fhir";

declare variable $qrimport:mapNeoDat2QR :=
    <neodat>
        <field name="PAT_NR"     linkId="orbis-pid" type="integer"/>
        <field name="SPZ"        linkId="qm-spz" type="string"/>
        <field name="Bayley"     linkId="qm-bayley" type="string"/>
        <field name="FAM_NAME"   linkId="pat-family" type="string"/>
        <field name="VORNAME"    linkId="pat-given" type="string"/>
        <field name="GEB"        linkId="pat-birthdate" type="date-de"/>
        <field name="GESCHLECHT" linkId="pat-sex" type="string"/>
        <field name="WunschTestDat" linkId="qm-plandat" type="date-de"/>
        <field name="GEBGEW"     linkId="birth-weight" type="decimal-de"/>
        <field name="GEST_ALT"   linkId="pca-weeks" type="integer"/>
        <field name="GEST_ALTD"  linkId="pca-days" type="integer"/>
        <field name="ERR_TERMIN" linkId="et" type="date-de"/>
        <field name="MEHRLZ"     linkId="birth-multiple-n" type="integer"/>
        <field name="MEHRLNR"    linkId="birth-multiple-nth" type="integer"/>
        <field name="ICH_GRADMA" linkId="outcome-ichgradma" type="integer"/>
        <field name="ICH_PARENA" linkId="outcome-ichparena" type="boolean-de"/>
        <field name="PVL"        linkId="outcome-pvl" type="boolean-de"/>
        <field name="BPD_STAT"   linkId="outcome-bpd" type="integer"/>
        <field name="NEC"        linkId="outcome-nec" type="integer"/>
        <field name="NGB_KRAMPF" linkId="outcome-ngka" type="boolean-de"/>
        <field name="HIE"        linkId="outcome-hie" type="integer"/>
        <field name="VERSTORB"   linkId="enc-death" type="boolean-de"/>
        <field name="AUFN_DAT"   linkId="enc-admission" type="dateTime-de"/>
        <field name="ENTL_DAT"   linkId="enc-dismissal" type="dateTime-de"/>
        <field name="PAT_ID"     linkId="neodat-pid" type="integer"/>
    </neodat>;

declare function qrimport:isAlreadyImported($p) as xs:boolean
{
  false()  
};

declare function qrimport:checkPatData($p) as xs:boolean
{
  false()  
  (:
 function r-condition:conditionsXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $onsetStart as xs:string*
        , $onsetEnd as xs:string*
        , $subject as xs:string*
        , $status as xs:string*
        , $verification as xs:string*
        , $category as xs:string*
        , $code as xs:string*
        , $format as xs:string*
        , $sort as xs:string*
        ) as item()
  :)
  (:  function r-careplan:careplansXML(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $author as xs:string*
        ,   $subject as xs:string*
        ,   $status as xs:string*
        ,   $format as xs:string*
        ) as item()
    :)
};


declare %private function qrimport:boolean-de($t as xs:string) as xs:boolean
{
    $t!="FALSCH"    
};
declare %private function qrimport:date-de($d as xs:string) as xs:date
{
    date:easyDate($d)
};
declare %private function qrimport:dateTime-de($d as xs:string) as xs:dateTime
{
    let $toks := tokenize($d,' ')
    return
        dateTime(date:easyDate($toks[1]),xs:time(concat($toks[2],':00')))
};
declare %private function qrimport:decimal-de($d as xs:string) as xs:string
{
    replace($d,',','.')
};

declare %private function qrimport:mapValue($f as xs:string, $type as xs:string) as item()
{
    switch ($type)
    case 'string'     return <value>{$f}</value>
    case 'boolean-de' return <value>{qrimport:boolean-de($f)}</value>
    case 'integer'    return <value>{$f}</value>
    case 'date-de'    return try {
                                <value>{qrimport:date-de($f)}</value>
                           } catch * {
                                let $lll := util:log-system-out($f)
                                return
                                    <value>{xs:date('1900-01-01')}</value>
                            }
    case 'dateTime-de' return try {
                                <value>{qrimport:dateTime-de($f)}</value>
                            } catch * {
                                let $lll := util:log-system-out($f)
                                return
                                    <value>{xs:dateTime('1900-01-01T00:00:00')}</value>
                            }
    case 'decimal-de' return <value>{qrimport:decimal-de($f)}</value>
    default return <value>{$f}</value>
};

declare %private function qrimport:mapLanguage($l)
{
    switch ($l)
    case '-1' return 'de-de'
    default return 'other' 
};

declare %private function qrimport:mapSex($l)
{
    switch ($l)
    case '1' return 'male'
    case '2' return 'female'
    default return 'other' 
};

declare %private function qrimport:analyzeNeoDatFields($fstring,$header)
{
    let $fs := tokenize($fstring,'\t')
    return
    <patient>
    {
        for $f at $n in $fs
        let $fd  := $qrimport:mapNeoDat2QR/field[$n]
        let $val := qrimport:mapValue($f,$fd/@type)
        return
            <field name="{$fd/@name/string()}" linkId="{$fd/@linkId/string()}" value="{$val}"/>
    }
    </patient>
};

(:~
 : import NeoDat QM data to FHIR v3.0.1 
 : pre 0.8
 :)
declare function qrimport:mkNeoDatQR(
      $patient as item()
    , $header
    , $quest as element(fhir:Questionnaire)
    ) as item()*
{
    let $fs := qrimport:analyzeNeoDatFields($patient/string(),$header)
    let $orbis-pid := $fs/field[@linkId='orbis-pid']/@value/string()
    let $pat := r-patient:patientByIdentifierXML($orbis-pid,'kikl-spz','u-admin','Admin')
    return
        if ($pat/fhir:id)
        then
    let $pref := concat('nabu/patients/',$pat/fhir:id/@value)
    let $pnam := r-patient:formatFHIRName($pat)

    let $demography := qrtf:mkQRItem(
            $quest//fhir:item[fhir:linkId/@value='demography']
        ,   <group>
                <simple>{$orbis-pid}</simple>
                <simple>{$fs/field[@linkId='neodat-pid']/@value/string()}</simple>
                <group>
                    <simple>{$fs/field[@linkId='pat-family']/@value/string()}</simple>
                    <simple>{$fs/field[@linkId='pat-given']/@value/string()}</simple>
                    <simple>{$fs/field[@linkId='pat-birthdate']/@value/string()}T00:00:00</simple>
                    <simple>{qrimport:mapSex($fs/field[@linkId='pat-sex']/@value/string())}</simple>
                </group>
            </group>
        )
    let $perinatal := qrtf:mkQRItem(
            $quest//fhir:item[fhir:linkId/@value='perinatalInfo']
        ,   <group>
                <group>
                    <simple>{$fs/field[@linkId='pca-weeks']/@value/string()}</simple>
                    <simple>{$fs/field[@linkId='pca-days']/@value/string()}</simple>
                </group>
                <simple>{$fs/field[@linkId='et']/@value/string()}</simple>
                    <simple>{xs:integer($fs/field[@linkId='birth-multiple-n']/@value/string())>1}</simple>
                    <simple>{$fs/field[@linkId='birth-multiple-n']/@value/string()}</simple>
                    <simple>{$fs/field[@linkId='birth-multiple-nth']/@value/string()}</simple>
                    <simple>{$fs/field[@linkId='birth-weight']/@value/string()}</simple>
                    <simple>{$fs/field[@linkId='birth-length']/@value/string()}</simple>
                    <simple>{$fs/field[@linkId='birth-head-cf']/@value/string()}</simple>
            </group>
        )
    let $encounter := qrtf:mkQRItem(
            $quest//fhir:item[fhir:linkId/@value='encounter']
        ,   <group>
                <simple>{$fs/field[@linkId='enc-admission']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='enc-dismissal']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='enc-death']/@value/string()}</simple>
            </group>
        )
    let $outcome := qrtf:mkQRItem(
            $quest//fhir:item[fhir:linkId/@value='outcome']
        ,   <group>
                <simple>{$fs/field[@linkId='outcome-ichgradma']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='outcome-ichparena']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='outcome-pvl']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='outcome-bpd']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='outcome-nec']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='outcome-bpd']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='outcome-ngka']/@value/string()}</simple>
                <simple>{$fs/field[@linkId='outcome-hie']/@value/string()}</simple>
            </group>
        )
    let $authored := adjust-dateTime-to-timezone(current-dateTime(),())
    return
        <QuestionnaireResponse xmlns="http://hl7.org/fhir">
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <identifier>
                <use value="usual"/>
                <type value="ORBIS-PNR"/>
                <system value="http://uk-koeln.de/#patient-orbis-pnr"/>
                <value value="{$orbis-pid}"/>
                <assigner>
                    <reference value="metis/organizations/ukk"/>
                    <display value="Unikliniken Köln"/>
                </assigner>
            </identifier>
            <basedOn>
                <reference value=""/>
                <display value=""/>                
            </basedOn>
            <questionnaire>
                <reference value="nabu/questionnaireresponses/qr-neodat-v2017-08-08"/>
                <display value="NeoDat Import v2017-08-08"/>                
            </questionnaire>
            <status value="in-progress"/>
            <subject>
                <reference value="{$pref}"/>
                <display value="{$pnam}"/>
            </subject>
            <context>
                <reference value=""/>
                <display value=""/>                
            </context>
            <authored value="{$authored}"/>
            <author>
                <reference value="nabu/practitioners/u-admin"/>
                <display value="Admin"/>                
            </author>
            <source>
                <reference value=""/>
                <display value="NeoDat"/>
            </source>
            <item>
                <linkId value="neodat"/>
                <text value="NeoDat Importdaten"/>
                <type value="group"/>
                {$demography}
                {$perinatal}
                {$encounter}
                {$outcome}
            </item>
        </QuestionnaireResponse>
        else ()
};

(:~
 : import Bayley III QM data to FHIR v3.0.1 
<BayleyTestdaten>
<ID>567</ID>
<PatNr>8236</PatNr>
<TestDat>2007-10-23T00:00:00</TestDat>
<Untersucher>Hausen</Untersucher>
<Cog>9</Cog>
<CogAlter>11</CogAlter>
<CogZuverl>1</CogZuverl>
<RecLang>8</RecLang>
<RecLangAlter>10</RecLangAlter>
<RecLangZuverl>1</RecLangZuverl>
<ExprLang>10</ExprLang>
<ExprLangAlter>12</ExprLangAlter>
<ExprLangZuverl>1</ExprLangZuverl>
<FineMotor>9</FineMotor>
<FineMotorAlter>11</FineMotorAlter>
<FineMotorZuverl>1</FineMotorZuverl>
<GrossMotor>5</GrossMotor>
<GrossMotorAlter>9</GrossMotorAlter>
<GrossMotorZuverl>1</GrossMotorZuverl>
<FG_x0020_Woche>40</FG_x0020_Woche>
<FG_Tage>0</FG_Tage>
<Testbarkeit>2</Testbarkeit>
<Deutsch_x0020_Muttersprache>-1</Deutsch_x0020_Muttersprache>
<_x0034_8>0</_x0034_8>
<_x0035_3>0</_x0035_3>
<_x0036_5>0</_x0036_5>
<_x0036_9>0</_x0036_9>
<_x0037_1>0</_x0037_1>
<KorrAlterBerücks>0</KorrAlterBerücks>
<FGAlterkorrberücks>0</FGAlterkorrberücks>
<Blind>0</Blind>
<Schwerhörig>0</Schwerhörig>
<motRet>0</motRet>
<MentaleRet>0</MentaleRet>
<keinementRet>0</keinementRet>
</BayleyTestdaten>
 :)
declare function qrimport:mkBayleyIIIQR(
      $b3 as item()
    , $quest as element(fhir:Questionnaire)
    ) as item()*
{
    let $pid := concat('p-',$b3/PatNr/string())
    let $pat := r-patient:patientByIDXML($pid,'kikl-spz','u-admin','Adm@in')
    return
        if ($pat/fhir:id)
        then
    let $pref := concat('nabu/patients/',$pat/fhir:id/@value)
    let $pnam := r-patient:formatFHIRName($pat)
    let $orbis-pid := if ($pat/fhir:identifier)
        then $pat/fhir:identifier/fhir:value/@value/string()
        else ''
    let $ssDetails  := qrtf:mkQRItem(
            $quest//fhir:item[fhir:linkId/@value='ssDetails']
        ,   <group>
                <group>
                    <simple>{$b3/FG_x0020_Woche/string()}</simple>
                    <simple>{$b3/FG_Tage/string()}</simple>
                </group>
            </group>
        )
    let $context  := qrtf:mkQRItem(
            $quest//fhir:item[fhir:linkId/@value='context']
        ,   <group>
                    <simple>{qrimport:mapLanguage($b3/Deutsch_x0020_Muttersprache/string())}</simple>
                    <simple>{$b3/Länge/string()}</simple>
                    <simple>{$b3/Gewicht/string()}</simple>
                    <simple>{$b3/KU/string()}</simple>
            </group>
        )
    let $bayley := qrtf:mkQRItem(
            $quest//fhir:item[fhir:linkId/@value='bayleyIII-test']
        ,   <group>
                    <simple>{$b3/ID/string()}</simple>
                    <simple>{$b3/TestDat/string()}</simple>
                    <simple>{$b3/Untersucher/string()}</simple>
                    <simple>{$b3/Testbarkeit/string()}</simple>
                    <simple></simple>
                    <simple>{xs:integer($b3/FGAlterkorrberücks/string()) > 0}</simple>
                    <group>
                        <simple>{$b3/Cog/string()}</simple>
                        <simple>{$b3/RWCog/string()}</simple>
                        <simple>{$b3/CogAlter/string()}</simple>
                        <simple>{$b3/CogZuverl/string()}</simple>
                    </group>
                    <group>
                        <simple>{$b3/RecLang/string()}</simple>
                        <simple>{$b3/RWRecL/string()}</simple>
                        <simple>{$b3/RecLangAlter/string()}</simple>
                        <simple>{$b3/RecLangZuverl/string()}</simple>
                    </group>
                    <group>
                        <simple>{$b3/ExprLang/string()}</simple>
                        <simple>{$b3/RWExprL/string()}</simple>
                        <simple>{$b3/ExprLangAlter/string()}</simple>
                        <simple>{$b3/ExprLangZuverl/string()}</simple>
                    </group>
                    <group>
                        <simple>{$b3/FineMotor/string()}</simple>
                        <simple>{$b3/RWFineM/string()}</simple>
                        <simple>{$b3/FineMotorAlter/string()}</simple>
                        <simple>{$b3/FineMotorZuverl/string()}</simple>
                    </group>
                    <group>
                        <simple>{$b3/GrossMotor/string()}</simple>
                        <simple>{$b3/RWGrossM/string()}</simple>
                        <simple>{$b3/GrossMotorAlter/string()}</simple>
                        <simple>{$b3/GrossMotorZuverl/string()}</simple>
                    </group>                    
            </group>
        )
    let $outcome  := qrtf:mkQRItem(
            $quest//fhir:item[fhir:linkId/@value='outcomeInformation']
        ,   <group>
                    <simple>{$b3/Blind/string()='1'}</simple>
                    <simple>{$b3/Schwerhörig/string()='1'}</simple>
                    <simple>{$b3/motRet/string()='1'}</simple>
                    <simple>{$b3/MentaleRet/string()='1'}</simple>
                    <simple>{$b3/keinementRet/string()='1'}</simple>
            </group>
        )
    let $authored := adjust-dateTime-to-timezone(current-dateTime(),())
    return
        <QuestionnaireResponse xmlns="http://hl7.org/fhir">
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <identifier>
                <use value="usual"/>
                <type value="ORBIS-PNR"/>
                <system value="http://uk-koeln.de/#patient-orbis-pnr"/>
                <value value="{$orbis-pid}"/>
                <assigner>
                    <reference value="metis/organizations/ukk"/>
                    <display value="Unikliniken Köln"/>
                </assigner>
            </identifier>
            <basedOn>
                <reference value=""/>
                <display value=""/>                
            </basedOn>
            <questionnaire>
                <reference value="nabu/questionnaireresponses/qr-bayleyIII-v2017-08-08"/>
                <display value="Bayley III v2017-08-08"/>                
            </questionnaire>
            <status value="in-progress"/>
            <subject>
                <reference value="{$pref}"/>
                <display value="{$pnam}"/>
            </subject>
            <context>
                <reference value=""/>
                <display value=""/>                
            </context>
            <authored value="{$authored}"/>
            <author>
                <reference value="nabu/practitioners/u-admin"/>
                <display value="Admin"/>                
            </author>
            <source>
                <reference value=""/>
                <display value="Bayley III"/>
            </source>
            <item>
                <linkId value="bayleyIII"/>
                <text value="Bayley III Daten"/>
                <type value="group"/>
                {$ssDetails}
                {$context}
                {$bayley}
                {$outcome}
            </item>
        </QuestionnaireResponse>
        else ()
};
