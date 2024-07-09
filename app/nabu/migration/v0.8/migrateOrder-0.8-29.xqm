xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $s := 'requested'
let $os := $oc/fhir:Order[fhir:status[@value=$s]][fhir:reason//fhir:code/@value='appointment']
return
 element {$s} {
    attribute n {count($os)}
    , let $dvs := for $o in $os
            return
                system:as-user('vdba','kikl823!', update replace $o/fhir:status/@value with 'active')
        return
            $dvs
    }
