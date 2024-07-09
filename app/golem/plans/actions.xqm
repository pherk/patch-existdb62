xquery version "3.0";
module namespace rea = "http://enahar.org/exist/apps/golem/actions";

declare namespace golem = "http://enahar.org/ns/1.0/golem";
declare namespace  fhir = "http://hl7.org/fhir";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";

declare variable $rea:adcoll := collection('/db/apps/nabuWorkflow/data/ActivityDefinitions');

declare function rea:actions(
      $a as element(fhir:action)*
    ) as element(golem:actions)?
{
    if ($a)
    then
        <actions xmlns="http://enahar.org/ns/1.0/golem">
        {
            if ($a/fhir:action)
            then rea:group($a)
            else rea:single($a)
        }
        </actions>
    else ()
};

declare %private function rea:definition(
      $ad as element(fhir:ActivityDefinition)
    , $params as element(golem:param)*
    ) as element(golem:request)*
{
    let $lll := util:log-app('TRACE','apps.nabu',$ad/fhir:title/@value/string())
    let $lll := util:log-app('TRACE','apps.nabu',$params)
    let $dynVals := rea:dynamicValues($ad)
    return
        for $p in $ad/fhir:participant
        return
            rea:participant($p, $ad, ($dynVals/golem:param,$params))
};

declare %private function rea:participant(
          $p as element(fhir:participant)
        , $ad as element(fhir:ActivityDefinition)
        , $params as element(golem:param)*
        ) as element(golem:request)
{
    <request xmlns="http://enahar.org/ns/1.0/golem" kind="{$ad/fhir:kind/@value/string()}">
    {
        rea:evalDynVal("spec.actionid", "1", $params)
    ,   rea:evalDynVal("spec.relatedAction.actionid", "1", $params)
    ,   rea:evalDynVal("spec.relatedAction.relationship", 
                    $ad/fhir:code/fhir:coding[fhir:system/@value="http://hl7.org/fhir/ValueSet/action-relationship-type"]/fhir:code/@value, $params)
    ,   rea:evalDynVal("spec.relatedAction.offsetDuration.value", "0", $params)
    ,   rea:evalDynVal("spec.relatedAction.offsetDuration.unit", "h", $params)
    ,   rea:evalDynVal("spec.interdisciplinary", 
                xs:string($ad/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/ValueSet/action-relationship-type']/fhir:code/@value='concurrent'), $params)
    ,   rea:evalDynVal("timingTiming.event", 
                $ad/fhir:timingTiming//fhir:event//fhir:valueString/@value, $params)
    ,   rea:evalDynVal("timingTiming.duration", 
                $ad/fhir:timingTiming//fhir:duration/@value, $params)
    ,   rea:evalDynVal("participant.role", 
                $p/fhir:role/@value, $params)
    ,   rea:evalDynVal("participant.actor.reference",
                $p/fhir:actor/fhir:reference/@value, $params)
    ,   rea:evalDynVal("participant.actor.display", 
                $p/fhir:actor/fhir:display/@value, $params)
    ,   rea:evalDynVal("participant.required", 
                $p/fhir:required/@value, $params)
    ,   rea:evalDynVal("schedule.reference",
                $ad/fhir:schedule/fhir:reference/@value, $params)
    ,   rea:evalDynVal("schedule.display",
                $ad/fhir:schedule/fhir:display/@value, $params)
    }
    </request>
};

declare %private function rea:evalDynVal(
          $path as xs:string
        , $expr as xs:string?
        , $params as element(golem:param)*
        ) as element(golem:param)?
{
    
    let $lll := util:log-app("TRACE","apps.nabu",$path)
    let $lll := util:log-app("TRACE","apps.nabu",$expr)
    let $lll := util:log-app("TRACE","apps.nabu",$params)
    
    let $retval := if ($params[@path=$path])
        then if ($params[@path=$path]/@expr)
            then
                let $lll := util:log-app("TRACE","apps.nabu",$params[@path=$path])
                return
                    <param xmlns="http://enahar.org/ns/1.0/golem"
                        path="{$path}"
                        value="{xs:string(util:eval($params[@path=$path][last()]/@expr/string()))}"/>
            else <param xmlns="http://enahar.org/ns/1.0/golem" path="{$path}" value="{$params[@path=$path]/@value/string()}"/>
        else if ($expr)
        then <param xmlns="http://enahar.org/ns/1.0/golem" path="{$path}" value="{$expr}"/>
        else ()
    return
        $retval
};

declare %private function rea:dynamicValue(
          $dv as element(fhir:dynamicValue)
        ) as element(golem:param)
{
    <param xmlns="http://enahar.org/ns/1.0/golem" path="{$dv/fhir:path/@value/string()}" expr="{$dv/fhir:expression/@value/string()}"/>    
};

declare %private function rea:dynamicValues(
          $a as item()*  (: fhir:action or fhir:ActionDefinition :)
        ) as element(golem:dynamicValues)
{
    <dynamicValues xmlns="http://enahar.org/ns/1.0/golem">
    {
        for $dv in $a/fhir:dynamicValue[fhir:language[@value='application/xquery']]
        return
            rea:dynamicValue($dv)
    }
    </dynamicValues>
};

declare %private function rea:single(
          $a as element(fhir:action)*
        ) as element(golem:single)?
{
    if (count($a)=1)
    then rea:singleAction($a)
    else if (count($a) > 1)
    then rea:singleCombiAction($a)
    else ()
};

declare %private function rea:singleCombiAction(
          $as as element(fhir:action)+
        ) as element(golem:single)
{
    let $lll := util:log-app('TRACE','apps.nabu',$as)
    let $title := string-join($as/fhir:textEquivalent/@value,'-')
    let $dynVals := rea:dynamicValues($as)
    return
    <single xmlns="http://enahar.org/ns/1.0/golem" text="{$title}" kind="RequestGroup">
        { $as/fhir:condition[fhir:language[@value='application/xquery']] }
        { 
            for $a at $n in $as
            let $aid := <param xmlns="http://enahar.org/ns/1.0/golem" path="spec.actionid" value="{$n}"/>
            return
                rea:evalSingleAction($a, $aid, $dynVals)
        }
    </single>
};

declare %private function rea:singleAction(
          $a as element(fhir:action)
        ) as element(golem:single)
{
    let $lll := util:log-app('TRACE','apps.nabu',$a)
    let $title := $a/fhir:textEquivalent/@value/string()
    let $dynVals := rea:dynamicValues($a)
    let $aid := <param xmlns="http://enahar.org/ns/1.0/golem" path="spec.actionid" value="1"/>
    return
    <single xmlns="http://enahar.org/ns/1.0/golem" text="{$title}" kind="RequestGroup">
    {
          $a/fhir:condition[fhir:language[@value='application/xquery']] 
        , rea:evalSingleAction($a, $aid, $dynVals)
    }
    </single>
};

declare %private function rea:evalSingleAction(
          $a as element(fhir:action)
        , $aid as element(golem:param)
        , $dynVals as element(golem:dynamicValues)
        ) as element(golem:request)+
{
    let $adid := tokenize($a/fhir:definition/fhir:reference/@value,'/')[3]
    let $ad := $rea:adcoll/fhir:ActivityDefinition[fhir:id[@value=$adid]]
    return
        if ($ad)
        then
            let $relparam := rea:relatedAction($a)
            return
                rea:definition($ad, ($aid, $relparam, $dynVals/golem:param))
        else 
            <request xmlns="http://enahar.org/ns/1.0/golem">
                <error value="{concat('definition for ',$adid, ' not found')}"/>
            </request>
};

declare %private function rea:relatedAction(
          $a as element(fhir:action)
        ) as element(golem:param)*
{
    if ($a/fhir:relatedAction)
    then 
        let $ra := $a/fhir:relatedAction
        return
        (
          <param xmlns="http://enahar.org/ns/1.0/golem" path="spec.relatedAction.actionid" value="{$ra/fhir:actionId/@value/string()}"/>
        , <param xmlns="http://enahar.org/ns/1.0/golem" path="spec.relatedAction.relationship" value="{$ra/fhir:relationship/@value/string()}"/>
        , <param xmlns="http://enahar.org/ns/1.0/golem" path="spec.relatedAction.offsetDuration.value" value="{$ra/fhir:offsetDuration/fhir:value/@value/string()}"/>
        , <param xmlns="http://enahar.org/ns/1.0/golem" path="spec.relatedAction.offsetDuration.unit" value="{$ra/fhir:offsetDuration/fhir:unit/@value/string()}"/>
        )
    else ()
};

declare %private function rea:group(
          $a as element(fhir:action)
        ) as element(golem:group-all)
{
    let $gb := ($a/fhir:groupingBehavior/@value,'logical-group')[1]
    let $sb := ($a/fhir:selectionBehavior/@value,'all')[1] 
    return
        if ($gb = 'logical-group')
        then
            if ($sb = 'all')
            then
                let $single := rea:single($a/fhir:action[fhir:relatedAction])
                let $other := 
                        for $child in $a/fhir:action[not(fhir:relatedAction)]
                        return
                            rea:actions($child)
                let $actions := ($single,$other)
                return
                <group-all xmlns="http://enahar.org/ns/1.0/golem" title="{$a/fhir:title/@value/string()}">
                {
                    $actions
                }
                </group-all>
            else error(QName('http://enahar.org/ns/1.0/golem', 'nyi'), 'selectionBehavior')
        else error(QName('http://enahar.org/ns/1.0/golem', 'nyi'), 'groupingBehavior')
};
