xquery version "3.0";
module namespace ctt = "http://enahar.org/exist/apps/nabu/ct-template";


import module namespace mem = "http://enahar.org/lib/mem";

declare namespace fhir = "http://hl7.org/fhir";
declare namespace  tei = "http://www.tei-c.org/ns/1.0";

declare variable $ctt:ctinfos := doc('/db/apps/nabu/FHIR/CareTeam/careteam-infos.xml');

declare function ctt:fillCareTeam(
      $ctprops as item()*
    , $childprops as item()*
    ) as element(fhir:CareTeam)
{
    let $content := $ctt:ctinfos//fhir:bricks/fhir:CareTeam
    let $ops0 := fold-left(
                $ctprops
            ,   mem:copy($content)
            ,   function($map, $prop) {
                    mem:replace($map, $content/fhir:*[local-name(.)=local-name($prop)], $prop)
                }
            )
    let $ops1 := fold-left(
                $childprops
            ,   $ops0
            ,   function($map, $childprop) {
                    let $child := ctt:fillChild($childprop)
                    return
                        mem:insert-child($map, $content, $child)
                }
            )
    return
        mem:execute($ops1)
};

declare function ctt:fillChild(
        $prop
        ) as item()?
{
    switch(local-name($prop))
    case 'participant' return $prop
    case 'note' return $prop
    default return ()
};