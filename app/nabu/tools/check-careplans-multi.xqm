xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $cps := collection('/db/apps/nabuCom/data/CarePlans')
let $oc  := collection('/db/apps/nabuData/data/FHIR/Orders')
let $tc  := collection('/db/apps/nabuCom/data/Tasks')
let $ec  := collection('/db/apps/nabuEncounter/data')
let $scps := $cps/fhir:CarePlan[starts-with(fhir:title/@value,'Request')][fhir:status[@value="active"]]
let $ss := distinct-values($scps/fhir:subject/fhir:reference/@value)
 
for $s in $ss[.!='']
let $cpss := $cps/fhir:CarePlan[fhir:subject/fhir:reference[@value=$s]][fhir:status[@value="active"]]

return
    if (count($cpss)>4)
    then
        let $os := $oc/fhir:Order[fhir:subject/fhir:reference[@value=$s]]
        let $ts := $tc/fhir:Task[fhir:subject/fhir:reference[@value=$s]]
        (: select one :)
        let $acc := let $notRI := $cpss[not(starts-with(fhir:title/@value,('Human','Request')))]      (: not-imported or edited :)
            let $first := $notRI[1]/fhir:id/@value
            return
                if (count($notRI)=0)
                then $cpss[1]
                else $cpss[fhir:id[@value=$first]]
        let $dons := for $c in $cpss[fhir:id[@value!=$acc/fhir:id/@value]]
            return
                $c
        return
            <res s="{$s}">
                <acc title="{$acc/fhir:title/@value/string()}" nactions="{count($acc/fhir:activity)}">{count($acc)}</acc>
                <dons>
                {
                    for $d in $dons
                    return
                        <don nactions="{count($d/fhir:activity)}"/>
                }
                </dons>
                <all nactions="{count($cpss/fhir:activity)}">{count($cpss)}</all>
            </res>
    else ()