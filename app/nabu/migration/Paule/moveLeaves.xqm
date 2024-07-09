xquery version "3.0";

import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-leave  = "http://enahar.org/exist/restxq/metis/leaves"   at "/db/apps/metis/FHIR/Leave/leave-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";



let $history := collection('/db/apps/metisData/data/History')
let $osh := $history/leave

let $realm := 'kikl-spz'

let $ids   := distinct-values($osh/id/@value)
for $id in $ids
let $o :=
    let $ods := $osh[id/@value=$id]
    return
        if (count($ods)>1)
        then    xxpath:highest(function($o){$o/lastModified/@value/string()}, $ods)
        else $ods
let $new    := $o
let $loguid := $o/lastModifiedBy/reference/@value/string()
let $lognam := $o/lastModifiedBy/display/@value/string()
let $store  := r-leave:putLeaveXML(<content>{$new}</content>, $realm, $loguid, $lognam)
return
    ()