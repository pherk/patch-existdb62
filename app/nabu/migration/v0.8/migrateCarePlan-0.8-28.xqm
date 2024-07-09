xquery version "3.0";

import module namespace cpmigr = "http://enahar.org/exist/apps/nabu/careplan-migration"     at "../../FHIR/CarePlan/careplan-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $cpc := collection('/db/apps/nabuCom/data/CarePlans')

let $realm := 'kikl-spz'

let $cps := for $cp in $cpc/fhir:CarePlan
(: 
    let $upd := system:as-user('vdba','kikl823!',
                    update delete $cp/fhir:activity[fhir:reference/fhir:reference/@value=""]
                )
:)
    let $oids := $cp/fhir:activity/fhir:reference/fhir:reference/@value ! substring-after(.,'nabu/orders/')
    let $os := if (count($oids)>0)
        then $oc/fhir:Order[fhir:id[@value=$oids]] 
        else () 
    let $as :=
        for $oid in $oids
        let $a := $cp/fhir:activity[fhir:reference/fhir:reference/@value=concat('nabu/orders/',$oid)]
        return 
            if (substring($a/fhir:progress[1]/fhir:time/@value,1,16)=substring($os[fhir:id/@value=$oid]/fhir:date/@value,1,16))
            then ()
            else if ($os[fhir:id/@value=$oid])
                then
                    (:
                    let $upd := system:as-user('vdba','kikl823!',
                        update value 
                            $a/fhir:progress[1]/fhir:time/@value with
                            $os[fhir:id/@value=$oid]/fhir:date/@value/string()
                        )
                    return ()
                        :)
                    ()
                else 
                    let $upd := system:as-user('vdba','kikl823!',
                        update delete $a
                        )
                    return
                        'd'
    return
        if ($as)
        then 
            $cp
        else ()
return
    $cps
