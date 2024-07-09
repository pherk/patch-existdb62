xquery version "3.0";

import module namespace r-order    = "http://enahar.org/exist/restxq/nabu/orders"         at "../../FHIR/Order/order-routes.xqm";
import module namespace ordermigr  = "http://enahar.org/exist/apps/nabu/order-migration"  at "../../FHIR/Order/order-migration.xqm";
import module namespace r-careplan = "http://enahar.org/exist/restxq/nabu/careplans"      at "../../FHIR/CarePlan/careplan-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $pec := collection('/db/apps/nabuEncounter/data/planned')/fhir:Encounter


let $realm := 'kikl-spz'
let $author := 
    <author xmlns="http://hl7.org/fhir">
        <reference value="metis/practitioners/u-admin"/>
        <display value="import-bot"/>
    </author>
            
for $e in $pec[1]
let $oid := substring-after(tokenize($e/fhir:appointment/fhir:reference/@value,'\?')[1],'nabu/orders/')
let $o := r-order:orderByID($oid,$realm,'u-admin','admin')
return (: pre 0.8 orders have no basedOn elment :)
    if ($o/fhir:basedOn and $o/fhir:basedOn/fhir:reference/@value!='')
    then (: check if CP link is valid :)
        if (count(r-careplan:careplanByID(substring-after($o/fhir:basedOn/fhir:reference/@value,'nabu/careplans/'),$realm,'u-admin','admin'))>0)
        then ()
        else $o
    else
        (: orders with other status will update with migrateOrder-0.8-26-4 script :)
        if ($o/fhir:status/@value='completed')
        then ordermigr:update-0.8-26-4($realm, $author, $o)
        else ()
