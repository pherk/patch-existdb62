xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";


let $es := collection(concat('/db/apps/nabuEncounter/data/','planned'))/fhir:Encounter[fhir:status[@value!='planned']][fhir:status[@value!='tentative']]
return
<in-planned all="{count($es)}">
{
    for $a in distinct-values($es/fhir:participant/fhir:actor/fhir:reference/@value)
    let $eas := $es[fhir:participant/fhir:actor[fhir:reference[@value=$a]]]
    order by count($eas) descending
    return
    <person status="{$eas[1]/fhir:participant/fhir:actor/fhir:display/@value/string()}" count="{count($eas)}">
    {
        for $ea in $eas
        order by $ea/fhir:period/fhir:start/@value/string() descending
        return
            <date start="{$ea/fhir:period/fhir:start/@value/string()}" status="{$ea/fhir:status/@value/string()}"/>
    }
    </person>
}
</in-planned>
    