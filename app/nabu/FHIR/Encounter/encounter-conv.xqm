xquery version "3.0";

module namespace encconv = "http://enahar.org/exist/apps/nabu/encounter-conv";

declare namespace fhir= "http://hl7.org/fhir";

declare variable $encconv:enahar-schedule-ref := "enahar/schedules/";

declare function encconv:o2e(
          $order as item()
        , $detail as item()
        , $status as xs:string
        , $combi as xs:string
    ) as item()
{
    let $def := if($order/fhir:definition)
        then $order/fhir:definition
        else ()
    let $basedOn := $order/fhir:basedOn
    let $fulfills  := concat("nabu/orders/", $order//fhir:id/@value,"?detail=",$detail/@id)
    let $pref  := $order//fhir:subject/fhir:reference/@value/string()
    let $pnam  := $order//fhir:subject/fhir:display/@value/string()
    let $reason := if ($order//fhir:reason/fhir:text/@value='')
        then $order//fhir:reason/fhir:coding/fhir:display/@value/string()
        else $order//fhir:reason/fhir:text/@value/string()
    let $descr  := $order//fhir:description/@value/string()
    let $termin-info  := string-join($detail/fhir:info/@value, ' - ')
    let $start := $detail/fhir:proposal/fhir:start/@value/string()
    let $end   := $detail/fhir:proposal/fhir:end/@value/string()
    let $scode := substring-after($detail/fhir:schedule/fhir:reference/@value/string(), $encconv:enahar-schedule-ref)
    let $sdisp := if ($detail/fhir:schedule/fhir:display/@value/string()='')
        then 'SPZ Ambulanz'
        else $detail/fhir:schedule/fhir:display/@value/string()
    let $stext := $sdisp
    let $aref  := $detail//fhir:actor/fhir:reference/@value/string()
    let $anam  := $detail//fhir:actor/fhir:display/@value/string()
    let $arole := $detail//fhir:actor/fhir:role/@value/string()
    let $ardisp := $arole
    let $artext := $arole
    let $dur   := (xs:dateTime($end) - xs:dateTime($start)) div xs:dayTimeDuration('PT1M')
    let $apptype := $order/fhir:appointmentType/fhir:coding[fhir:system/@value='http://hl7.org/fhir/v2/0276']
    let $now   := adjust-dateTime-to-timezone(current-dateTime(),())
    return
<Encounter xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionId value="0"/>
    </meta>
    { $def }
    { $basedOn }
    <priority value="0"/>
    <status value="{$status}"/>
    <class value="AMB"/>
    <type>
        <coding>
            <system value="#encounter-type"/>
            <code value="{$scode}"/>
            <display value="{$sdisp}"/>
        </coding>
        { $apptype }
        <text value="{$stext}"/>
    </type>
    <subject>
        <reference value="{$pref}"/>
        <display value="{$pnam}"/>
    </subject>
    <participant>
        <type>
            <coding>
                <system value="#encounter-role"/>
                <code value="{$arole}"/>
                <display value="{$ardisp}"/>
            </coding>
            <text value="{$artext}"/>
        </type>
        <period>
            <start value="{$start}"/>
            <end value="{$end}"/>
        </period>
        <individual>
            <reference value="{$aref}"/>
            <display value="{$anam}"/>
        </individual>
    </participant>  
    <appointment>
        <reference value="{$fulfills}"/>
    </appointment>
    <period>
        <start value="{$start}"/>
        <end value="{$end}"/>
    </period>
    <reasonCode>
        <coding>
            <system value="#encounter-reason"/>
            <code value="amb"/>
            <display value="{$reason}"/>
        </coding>
        <text value="{concat($descr,' - ',$termin-info)}"/>
    </reasonCode>
    <serviceProvider>
        <reference value="metis/organizations/kikl-spz"/>
        <display value="SPZ Kinderklinik"/>
    </serviceProvider>
    <location>
        <location>
            <reference value="metis/locations/kikl-spz"/>
            <display value="SPZ KiKl"/>
        </location>
        <status value="planned"/>
        <period>
            <start value="{$start}"/>
            <end value="{$end}"/>
        </period>
    </location>
    {
        if ($combi='')
        then ()
        else
            <partOf>
                <reference value=""/>
                <display value="{$combi}"/>
            </partOf>
    }
</Encounter>
};
