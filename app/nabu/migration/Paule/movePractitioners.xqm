xquery version "3.0";

import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-practitioner  = "http://enahar.org/exist/restxq/metis/practitioners"   at "/db/apps/metis/FHIR/Practitioner/practitioner-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";



let $history := collection('/db/apps/metisData/data/History')
let $osh := $history/fhir:Practitioner

let $realm := 'kikl-spz'

let $ids   := distinct-values($osh/fhir:id/@value)
for $id in $ids
let $o :=
    let $ods := $osh[fhir:id/@value=$id]
    return
        if (count($ods)>1)
        then    xxpath:highest(function($o){$o/fhir:lastModified/@value/string()}, $ods)
        else $ods
let $new    := $o
let $loguid := $o/fhir:lastModifiedBy/fhir:reference/@value/string()
let $lognam := $o/fhir:lastModifiedBy/fhir:display/@value/string()
let $store  := r-practitioner:putPractitionerXML(<content>{$new}</content>, $realm, $loguid, $lognam)
return
    ()