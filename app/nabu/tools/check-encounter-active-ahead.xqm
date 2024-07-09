xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $date := "2019-01-31"
let $es := collection(concat('/db/apps/nabuEncounter/data/','2019'))/fhir:Encounter[fhir:status[@value=('planned','tentative','arrived','in-progress')]][fhir:period/fhir:start/@value > $date]
return
<in-planned all="{count($es)}">
{
    $es
}
</in-planned>
    