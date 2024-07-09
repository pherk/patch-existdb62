xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-organization = "http://enahar.org/exist/restxq/metis/organizations";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config="http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare %private function r-organization:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-organization:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <organizations xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </organizations>
};

(:~
 : GET: /metis/organizations/{$id}
 : Retrieve an Organization identified by id.
 : 
 : @param $id
 : @return <Organization/>
 :)
declare 
    %rest:GET
    %rest:path("/metis/organizations/{$id}")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:header-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-organization:organizationByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    )
{
    let $prs := collection($config:metis-organizations)/Organization[id/@value=$id]
    return
        if (count($prs)>0) then
            xxpath:highest(function($e){$e/lastModified/@value/string()}, $prs)
        else r-organization:rest-response(404, concat('Organization with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /metis/organizations/{$id}/_history
 : get organization history with id $id
 : 
 : @param $id  organization id
 : 
 : @return  organization bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/organizations/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-organization:organizationHistoryByID(
      $id as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $hits  := collection($config:metis-organizations)/Organization[id/@value=$id] 
    return
        r-organization:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /metis/practioner/{$id}/_history/{$vid}
 : get organization history with id $id and version $vid
 : 
 : @param $id organization id
 : @param $vid version id
 : 
 : @return  organization bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/organizations/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-organization:organizationVersionByID(
     $id as xs:string*
   , $vid as xs:string*
   , $start as xs:string*
   , $length as xs:string*)
{
    let $hits  := collection($config:metis-organizations)/Organization[id/@value=$id][meta/versionID/@value=$vid]
    let $latest:= xxpath:highest(function($e){$e/lastModified/@value/string()}, $hits)
    return
        r-organization:prepareHistoryBundle($id, $latest)
};

declare %private function r-organization:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/metis/organizations/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/metis"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/meta/versionID/@value)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/metis/organizations/{$id}/_history/{$e/meta/versionID/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/metis/organizations/{$id}/_history/{$e/meta/versionID/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : GET: /metis/organizations
 : Search organizations using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '15')
 : @param $name     family-name
 : @param $super    super (within tags)
 : @param $tag      tag
 : @param $locality locality
 : @return organizations bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/organizations")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "15")
    %rest:query-param("name",   "{$name}", "")
    %rest:query-param("type",   "{$type}", "")
    %rest:query-param("tag",    "{$tag}", "")
    %rest:query-param("city",   "{$city}",  "")
    %rest:query-param("partOf", "{$partOf}",  "")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-organization:organizationsXML(
      $start as xs:string*
    , $length as xs:string*
    , $name as xs:string*
    , $type as xs:string*
    , $tag as xs:string*
    , $city as xs:string*
    , $partOf as xs:string*)
{
    let $hits := collection($config:metis-organizations)/Organization[partOf/reference[contains(@value,$partOf)]]
    let $matched := if ($name="" and $city="" and $tag="" and $type="")
        then $hits
        else if (r-organization:isPLZ($city))
        then $hits[matches(meta/tag/text/@value,$tag)][matches(type/coding/code/@value,$type)][matches(name/@value,$name)][matches(address/postalCode/@value,concat('^',$city))]
        else $hits[matches(meta/tag/text/@value,$tag)][matches(type/coding/code/@value,$type)][matches(name/@value,$name)][matches(address/city/@value,$city)]
    let $ids         := distinct-values($matched/id/@value/string())
    let $newest  := for $id in $ids
            let $prs := $hits[id/@value=$id]
            return
                if (count($prs)>1)
                then xxpath:highest(function($e){$e/lastModified/@value/string()}, $prs)
                else $prs
    let $hits  := $newest[partOf/reference[contains(@value,$partOf)]]
    let $valid :=  if ($name="" and $city="" and $tag="" and $type="")
        then $hits
        else if (r-organization:isPLZ($city))
        then $hits[matches(meta/tag/text/@value,$tag)][matches(type/coding/code/@value,$type)][matches(name/@value,$name)][matches(address/postalCode/@value,concat('^',$city))]
        else $hits[matches(meta/tag/text/@value,$tag)][matches(type/coding/code/@value,$type)][matches(name/@value,$name)][matches(address/city/@value,$city)]
    let $sorted-hits := for $c in $valid
        order by $c/name/@value collation "?lang=de-DE"
        return
            $c
    return
        r-organization:prepareResult($sorted-hits, $start, $length)
};

(:~
 : GET: /metis/organizations
 : Search organizations using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '15')
 : @param $name     family-name
 : @param $super    super (within tags)
 : @param $tag      tag
 : @param $locality locality
 : @return organizations bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/organizations")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "15")
    %rest:query-param("name",   "{$name}", "")
    %rest:query-param("type",   "{$type}", "")
    %rest:query-param("tag",    "{$tag}", "")
    %rest:query-param("city",   "{$city}",  "")
    %rest:query-param("partOf", "{$partOf}",  "")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-organization:organizationsJSON(
      $start as xs:string*
    , $length as xs:string*
    , $name as xs:string*
    , $type as xs:string*
    , $tag as xs:string*
    , $city as xs:string*
    , $partOf as xs:string*
    )
{
    let $hits := collection($config:metis-organizations)/Organization[partOf/reference[contains(@value,$partOf)]]
    let $matched := if ($name="" and $city="" and $tag="" and $type="")
        then $hits
        else if (r-organization:isPLZ($city))
        then $hits[matches(meta/tag/text/@value,$tag)][matches(type/coding/code/@value,$type)][matches(name/@value,$name)][matches(address/postalCode/@value,concat('^',$city))]
        else $hits[matches(meta/tag/text/@value,$tag)][matches(type/coding/code/@value,$type)][matches(name/@value,$name)][matches(address/city/@value,$city)]
    let $ids         := distinct-values($matched/id/@value/string())
    let $newest  := for $id in $ids
            let $prs := $hits[id/@value=$id]
            return
                if (count($prs)>1)
                then xxpath:highest(function($e){$e/lastModified/@value/string()}, $prs)
                else $prs
    let $hits  := $newest[partOf/reference[contains(@value,$partOf)]]
    let $valid :=  if ($name="" and $city="" and $tag="" and $type="")
        then $hits
        else if (r-organization:isPLZ($city))
        then $hits[matches(meta/tag/text/@value,$tag)][matches(type/coding/code/@value,$type)][matches(name/@value,$name)][matches(address/postalCode/@value,concat('^',$city))]
        else $hits[matches(meta/tag/text/@value,$tag)][matches(type/coding/code/@value,$type)][matches(name/@value,$name)][matches(address/city/@value,$city)]
    let $sorted-hits := for $c in $valid
        order by $c/name/@value collation "?lang=de-DE"
        return
            $c
    return
    <json:array xmlns:json="http://www.json.org">
    {
        for $u in $hits
        let $uid := $u/fhir:id/@value/string()
        let $name := $u/fhir:name/@value/string()
        order by lower-case($name)
        return

        <json:value xmlns:json="http://www.json.org" json:array="true">
            <id>{$uid}</id>
            <text>{$name}</text>
        </json:value>
    }
    </json:array>
};

declare %private function r-organization:isPLZ($str as xs:string) as xs:boolean
{
    (: test if str can be cast to number :)
    string(number($str)) != 'NaN'
};


(:~
 : PUT: /metis/organizations
 : Update an existing Organization or store a new one.
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/metis/organizations")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:header-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-organization:putOrganizationXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string* 
    , $lognam as xs:string*
    )
{
    let $isNew := not($content/Organization/@xml:id)
    let $cid   := if ($isNew)
        then concat("c-", util:uuid())
        else $content/Organization/id/@value/string()
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Organization/meta/versionID/@value/string()) + 1
    let $base := $content/Organization/fhir:*[not(
                                               self::meta
                                            or self::id
                                            or self::lastModified
                                            or self::lastModifiedBy
                                            )]
    let $meta := $content//meta/fhir:*[not(self::versionID)]
    let $uuid := if ($isNew) 
        then $cid
        else concat("c-", util:uuid())
    let $data := 
        <Organization xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </Organization>
        
    let $file  := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:metis-organizations, $file, $data)
            , sm:chmod(xs:anyURI($config:metis-organizations || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:metis-organizations || '/' || $file), $config:data-group)))
        return
            r-organization:rest-response(200, 'Organization sucessfully stored.') 
    } catch * {
        r-organization:rest-response(401, 'permission denied. Ask the admin.') 
    }
};
