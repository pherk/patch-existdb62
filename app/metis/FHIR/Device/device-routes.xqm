xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-device = "http://enahar.org/exist/restxq/metis/devices";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config="http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";
import module namespace date   = "http://enahar.org/exist/apps/metis/date"    at "../../modules/date.xqm";
import module namespace r-user = "http://enahar.org/exist/restxq/metis/users"  at "/db/apps/metis/FHIR/user/user-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-device:deviceHistory := '/db/apps/metisData/History/Devices';

declare %private function r-device:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-device:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <devices xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </devices>
};

(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare function r-device:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-device:deviceHistory)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-device:deviceHistory, $nameHistory)
                    )
        )
};

(:~
 : GET: /metis/devices/{$id}
 : Retrieve an Device identified by id.
 : 
 : @param $id
 : @return <Device/>
 :)
declare 
    %rest:GET
    %rest:path("/metis/devices/{$id}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")    
    %rest:produces("application/xml", "text/xml")
function r-device:deviceByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        )
{
    let $coll := collection($config:metis-devices)
    let $prs := $coll/fhir:Device[fhir:id[@value=$id]]
    return
        if (count($prs)=1)
        then
            $prs
        else r-device:rest-response(404, concat('Device with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /metis/devices/{$id}/_history
 : get device history with id $id
 : 
 : @param $id  device id
 : 
 : @return  device bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/devices/{$id}/_history")
    %rest:path("/metis/devices/{$id}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}") 
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-device:deviceHistoryByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        ) as xs:string*
{
    let $coll := collection($config:metis-devices)
    let $hits := $coll/fhir:Device[fhir:id[@value=$id]] 
    return
        r-device:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /metis/practioner/{$id}/_history/{$vid}
 : get device history with id $id and version $vid
 : 
 : @param $id device id
 : @param $vid version id
 : 
 : @return  device bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/devices/{$id}/_history/{$vid}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}") 
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-device:deviceVersionByID(
          $id as xs:string*
        , $vid as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        )
{
    let $colls  := collection($config:metis-devices)
    let $hits := $colls/fhir:Device[fhir:id[@value=$id]][fhir:meta/fhir:versionID/@value=$vid]
    return
        r-device:prepareHistoryBundle($id, $hits)
};

declare %private function r-device:prepareHistoryBundle($id, $entries)
{
    let $serverip := 'http://enahar.org'
    return
        <feed>
            <id/>
            <meta>
                <versionID value="0"/>
            </meta>
            <type value="history"/>
            <title/>
            <link rel="self"      href="{$serverip}/exist/restxq/metis/devices/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/metis"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/meta/versionID)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/metis/devices/{$id}/_history/{$e/meta/versionID/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/metis/devices/{$id}/_history/{$e/meta/versionID/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : GET: /metis/devices
 : Search devices using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '*')
 : @param $name     family-name
 : @param $param    type (pc,printer)
 : @param $tag      tag
 : @param $location location
 : @return devices bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/devices")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}") 
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("name",  "{$name}", "")
    %rest:query-param("type", "{$type}", "")
    %rest:query-param("tag",   "{$tag}", "")
    %rest:query-param("location",  "{$location}",  "")
    %rest:produces("application/xml", "text/xml")
function r-device:devicesXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $name as xs:string*
        , $type as xs:string*
        , $tag as xs:string*
        , $location as xs:string*
        ) as item()
{
    let $matched := if ($type="" and $location="")
        then collection($config:metis-devices)/fhir:Device
        else collection($config:metis-devices)/fhir:Device[matches(fhir:meta/fhir:tag/fhir:text/@value,$tag)][matches(fhir:type/fhir:coding/fhir:code/@value,$type)][matches(fhir:location/fhir:reference/@value,$location)]
    let $sorted-hits := for $c in $matched
        order by $c/fhir:location/fhir:reference/@value/string() collation "?lang=de-DE"
        return
            $c
    return
        r-device:prepareResult($sorted-hits, $start, $length)
};

(:~
 : GET: /metis/devices2csv
 : Search devices using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '*')
 : @param $name     family-name
 : @param $param    type (pc,printer)
 : @param $tag      tag
 : @param $location location
 : @return devices as csv
 :)
declare 
    %rest:GET
    %rest:path("/metis/devices2csv")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}") 
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("name",  "{$name}", "")
    %rest:query-param("type", "{$type}", "")
    %rest:query-param("tag",   "{$tag}", "")
    %rest:query-param("location",  "{$location}",  "")
    %rest:produces("text/csv")
    %output:method("text")
function r-device:devices2CSV(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $name as xs:string*
        , $type as xs:string*
        , $tag as xs:string*
        , $location as xs:string*
        )
{
    let $nl := "&#10;"
    let $matched := if ($type="" and $location="")
        then collection($config:metis-devices)/fhir:Device
        else collection($config:metis-devices)/fhir:Device[matches(fhir:meta/fhir:tag/fhir:text/@value,$tag)][matches(fhir:type/fhir:coding/fhir:code/@value,$type)][matches(fhir:location/fhir:reference/@value,$location)]
    let $sorted-hits := for $c in $matched
        order by $c/fhir:location/fhir:reference/@value/string() collation "?lang=de-DE"
        return
            $c
let $csv :=
  string-join(
        ("Hs-Etage-Raum, Typ, PC-Name, IP, OS, NonStandardApps",
        for $d in $sorted-hits
        return
            if ($d/type/coding/code/@value="pc")
            then string-join(
                    (
                      $d/fhir:id/@value
                    , "PC"
                    , $d/fhir:identifier/fhir:value/@value
                    , $d/fhir:url/@value
                    , $d/fhir:extension[@url="#device-os"]/fhir:valueCode/@value
                    , replace($d/fhir:extension[@url="#device-apps"]/fhir:valueCode/@value,',',';')
                    )
                    , ', ')
            else string-join(
                    (
                      $d/fhir:id/@value
                    , "Printer"
                    , $d/fhir:identifier/fhir:value/@value
                    , $d/fhir:url/@value
                    , ""
                    , ""
                    )
                    , ', ')
        )
    , $nl)
return
    (   <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="text/csv"/>
                <http:header name="Content-Disposition" value="attachment;filename=devices.csv"/>
            </http:response>
         </rest:response>
    , $csv)
};


(:~
 : PUT: /metis/devices
 : Update an existing Device or store a new one.
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/metis/devices")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}") 
    %rest:produces("application/xml", "text/xml")
function r-device:putDeviceXML(
          $content as document-node()*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        )
{
    let $isNew := not($content/fhir:Device/@xml:id)
    let $cid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:Device/fhir:id/@value/string()
            let $device := collection($config:metis-devices)/fhir:Device[fhir:id[@value = $id]]
            let $move := r-device:moveToHistory($device)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Device/fhir:meta/fhir:versionID/@value/string()) + 1
    let $base := $content/fhir:Device/fhir:*[not(
                                               self::meta
                                            or self::id
                                            or self::lastModified
                                            or self::lastModifiedBy
                                            )]
    let $meta := $content//fhir:meta/fhir:*[not(self::versionID)]
    let $uuid := if ($isNew) 
        then $cid
        else concat("c-", util:uuid())
    let $data := 
        <Device xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                {$meta}
                <versionID value="{$version}"/>
            </meta>
            <lastModifiedBy>
                <ref value="metis/practitioners/{$loguid}"/>
                <display value="importBot"/>
            </lastModifiedBy>    
            <lastModified value="{current-dateTime()}"/>
            { $base }
        </Device>
        
    let $file  := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:metis-devices, $file, $data)
            , sm:chmod(xs:anyURI($config:metis-devices || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:metis-devices || '/' || $file), $config:data-group)))
        return
            r-device:rest-response(200, 'Device sucessfully stored.') 
    } catch * {
        r-device:rest-response(401, 'permission denied. Ask the admin.') 
    }
};
