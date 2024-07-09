xquery version "1.0";

import module namespace xmldb    = "http://exist-db.org/xquery/xmldb";
import module namespace util     = "http://exist-db.org/xquery/util";
import module namespace request  = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";

import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

declare option exist:serialize "method=json media-type=text/javascript";


let $key := request:get-parameter('person','')

return
<json:value xmlns:json="http://www.json.org">
    <json:value xmlns:json="http://www.json.org" json:array="true">
        <id>pmh</id>
        <text>Peter Herkenrath</text>
    </json:value>
</json:value>