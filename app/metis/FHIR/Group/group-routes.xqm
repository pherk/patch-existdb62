xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-group = "http://enahar.org/exist/restxq/metis/groups";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config="http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare %private function r-group:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-group:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <groups xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </groups>
};

(:~
 : GET: /metis/groups/{$id}
 : Retrieve an Group identified by id.
 : 
 : @param $id
 : @return <Group/>
 :)
declare 
    %rest:GET
    %rest:path("/metis/groups/{$id}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-group:getGroupByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) {
    let $prs := collection($config:metis-groups)/Group[fhir:id[@value=$id]]
    return
        if (count($prs)>0) then
            xxpath:highest(function($e){$e/lastModified/@value/string()}, $prs)
        else r-group:rest-response(404, concat('Group with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /metis/groups/{$id}/_history
 : get group history with id $id
 : 
 : @param $id  group id
 : 
 : @return  group bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/groups/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-group:groupHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $hits  := collection($config:metis-groups)/Group[id/@value=$id] 
    return
        r-group:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /metis/groups/{$id}/_history/{$vid}
 : get group history with id $id and version $vid
 : 
 : @param $id group id
 : @param $vid version id
 : 
 : @return  group bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/groups/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-group:groupVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $hits  := collection($config:metis-groups)/Group[id/@value=$id][meta/versionID/@value=$vid]
    let $latest:= xxpath:highest(function($e){$e/lastModified/@value/string()}, $hits)
    return
        r-group:prepareHistoryBundle($id, $latest)
};

declare %private function r-group:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/metis/groups/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/metis/groups/{$id}/_history/{$e/meta/versionID/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/metis/groups/{$id}/_history/{$e/meta/versionID/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : GET: /metis/groups
 : Search groups using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '15')
 : @param $name     family-name
 : @param $super    super (within tags)
 : @param $tag      tag
 : @param $locality locality
 : @return groups bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/groups")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("name",   "{$name}", "")
    %rest:query-param("type",   "{$type}", "")
    %rest:query-param("tag",    "{$tag}", "")
    %rest:produces("application/xml", "text/xml")
function r-group:groups($start as xs:string*, $length as xs:string*,
            $name as xs:string*, $type as xs:string*, $tag as xs:string*) as item()
{
    let $hits     := collection($config:metis-groups)/Group
    let $matched := if ($name="" and $tag="" and $type="")
        then $hits
        else $hits[matches(meta/tag/text/@value,$tag)][type/@value=$type][matches(name/@value,$name)]
    let $ids         := distinct-values($matched/id/@value/string())
    let $newest  := for $id in $ids
            let $prs := collection($config:metis-groups)/Group[id[@value=$id]]
            return
                if (count($prs)>1)
                then xxpath:highest(function($e){$e/lastModified/@value/string()}, $prs)
                else $prs
    let $valid :=  if ($name="" and $tag="" and $type="")
        then $newest
        else $newest[matches(meta/tag/text/@value,$tag)][type/@value=$type][matches(name/@value,$name)]
    let $sorted-hits := for $c in $valid
        order by $c/name/@value collation "?lang=de-DE"
        return
            $c
    return
        r-group:prepareResult($sorted-hits, $start, $length)
};

declare %private function r-group:isPLZ($str as xs:string) as xs:boolean
{
    (: test if str can be cast to number :)
    string(number($str)) != 'NaN'
};


(:~
 : PUT: /metis/groups
 : Update an existing Group or store a new one.
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/metis/groups")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:produces("application/xml", "text/xml")
function r-group:putGroup(
      $content as node()*
    , $realm as xs:string*
    , $loguid as xs:string* )
{
    let $isNew := not($content/Group/@xml:id)
    let $cid   := if ($isNew)
        then concat("c-", util:uuid())
        else $content/Group/id/@value/string()
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Group/meta/versionID/@value/string()) + 1
    let $base := $content/Group/fhir:*[not(
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
        <Group xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </Group>
        
    let $file  := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:metis-groups, $file, $data)
            , sm:chmod(xs:anyURI($config:metis-groups || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:metis-groups || '/' || $file), $config:data-group)))
        return
            r-group:rest-response(200, 'Group sucessfully stored.') 
    } catch * {
        r-group:rest-response(401, 'permission denied. Ask the admin.') 
    }
};


(:~
 : GET: /metis/roles
 : 
 : @param $name   ('i')
 : @param $filter 'service'
 : 
 : @return bundle <group/>
 :)
declare
    %rest:GET
    %rest:path("/metis/roles")
    %rest:query-param("start",  "{$start}",  "1")      
    %rest:query-param("length", "{$length}", "100")
    %rest:query-param("org",    "{$org}",   "metis/organizations/kikl-spz")
    %rest:query-param("name",   "{$name}",   "")
    %rest:query-param("filter", "{$filter}", "")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-group:roles($start as xs:string*, $length as xs:string*,
        $org as xs:string*, $name as xs:string*, $filter as xs:string*) 
{ 
    let $length := '*'
    let $hits     := collection($config:metis-groups)/fhir:Group[fhir:type/@value=('practitioner','role')]
    let $filtered := switch($filter)
        case 'service' return $hits/../fhir:Group[fhir:characteristics[fhir:code/fhir:text/@value='service'][fhir:valueCode/@value='true']]
        default        return $hits
    let $matched := switch($name)
        case "" return $filtered
        default return $filtered/../fhir:Group[matches(fhir:name/@value, $name, 'i')]
    let $sorted-hits := for $r in $matched
        let $base := $r/fhir:*[not(self::fhir:member)]
        order by $r/fhir:name/@value/string()
        return
            <Group>
                {$base}
            </Group>
(: 
                {
                    for $u in r-practitioner:practitioners('1','*', '', '', $org, $r/code/text/@value, '', '', 'true')//fhir:Practitioner
                    return
                        <member>
                            <reference value="{$u/fhir:id/@value/string()}"/>
                            <display value="{ string-join($u/fhir:name[fhir:use/@value='official']/fhir:family/@value, ' ')}"/>
                        </member>
                }
:)
    return
        r-group:prepareResult($sorted-hits, $start, $length)
};

(:~
 : GET: /metis/roles/{$alias}/alias
 : @alias user alias
 : @return <roles><role>...</role></roles>
 : @deprecated should use /metis/users/{$uid}/roles
 :)
declare
    %rest:GET
    %rest:path("/metis/roles/{$alias}/alias")
    %rest:produces("application/xml", "text/xml")
function r-group:roleByAlias($alias as xs:string*) {
    let $r := collection($config:metis-groups)/Group[code/text/@value=$alias]
    return
        if ($r)
        then $r
        else r-group:rest-response(404, 'role not found. Ask the admin.')
};

(:~
 : GET: /metis/roles?name=...
 : 
 : @param $name ('i')
 : @return json array
 :)
declare 
    %rest:GET
    %rest:path("metis/roles")
    %rest:query-param("start",  "{$start}",  "1")      
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("org",    "{$org}",   "metis/organizations/kikl-spz")
    %rest:query-param("name",   "{$name}",   "")
    %rest:query-param("filter", "{$filter}", "")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-group:rolesJSON($start as xs:string*, $length as xs:string*,
        $org as xs:string*, $name as xs:string*, $filter as xs:string*) as item()
{
    let $hits     := collection($config:metis-groups)/Group[type/@value=('practitioner','role')]
    let $filtered := switch($filter)
        case 'service' return $hits[characteristics[code/text/@value='service']/valueCode/@value='true']
        default        return $hits
    let $matched := switch($name)
        case "" return $filtered
        default return $filtered[matches(name/@value, $name, 'i')]
    let $sorted-hits := for $r in $matched
        let $base := $r/fhir:*[not(self::fhir:member)]
        order by $r/name/@value/string()
        return
            <Group>
                {$base}
            </Group>
    let $count := count($sorted-hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <json:array xmlns:json="http://www.json.org">
        {
            for $r in subsequence($sorted-hits, $start, $len1) 
            let $alias := $r/code/text/@value/string()
            let $name := $r/name/@value/string()
            order by lower-case($name)
            return
            <json:value xmlns:json="http://www.json.org" json:array="true">
                <id>{$alias}</id>
                <text>{$name}</text>
            </json:value>
        }
        </json:array>
};
