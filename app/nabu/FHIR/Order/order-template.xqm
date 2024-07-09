xquery version "3.0";

module namespace ot = "http://enahar.org/exist/apps/nabu/order-template";

import module namespace mem="http://enahar.org/lib/mem";

declare namespace fhir = "http://hl7.org/fhir";
declare namespace  tei = "http://www.tei-c.org/ns/1.0";

declare variable $ot:oinfos := doc('/db/apps/nabu/FHIR/Order/order-infos.xml');

declare function ot:fillOrder(
      $oprops as item()*
    , $dprops as item()*
    ) as element(fhir:Order)
{
    let $content := $ot:oinfos//fhir:bricks/fhir:Order
    let $ops0 := fold-left(
                $oprops
            ,   mem:copy($content)
            ,   function($map, $prop) {
                    mem:replace($map, $content/fhir:*[local-name(.)=local-name($prop)], $prop)
                }
            )
    let $ops1 := fold-left(
                $dprops
            ,   $ops0
            ,   function($map, $dprop) {
                    let $detail := ot:fillDetail($dprop/fhir:*)
                    return
                        mem:insert-child($map, $content, $detail)
                }
            )
    return
        mem:execute($ops1)
};

declare function ot:fillDetail(
        $props as item()*
    ) as element(fhir:detail)
{
    (:~
     : cave replaces only props which exist in original )
     :)
    let $detail := <detail xmlns="http://hl7.org/fhir" id="{util:uuid()}">
            { $ot:oinfos//fhir:bricks/fhir:detail/fhir:* }
            </detail>
    let $ops0 := fold-left(
                $props
            ,   mem:copy($detail)
            ,   function($map, $prop) {
                    mem:replace($map, $detail/fhir:*[local-name(.)=local-name($prop)], $prop)
                }
            )
    return
        mem:execute($ops0)
};