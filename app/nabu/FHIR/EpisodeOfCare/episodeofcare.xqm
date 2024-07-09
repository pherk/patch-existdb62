xquery version "3.0";
module namespace eoc = "http://enahar.org/exist/apps/nabu/eoc";

import module namespace mem = "http://enahar.org/lib/mem";



declare namespace fhir= "http://hl7.org/fhir";


declare function eoc:careManager(
          $ps (: as element(fhir:participant)* :)
        ) as element(fhir:careManager)?
{
    if ($ps)
    then
        let $psf := $ps/../fhir:participant[fhir:role/fhir:coding/fhir:code/@value=('spz-arzt','spz-gbafg','spz-psych','spz-moto','spz-nme')]
        (: priotize arzt :)
        let $cm := if (count($psf)>1)
            then let $cms := for $p in $psf[fhir:role/fhir:coding/fhir:code/@value=('spz-arzt','spz-gbafg')]
                    order by $p/fhir:period/fhir:end/@value/string() descending
                    return $p
                 return $cms[1]
            else $psf
        return
            if ($cm)
            then
                <careManager xmlns="http://hl7.org/fhir">
                { $cm/fhir:member/fhir:reference }
                { $cm/fhir:member/fhir:display }
                {$ps}
                </careManager>
            else ()
    else ()
};
