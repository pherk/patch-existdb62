xquery version "3.1";

declare namespace fhir="http://hl7.org/fhir";

let $locs := collection("/db/apps/metisData/data/FHIR/Locations")
let $bu := "26"
let $floors := ("UG", "1OG", "2OG", "3OG")
return
<haus no="{$bu}">
{
    for $fl in $floors
    let $flref := concat('metis/locations/bu-',$bu,'-',$fl)
    return
    <ebene ref="{$fl}">
    {
    for $r in $locs/fhir:Location[fhir:physicalType/fhir:coding[fhir:system/@value="http://hl7.org/fhir/location-physical-type"]/fhir:code[@value='ro']][starts-with(fhir:partOf/fhir:reference/@value,$flref)][fhir:status[@value='active']]
    order by $r/fhir:name/@value/string()
    return
        <raum no="{$r/fhir:name/@value/string()}" type="{$r/fhir:extension[@url='#room-type']/fhir:valueCode/@value/string()}" group="{$r/fhir:extension[@url='#managedByGroup']/fhir:valueCode/@value/string()}" np="{$r/fhir:extension[@url='#room-pc-no']/fhir:valueInteger/@value/string()}" m2="{$r/fhir:extension[@url='#room-area']/fhir:valueDecimal/@value/string()}">{$r/fhir:description/@value/string()}</raum>
    }
    </ebene>
}
</haus>