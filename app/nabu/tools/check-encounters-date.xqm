xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuEncounter/data/planned')/fhir:Encounter
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
        try {
        let $diff := xs:dateTime($o/fhir:period/fhir:end/@value/string()) - xs:dateTime($o/fhir:period/fhir:start/@value/string())
        return 
            if ($diff > xs:dayTimeDuration("PT0M") and $diff <  xs:dayTimeDuration("PT24H"))
            then ()
            else $o
    } catch * {
        let $lll :=util:log-app('DEBUG','nabu',$o/@xml:id/string())
        return $o
    }