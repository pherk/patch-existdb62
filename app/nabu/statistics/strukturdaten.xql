xquery version "3.1";

declare namespace fhir="http://hl7.org/fhir";
let $year := "2018"
let $ps := collection("/db/apps/nabuData/data/FHIR/Patients")
let $encs := collection("/db/apps/nabuEncounter/data/" || $year)
let $ef := $encs/fhir:Encounter[fhir:status[@value='finished']]
let $sids := distinct-values(for $e in $ef/fhir:subject/fhir:reference/@value return substring-after($e,'nabu/patients/'))

let $psact := for $id in $sids
    return
        $ps/fhir:Patient[fhir:id[@value=$id]]
let $pcnt := count($psact)
return
<structurdaten year="{$year}">
    <termine>
        <gesamt>{count($encs/fhir:Encounter[fhir:status[@value='finished']])}</gesamt>
    </termine>
    <patienten>
        <gesamt>{$pcnt}</gesamt>
        <byBirthDate>
            {
                let $ys := distinct-values(for $b in $psact/fhir:birthDate/@value
                                            return substring($b,1,4)
                                        )
                for $y in $ys
                order by $y
                return
                    <year y="{$y}">{count($psact/../fhir:Patient[fhir:birthDate[starts-with(@value,$y)]])}</year>
            }
        </byBirthDate>
    </patienten>
</structurdaten>
