xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";

let $ci := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare[fhir:status[@value=("onhold","waitlist")]]
return
<eoc-status>
{
    for $e in $ci
    return
        <patient>{$e/fhir:patient/fhir:display/@value/string()}</patient>
}</eoc-status>