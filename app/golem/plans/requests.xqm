xquery version "3.1";

module namespace rer = "http://enahar.org/exist/apps/golem/requests";

import module namespace rec = "http://enahar.org/exist/apps/golem/context"            at "/db/apps/golem/context/context.xqm";
import module namespace ot    = "http://enahar.org/exist/apps/nabu/order-template"    at "/db/apps/nabu/FHIR/Order/order-template.xqm";

declare namespace golem = "http://enahar.org/ns/1.0/golem";
declare namespace  fhir = "http://hl7.org/fhir";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";

declare function rer:requests(
      $as as element(golem:actions)?
    , $context as element(golem:context)
    , $priority as xs:string
    , $description as xs:string
    ) as element(fhir:Order)*
{
    let $lll := util:log-app('TRACE','apps.nabu',$as)
    let $lll := util:log-app('TRACE','apps.nabu',$context)

    let $requests := if ($as)
        then
            if ($as/golem:group-all)
            then
                (
                    for $s in $as/golem:group-all/golem:single
                    return
                        rer:singleRequestGroup($s,$context,$priority,$description)
                ,   for $a in $as/golem:group-all/golem:actions
                    return
                        rer:requests($a, $context, $priority, $description)
                )
            else if ($as/golem:single)
            then
                for $s in $as/golem:single
                return
                    rer:singleRequestGroup($s,$context,$priority,$description)
            else ()
        else ()
    return
        $requests
};

declare function rer:singleRequestGroup(
      $single as element(golem:single)
    , $context as element(golem:context)
    , $priority as xs:string
    , $description as xs:string
    ) as element(fhir:Order)?
{
    let $lll := util:log-app('TRACE','apps.nabu',$single)
    let $lll := util:log-app('TRACE','apps.nabu',$context)
    let $lll := util:log-app('TRACE','apps.nabu',$priority)
    let $lll := util:log-app('TRACE','apps.nabu',$description)
    (:~
     :  1. with dynVals from AD and PD
     :  2. with params in careplans.xml ???? 
     :)
    return
        if (rec:checkCondition($single/fhir:condition[fhir:language[@value='application/xquery']], $context))
        then
            let $info := if ($description="")
                then $single/@text/string()
                else $description
            (: context title is not property of Order :)
            let $params :=
               ( 
                    $context/fhir:params/fhir:*[not(self::fhir:title or self::fhir:description)]
                ,   <description xmlns="http://hl7.org/fhir" value="{$info}"/>
                ,   rer:prepareWhen($priority)
                ,   <comment xmlns="http://hl7.org/fhir" value="{$context/fhir:params/fhir:description/@value/string()}"/>
                ,   <date    xmlns="http://hl7.org/fhir" value="{adjust-dateTime-to-timezone(current-dateTime())}"/>
                ,   <status  xmlns="http://hl7.org/fhir" value="active"/>
                ,   <target  xmlns="http://hl7.org/fhir">
                        <role value="spz-ateam"/>
                        <reference value=""/>
                        <display value="SPZ ATeam"/>
                    </target>
                )
            let $details := for $d in $single/golem:request
                return
                    rer:prepareOrderDetail($d)
            let $lll := util:log-app('TRACE','apps.nabu',$params)
            let $lll := util:log-app('TRACE','apps.nabu',$details)
            return
                ot:fillOrder($params,$details)
        else ()
};

declare function rer:prepareWhen($priority as xs:string)
{
    let $code := rer:mapGoalPrioCode($priority)
    let $disp := rer:mapGoalPrioDisp($priority)
    return
        <when xmlns="http://hl7.org/fhir">
            <code>
                <coding>
                    <system value="#order-priority"/>
                    <code value="{$code}"/>
                    <display value="{$disp}"/>
                </coding>
                <text value="{$disp}"/>
            </code>
            <schedule>
                <event value=""/>
            </schedule>
        </when>
};

declare function rer:mapGoalPrioCode($priority as xs:string)
{
    switch($priority)
    case "medium-priority" return "normal"
    case "asap-priority" return "urgent"
    case "high-priority" return "high"
    case "other-priority" return "low"
    default return "normal"
};

declare function rer:mapGoalPrioDisp($priority as xs:string)
{
    switch($priority)
    case "medium-priority" return "normal"
    case "asap-priority" return "sehr dringend"
    case "high-priority" return "dringend"
    case "other-priority" return "niedrig"
    default return "normal"
};

(:~
 : specific for Order details
 : 
 : move to FHIR 3.01 RequestGroup action property
 : added
 : - releatedAction overrides combination/interdisciplinary 
 : TODO
 : - info -> title, description
 : - begin, dow, daytime, duration -> timing
 : - actor -> participant, allow for more than one participant (interdisciplinary!)
 : - schedule?
 :)
declare function rer:prepareOrderDetail(
        $d as item()
    ) as item()
{
    let $detail-info := ''
    return
    <detail xmlns="http://hl7.org/fhir">
        <info value="{$detail-info}"/>
        <actor>
            <role value="{$d/golem:param[@path="participant.role"]/@value/string()}"/>
            <reference value="{$d/golem:param[@path="participant.actor.reference"]/@value/string()}"/>
            <display value="{$d/golem:param[@path="participant.actor.display"]/@value/string()}"/>
            <required value="{$d/golem:param[@path="participant.required"]/@value/string()}"/>
        </actor>
        <schedule>
            <reference value="{$d/golem:param[@path="schedule.reference"]/@value/string()}"/>
            <display value="{$d/golem:param[@path="schedule.display"]/@value/string()}"/>
        </schedule>
        <spec>
            <combination value="{$d/golem:param[@path="spec.actionid"]/@value/string()}"/>
            <interdisciplinary value="{$d/golem:param[@path="spec.interdisciplinary"]/@value/string()}"/>
            <begin value="{rer:event($d/golem:param[@path="timingTiming.event"]/@value)}"/>
            <daytime value="any"/>
            <dow value="any"/>
            <duration value="{$d/golem:param[@path="timingTiming.duration"]/@value/string()}"/>
            <relatedAction>
                <actionid value="{$d/golem:param[@path="spec.relatedAction.actionid"]/@value/string()}"/>
                <relationship value="{$d/golem:param[@path="spec.relatedAction.relationship"]/@value/string()}"/>
                <offsetDuration> 
                    <value value="{$d/golem:param[@path="spec.relatedAction.offsetDuration.value"]/@value/string()}"/> 
                    <unit value="{$d/golem:param[@path="spec.relatedAction.offsetDuration.unit"]/@value/string()}"/> 
                </offsetDuration> 
            </relatedAction>
        </spec>
    </detail> 
};

(:~ 
 : split off timezone from date
 :)
declare function rer:event(
      $e as xs:string
    )  as xs:string
{
    tokenize($e, '\+')[1]
};
