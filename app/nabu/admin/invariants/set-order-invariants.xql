xquery version "3.1";

(:~
 : Eoc/CT Kombi, die auf "onhold" oder "waitlist" steht, auf "active" oder "completed" setzen
 : die beiden status sind illegal, da sie beim Laden des Patienten nicht mitgeladen werden
 :)

declare namespace fhir= "http://hl7.org/fhir";

let $status := "completed"


let $os := collection('/db/apps/nabuData/data/FHIR/Orders')
let $aos := $os/fhir:Order[fhir:status[@value="active"]]
return
<ao-status>
{
    for $o in $aos
    return
        let $ds  := $o/fhir:detail
        for $d in $ds
        return
            if ($d/fhir:actor/fhir:required/@value="")
            then let $upd := system:as-user("admin","kikl968", (update value $d/fhir:actor/fhir:required/@value with "true"))
                 return <r id="{$o/fhir:subject/fhir:reference/@value}"/>
            else if ($d/fhir:spec/fhir:combination/@value="")
            then let $cs  := distinct-values($ds/fhir:spec/fhir:combination/@value)
                 let $max := max(for $c in $cs return if ($c="") then 0 else xs:integer($c))
                 let $upd := system:as-user("admin","kikl968", (update value $d/fhir:spec/fhir:combination/@value with $max))
                 return <c id="{$o/fhir:subject/fhir:reference/@value}">{$max}</c>
            else ()
}</ao-status>
