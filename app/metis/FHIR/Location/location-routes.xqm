xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-location = "http://enahar.org/exist/restxq/metis/locations";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config="http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";
import module namespace date   = "http://enahar.org/exist/apps/metis/date"    at "../../modules/date.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-location:locationHistory := '/db/apps/metisData/History/Locations';

declare %private function r-location:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-location:prepareResult($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <locations xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            {
                for $l in subsequence($hits, $start, $len1)
                return
                    switch ($format)
                    case 'short' return
                        <Location xmlns="http://hl7.org/fhir">
                            <reference value="{concat('metis/locations/',$l/fhir:id/@value)}"/>
                            <description xmlns="http://hl7.org/fhir" value="{concat($l/fhir:id/@value,' - ',$l/fhir:description/@value)}"/>
                        </Location>
                    default return $l
            }
        </locations>
};

(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare function r-location:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-location:locationHistory)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-location:locationHistory, $nameHistory)
                    )
        )
};

(:~
 : GET: /metis/locations/{$id}
 : Retrieve an Location identified by id.
 : 
 : @param $id
 : @return <Location/>
 :)
declare 
    %rest:GET
    %rest:path("/metis/locations/{$id}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-location:locationByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $prs := collection($config:metis-locations)/fhir:Location[fhir:id[@value=$id]]
    return
        if (count($prs)=1)
        then $prs
        else if (count($prs) > 1)
        then r-location:rest-response(404, concat('Location with ID:',$id, ' found too many. Ask the Admin.'))
        else r-location:rest-response(404, concat('Location with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /metis/locations/{$id}/_history
 : get location history with id $id
 : 
 : @param $id  location id
 : 
 : @return  location bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/locations/{$id}/_history")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-location:locationHistoryByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        ) as item()
{
    let $colls := collection($config:metis-locations)
    let $hits  := $colls/fhir:Location[fhir:id[@value=$id]] 
    return
        r-location:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /metis/practioner/{$id}/_history/{$vid}
 : get location history with id $id and version $vid
 : 
 : @param $id location id
 : @param $vid version id
 : 
 : @return  location bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/locations/{$id}/_history/{$vid}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-location:locationVersionByID(
          $id as xs:string*
        , $vid as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        ) as item()
{
    let $colls := collection($config:metis-locations)
    let $hits  := $colls/fhir:Location[fhir:id[@value=$id]][fhir:meta/fhir:versionID/@value=$vid]
    return
        r-location:prepareHistoryBundle($id, $hits)
};

declare %private function r-location:prepareHistoryBundle($id, $entries)
{
    let $serverip := 'http://enahar.org'
    return
        <feed>
            <id value=""/>
            <meta>
                <versionID value="0"/>
            </meta>
            <type value="history"/>
            <title/>
            <link rel="self"      href="{$serverip}/exist/restxq/metis/locations/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/metis"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/fhir:meta/fhir:versionID/@value/string())
                return
                    <entry>
                        {$e/fhir:title}
                        <id>{$serverip}/exist/restxq/metis/locations/{$id}/_history/{$e/fhir:meta/fhir:versionID/@value/string()}</id>
                        <updated>{$e/fhir:lastModified/@value/string()}</updated>
                        <published>{$e/fhir:lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/metis/locations/{$id}/_history/{$e/fhir:meta/fhir:versionID/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : GET: /metis/locations
 : Search locations using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '15')
 : @param $name     family-name
 : @param $super    super (within tags)
 : @param $tag      tag
 : @param $city     city
 : @return locations bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/locations")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("name",   "{$name}", "")
    %rest:query-param("type",   "{$type}", "")
    %rest:query-param("partOf", "{$partOf}",  "")
    %rest:query-param("_format","{$format}",  "full")
    %rest:produces("application/xml", "text/xml")
function r-location:locationsXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $name as xs:string*
        , $type as xs:string*
        , $partOf as xs:string*
        , $format as xs:string*
        ) as item()
{
    let $colls := collection($config:metis-locations)
    let $matched := $colls/fhir:Location[fhir:physicalType/fhir:coding/fhir:code[matches(@value,$type)]][fhir:partOf/fhir:reference[matches(@value,$partOf)]][fhir:name[matches(@value,$name)]]

    let $sorted-hits := for $c in $matched
        order by $c/fhir:id/@value/string() collation "?lang=de-DE"
        return
            $c
    return
        r-location:prepareResult($sorted-hits, $start, $length, $format)
};

declare %private function r-location:isPLZ($str as xs:string) as xs:boolean
{
    (: test if str can be cast to number :)
    string(number($str)) != 'NaN'
};


(:~
 : PUT: /metis/locations
 : Update an existing Location or store a new one.
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/metis/locations")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-location:putLocationXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    )
{
    let $isNew := not($content/fhir:Location/@xml:id)
    let $cid   := if ($isNew)
        then concat("loc-", util:uuid())
        else 
            let $id := $content/fhir:Location/fhir:id/@value/string()
            let $loc := collection($config:metis-locations)/fhir:Location[fhir:id[@value = $id]]
            let $move := r-location:moveToHistory($loc)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Location/fhir:meta/fhir:versionID/@value/string()) + 1
    let $base := $content/fhir:Location/fhir:*[not(
                                               self::meta
                                            or self::id
                                            or self::lastModified
                                            or self::lastModifiedBy
                                            )]
    let $meta := $content//fhir:meta/fhir:*[not(self::versionID)]
    let $uuid := if ($isNew) 
        then $cid
        else concat("loc-", util:uuid())
    let $data := 
        <Location xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                {$meta}
                <versionID value="{$version}"/>
            </meta>
            <lastModifiedBy>
                <ref value="{concat('metis/practitioners/',$loguid)}"/>
                <display value="{$lognam}"/>
            </lastModifiedBy>    
            <lastModified value="{current-dateTime()}"/>
            { $base }
        </Location>
        
    let $file  := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:metis-locations, $file, $data)
            , sm:chmod(xs:anyURI($config:metis-locations || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:metis-locations || '/' || $file), $config:data-group)))
        return
            r-location:rest-response(200, 'Location sucessfully stored.') 
    } catch * {
        r-location:rest-response(401, 'permission denied. Ask the admin.') 
    }
};
