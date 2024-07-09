xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $sortByActor := false()
let $now := current-dateTime()
let $eps := collection(concat('/db/apps/nabuEncounter/data/','planned'))/fhir:Encounter[fhir:period/fhir:start/@value<$now]
let $ems21 := collection(concat('/db/apps/nabuEncounter/data/','2021'))/fhir:Encounter[fhir:status[@value!='finished'][@value!='cancelled']]
let $ems20 := collection(concat('/db/apps/nabuEncounter/data/','2020'))/fhir:Encounter[fhir:status[@value!='finished'][@value!='cancelled']]
let $es := ($eps,$ems21, $ems20)
return
    if ($sortByActor)
    then
        <in-planned all="{count($es)}">
        {
            for $a in distinct-values($es/fhir:participant/fhir:actor/fhir:reference/@value)
            let $eas := $es[fhir:participant/fhir:actor[fhir:reference[@value=$a]]]
            order by count($eas) descending
            return
                <person name="{$eas[1]/fhir:participant/fhir:actor/fhir:display/@value/string()}" count="{count($eas)}">
                {
                    for $ea in $eas
                    order by $ea/fhir:period/fhir:start/@value/string() descending
                    return
                        <date start="{$ea/fhir:period/fhir:start/@value/string()}" subject="{$ea/fhir:subject/fhir:display/@value/string()}" status="{$ea/fhir:status/@value/string()}"/>
                }
                </person>
        }
        </in-planned>
    else
        <in-planned all="{count($es)}">
        {
            let $alldays := for $e in $es
                return tokenize($e/fhir:period/fhir:start/@value,'T')[1]
            let $days    := distinct-values($alldays)
            for $day in $days
            let $eds := $es[starts-with(fhir:period/fhir:start/@value,$day)]
            order by count($eds) descending, $day descending
            return
                if (count($eds)>1)
                then
                <day datum="{$day}" count="{count($eds)}">
                {
                    let $as := distinct-values($eds/fhir:participant/fhir:actor/fhir:display/@value)
                    for $an in $as
                    order by $an
                    return
                        for $e in $eds[fhir:participant/fhir:actor/fhir:display/@value=$an]
                        return
                            <date actor="{$e/fhir:participant/fhir:actor/fhir:display/@value/string()}" subject="{$e/fhir:subject/fhir:display/@value/string()}" status="{$e/fhir:status/@value/string()}"/>
                }
                </day>
                else ()
        }
        </in-planned>