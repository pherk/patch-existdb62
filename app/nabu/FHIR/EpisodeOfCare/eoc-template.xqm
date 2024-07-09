xquery version "3.0";
module namespace eoct = "http://enahar.org/exist/apps/nabu/eoc-template";

import module namespace mem = "http://enahar.org/lib/mem";

declare namespace fhir = "http://hl7.org/fhir";
declare namespace  tei = "http://www.tei-c.org/ns/1.0";

declare variable $eoct:eocinfos := doc('/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare-infos.xml');

declare function eoct:fillEpisodeOfCare(
      $eocprops as item()*
    , $childprops as item()*
    ) as element(fhir:EpisodeOfCare)
{
    let $content := $eoct:eocinfos//fhir:bricks/fhir:EpisodeOfCare
    let $ops0 := fold-left(
                $eocprops
            ,   mem:copy($content)
            ,   function($map, $prop) {
                    mem:replace($map, $content/fhir:*[local-name(.)=local-name($prop)], $prop)
                }
            )
    let $ops1 := fold-left(
                $childprops
            ,   $ops0
            ,   function($map, $childprop) {
                    let $child := eoct:fillChild($childprop)
                    return
                        mem:insert-child($map, $content, $child)
                }
            )
    return
        mem:execute($ops1)
};

declare function eoct:fillChild(
        $prop
        ) as item()?
{
    switch(local-name($prop))
    case 'team' return $prop       
    case 'statusHistory' return $prop
    default return ()
};