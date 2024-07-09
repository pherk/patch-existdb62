xquery version "3.1";

let $p18s := collection('/db/apps/nabuData/data/FHIR/Patients')/*:Patient[*:extension[@url="#patient-over-18"]]
return
<p-over-18>{
    for $ps in $p18s
    group by $status := $ps/*:extension[@url="#patient-over-18"]/*:valueCodeableConcept/*:coding/*:code/@value/string()
    order by $status
    return
        switch ($status)
        case "over-18-granted" return for $p in $ps
                                   order by $p/*:extension[@url="#patient-over-18-limit"]/*:valueDate/@value/string()
                                   return <over-18-granted name="{$p/*:text/string()}" limit="{$p/*:extension[@url='#patient-over-18-limit']/*:valueDate/@value}"/>
        case "not-granted"     return for $p in $ps
                                   order by $p/*:birthDate/@value
                                   return <not-granted name="{$p/*:text/string()}"/>
        case "mzeb"            return <mzeb name="{$ps/*:text/string()}"/>
        case "other"           return <other name="{$ps/*:text/string()}"/>
        case "poli"            return for $p in $ps
                                   order by $p/*:birthDate/@value
                                   return <poli name="{$p/*:text/string()}"/>
        case "unknown"         return for $p in $ps
                                   order by $p/*:birthDate/@value
                                   return <unknown name="{$p/*:text/string()}"/>
        default                return <error name="{$ps/*:text/string()}" status="{$status}"/>
}</p-over-18>