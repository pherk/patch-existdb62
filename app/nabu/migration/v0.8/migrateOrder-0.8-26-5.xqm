xquery version "3.0";

import module namespace ordermigr  = "http://enahar.org/exist/apps/nabu/order-migration"     at "../../FHIR/Order/order-migration.xqm";
import module namespace r-careplan = "http://enahar.org/exist/restxq/nabu/careplans"     at "../../FHIR/CarePlan/careplan-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $oc := collection('/db/apps/nabuData/data/FHIR/Orders')
let $os := $oc/fhir:Order[fhir:status[@value=('requested','received','accepted')]]

let $realm := 'kikl-spz'
let $author := 
    <author xmlns="http://hl7.org/fhir">
        <reference value="metis/practitioners/u-admin"/>
        <display value="import-bot"/>
    </author>
            
for $o in $os[1]
return
    if ($o/fhir:basedOn and $o/fhir:basedOn/fhir:reference/@value!='')
    then (: check if CP link is valid :)
        if (count(r-careplan:careplanByID(substring-after($o/fhir:basedOn/fhir:reference/@value,'nabu/careplans/'),$realm,'u-admin','admin'))>0)
        then
            ()
        else $o
    else
        ordermigr:update-0.8-26-4($realm, $author, $o)