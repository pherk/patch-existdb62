xquery version "3.0";

module namespace cpt = "http://enahar.org/exist/apps/nabu/careplan-template";

import module namespace mem="http://enahar.org/lib/mem";

declare namespace fhir = "http://hl7.org/fhir";
declare namespace  tei = "http://www.tei-c.org/ns/1.0";

declare variable $cpt:cpinfos := doc('/db/apps/nabu/FHIR/CarePlan/careplan-infos.xml');

declare function cpt:fillCarePlan(
      $content as element(fhir:CarePlan)
    , $cpprops as item()*
    , $actprops as item()*
    ) as element(fhir:CarePlan)
{
    let $ops0 := fold-left(
                $cpprops
            ,   mem:copy($content)
            ,   function($map, $prop) {
                    mem:replace($map, $content/fhir:*[local-name(.)=local-name($prop)], $prop)
                }
            )
    let $ops1 := fold-left(
                $actprops
            ,   $ops0
            ,   function($map, $actprop) {
                    let $activity := cpt:fillActivity($actprop/fhir:*)
                    return
                        mem:insert-child($map, $content, $activity)
                }
            )
    return
        mem:execute($ops1)
};

declare function cpt:fillActivity(
        $props as item()*
    ) as element(fhir:activity)
{
    let $activity := 
        <activity xmlns="http://hl7.org/fhir" id="{util:uuid()}">
            { $cpt:cpinfos//fhir:bricks/fhir:activity/fhir:* }
        </activity>
    let $ops0 := fold-left(
                $props
            ,   mem:copy($activity)
            ,   function($map, $prop) {
                    if (count($activity/fhir:*[local-name(.)=local-name($prop)])=0)
                    then
                        mem:insert-child($map, $activity, $prop)
                    else if (count($activity/fhir:*[local-name(.)=local-name($prop)])=1)
                    then
                        mem:replace($map, $activity/fhir:*[local-name(.)=local-name($prop)], $prop)
                    else () (: replace would't all props with new one :)
                }
            )
    return
        mem:execute($ops0)
};