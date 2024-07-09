xquery version "3.1";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config ="http://enahar.org/exist/apps/metis/config"  at "../../modules/config.xqm";
import module namespace date   = "http://enahar.org/exist/apps/metis/date"   at "../../modules/date.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare namespace fo     ="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  ="http://exist-db.org/xquery/xslfo";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-practitioner:coll := collection($config:metis-practitioners);
declare variable $r-practitioner:practitionerHistory := '/db/apps/metisData/data/History/Practitioners';

declare %private function r-practitioner:formatFHIRname(
          $p as element(fhir:Practitioner)
        ) as xs:string
{
    let $name := $p/fhir:name[fhir:use/@value='official']
    return
        concat(
              $name/fhir:family/@value
            , ', '
            , $name/fhir:given/@value
            , ', '
            , $p/fhir:address/postalCode/@value
            , ' '
            , $p/fhir:address/fhir:city/@value
            )
};

declare function r-practitioner:generateText(
          $p as element(fhir:Practitioner)
        ) as element(fhir:text)
{
    let $composite-name := r-practitioner:formatFHIRname($p)
    let $text :=
            <text xmlns="http://hl7.org/fhir">
                <status value="generated"/>
                <div xmlns="http://www.w3.org/1999/xhtml">
                    <div class="composite-name">{$composite-name}</div>
                </div>
            </text>
    return
        $text
};
(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare %private function r-practitioner:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-practitioner:practitionerHistory)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-practitioner:practitionerHistory, $nameHistory)
                    )
        )
};

declare %private function r-practitioner:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-practitioner:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <practitioners xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </practitioners>
};

(:~
 : GET: /metis/practitioners/{$id}
 : Retrieve an Practitioner identified by id.
 : 
 : @param $id
 : @return <Practitioner/>
 :)
declare 
    %rest:GET
    %rest:path("/metis/practitioners/{$id}")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/xml", "text/xml")
function r-practitioner:practitionerByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $active as xs:string*
    )
{
    let $prs := $r-practitioner:coll/fhir:Practitioner[fhir:id[@value = $id]]
    return
        if (count($prs)=1)
        then if ($prs/../fhir:Practitioner[fhir:active[@value=$active]])
            then $prs
            else r-practitioner:rest-response(404, concat('Practitioner with ID: ',$id, ' found, but active != ', $active))
        else r-practitioner:rest-response(404, concat('Practitioner with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /metis/practitioners/{$id}/_history
 : get practitioner history with id $id
 : 
 : @param $id  practitioner id
 : 
 : @return  practitioner bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/practitioners/{$id}/_history")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/xml", "text/xml")
function r-practitioner:practitionerHistoryByID(
        $id as xs:string*,
        $realm as xs:string*, $loguid as xs:string*,
        $start as xs:string*, $length as xs:string*,
        $active as xs:string*)
{
    let $hits  := $r-practitioner:coll/fhir:Practitioner[fhir:id[@value=$id]][fhir:active[@value=$active]]
    return
        r-practitioner:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /metis/practioner/{$id}/_history/{$vid}
 : get practitioner history with id $id and version $vid
 : 
 : @param $id practitioner id
 : @param $vid version id
 : 
 : @return  practitioner bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/practitioners/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-practitioner:practitionerVersionByID(
        $id as xs:string*, $vid as xs:string*,
        $start as xs:string*, $length as xs:string*)
{
    let $hits  := $r-practitioner:coll/fhir:Practitioner[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-practitioner:prepareHistoryBundle($id, $hits)
};

declare %private function r-practitioner:prepareHistoryBundle($id, $entries)
{
    let $serverip := 'http://enahar.org'
    return
        <feed>
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <type value="history"/>
            <title/>
            <link rel="self"      href="{$serverip}/exist/restxq/metis/practitioners/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/metis"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/fhir:meta/fhir:versionId)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/metis/practitioners/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}</id>
                        <updated>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</updated>
                        <published>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/metis/practitioners/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : GET: /metis/practitioners/{$id}
 : Retrieve an Practitioner identified by id
 : 
 : @param $id
 : @return <Practitioner/>
 :)
declare 
    %rest:GET
    %rest:path("/metis/practitioners/{$id}/account")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:query-param("system", "{$system}", "")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/xml", "text/xml")
function r-practitioner:practitionerByIdentifier(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $system as xs:string*
        , $active as xs:string*
        )
{
    let $prs := if ($system="")
        then $r-practitioner:coll/fhir:Practitioner[fhir:identifier[fhir:value/@value = $id]]
        else $r-practitioner:coll/fhir:Practitioner[fhir:identifier[fhir:value/@value = $id]]
    return
        if (count($prs) > 0)
        then if ($prs/../fhir:Practitioner[fhir:active[@value=$active]])
            then $prs/../fhir:Practitioner[fhir:active[@value=$active]]
            else r-practitioner:rest-response(404, concat('Practitioner with ID: ',$id, ' found, but active != ', $active))
        else r-practitioner:rest-response(404, concat('Practitioner with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /metis/practitioners
 : Search practitioners using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '15')
 : @param $name     family-name
 : @param $tag      tag
 : @param $city     city
 : @param $org      organization ref
 : @þaram $role     role code
 : @param $active   active
 : @return practitioners bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/practitioners")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "15")
    %rest:query-param("name",  "{$name}", "")
    %rest:query-param("city",  "{$city}",  "")
    %rest:query-param("org",   "{$org}",  "")
    %rest:query-param("role",  "{$role}",  "")
    %rest:query-param("specialty", "{$specialty}",  "")
    %rest:query-param("tag",   "{$tag}", "")
    %rest:query-param("active","{$active}",  "true")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-practitioner:practitioners(
      $start as xs:string*, $length as xs:string*
    , $name as xs:string*
    , $city as xs:string*
    , $org as xs:string*
    , $role as xs:string*
    , $specialty as xs:string*
    , $tag as xs:string*
    , $active as xs:string*
    ) as item()
{
    let $oref := concat('metis/organizations/',$org)
    let $hits := if ($role!='')
        then $r-practitioner:coll/fhir:Practitioner[fhir:role/fhir:coding/fhir:code[@value=$role]]
        else $r-practitioner:coll/fhir:Practitioner
    let $hits1 := if ($org!='')
        then $hits/../fhir:Practitioner[fhir:organization/fhir:reference[@value=$org]]
        else $hits
    let $matched :=
        if (r-practitioner:isPLZ($city))
        then let $ps := $hits1/../fhir:Practitioner[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)][matches(address/postalCode/@value,concat('^',$city))]
            return
                $ps/../fhir:Practitioner[fhir:active[@value=$active]]
        else if ($city!='')
            then let $h0 := $hits1/../fhir:Practitioner[fhir:name/fhir:family[matches(@value,$name)]]
                let $ps := $h0/../fhir:Practitioner[matches(meta/tag/text/@value,$tag)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)][matches(address/city/@value,$city)]
                return
                    $ps/../fhir:Practitioner[fhir:active[@value=$active]]
            else let $h0 := $hits1/../fhir:Practitioner[fhir:name[fhir:family[starts-with(@value,$name)]]]
                 let $h1 := $h0/../fhir:Practitioner[matches(meta/tag/text/@value,$tag)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)]
                 return $h1/../fhir:Practitioner[fhir:active[@value=$active]]
 
    let $sorted-hits := for $c in $matched
        order by $c/fhir:name/fhir:family/@value collation "?lang=de-DE"
        return
            $c
    return
        r-practitioner:prepareResult($sorted-hits, $start, $length)
};

declare %private function r-practitioner:isPLZ($str as xs:string) as xs:boolean
{
    (: test if str can be cast to number :)
    string(number($str)) != 'NaN'
};

(:~
 : GET: /metis/practitioners
 : Search practitioners using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '15')
 : @param $name     family-name
 : @param $tag      tag
 : @param $city     city
 : @param $org      organization ref
 : @þaram $role     role code
 : @param $active   active
 : @return practitioners bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/practitioners")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "15")
    %rest:query-param("name",  "{$name}", "")
    %rest:query-param("city",  "{$city}",  "")
    %rest:query-param("org",   "{$org}",  "")
    %rest:query-param("role",  "{$role}",  "")
    %rest:query-param("specialty", "{$specialty}",  "")
    %rest:query-param("tag",   "{$tag}", "")
    %rest:query-param("active","{$active}",  "true")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-practitioner:practitionersJSON(
      $start as xs:string*, $length as xs:string*
    , $name as xs:string*
    , $city as xs:string*
    , $org as xs:string*
    , $role as xs:string*
    , $specialty as xs:string*
    , $tag as xs:string*
    , $active as xs:string*
    ) as item()
{
    let $oref := concat('metis/organizations/',$org)
    let $hits := if ($role!='')
        then $r-practitioner:coll/Practitioner[role/coding/code[@value=$role]][active[@value=$active]]
        else $r-practitioner:coll/Practitioner[active[@value=$active]]
    let $hits1 := if ($org!='')
        then $hits/../fhir:Practitioner[$oref=./organization/reference/@value]
        else $hits
    let $matched :=
        if (r-practitioner:isPLZ($city))
        then $hits1/../fhir:Practitioner[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)][matches(address/postalCode/@value,concat('^',$city))]
        else if ($city!='')
            then $hits1/../fhir:Practitioner[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)][matches(address/city/@value,$city)]
            else $hits1/../fhir:Practitioner[starts-with(name/family/@value,$name)][matches(meta/tag/text/@value,$tag)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)]
 
    return
    <json:array xmlns:json="http://www.json.org">
    {
        for $u in $matched
        let $uid := $u/fhir:id/@value/string()
        let $name := concat(
                  string-join($u/fhir:name[fhir:use/@value='official']/fhir:family/@value, ' ')
                , ', '
                , $u/fhir:name[fhir:use/@value='official']/fhir:given/@value)
        order by lower-case($name)
        return

        <json:value xmlns:json="http://www.json.org" json:array="true">
            <id>{$uid}</id>
            <text>{$name}</text>
        </json:value>
    }
    </json:array>
};

(:~
 : GET: /metis/practitioners2pdf
 : Search practitioners using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '15')
 : @param $name     family-name
 : @param $tag      tag
 : @param $city     city
 : @param $org      organization ref
 : @þaram $role     role code
 : @param $active   active
 : @return practitioners bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/practitioners2pdf")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "15")
    %rest:query-param("name",  "{$name}", "")
    %rest:query-param("city",  "{$city}",  "")
    %rest:query-param("org",   "{$org}",  "")
    %rest:query-param("role",  "{$role}",  "")
    %rest:query-param("specialty", "{$specialty}",  "")
    %rest:query-param("tag",   "{$tag}", "")
    %rest:query-param("active","{$active}",  "true")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-practitioner:practitioners2pdf(
        $start as xs:string*, $length as xs:string*,
        $name as xs:string*, $city as xs:string*,
        $org as xs:string*, $role as xs:string*, $specialty as xs:string*, $tag as xs:string*,
        $active as xs:string*)
{
(:~ 
 :  namespace interaction with util:eval.
 :  you can exec p2pdf as long as you will, but the next call an other routine fails with error
 :  namespace "config" not defined
 :)
    let $facets := 
        <facets xmlns="">
            <facet name="name"      method="matches" path="fhir:name/fhir:family/@value">{$name}</facet>
            <facet name="city"      method="matches" path="fhir:address/fhir:city/@value">{$city}</facet>
            <facet name="org"       method="equals"  path="fhir:organization/fhir:reference/@value">{$org}</facet>
            <facet name="role"      method="equals"  path="fhir:role/fhir:coding/fhir:code/@value">{$role}</facet>
            <facet name="specialty" method="equals"  path="fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value">{$specialty}</facet>
            <facet name="tag"       method="matches" path="fhir:meta/fhir:tag/fhir:text/@value">{$tag}</facet>
            <facet name="active"    method="equals"  path="fhir:active/@value">{$active}</facet>
        </facets>
(: 
    let $coll    := collection('/db/apps/metisData/data/FHIR/Practitioners')
    let $filter  := local:facet-filters($facets)
    let $matched := util:eval("$coll/*:Practitioner" || $filter)
    let $newest  := local:newest($coll, $matched)
    let $valid   := util:eval("$newest" || $filter)
:)
    let $hits := if ($role)
        then $r-practitioner:coll/Practitioner[role/coding/code[@value=$role]][active/@value=$active]
        else $r-practitioner:coll/Practitioner[active/@value=$active]
    let $hits1 := if ($org)
        then $hits[$org=./organization/reference/@value]
        else $hits
    let $matched :=
        if (r-practitioner:isPLZ($city))
        then $hits1[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)][matches(address/postalCode/@value,concat('^',$city))]
        else if ($city!='')
            then $hits1[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)][matches(address/city/@value,$city)]
            else $hits1[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(fhir:qualification/fhir:code/fhir:coding[fhir:system/@value='http://hl7.org/fhir/vs/practitioner-specialty']/fhir:code/@value,$specialty)]

    let $sorted-hits := for $c in $matched
        order by $c/name/family/@value collation "?lang=de-DE"
        return
            $c
let $result := teic:table2tei($sorted-hits, $facets)
let $fo  := tei2fo:report($result)

let $pdf := xslfo:render($fo, "application/pdf", ())
return
    (   <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="application/pdf"/>
                <http:header name="Content-Disposition" value="attachment;filename=practitioners.pdf"/>
            </http:response>
         </rest:response>
    , $pdf)
};

declare function local:facet-filters($facets as node()) as xs:string?
{
    string-join(
    (
        for $f in $facets/*:facet
        return
            if ($f and $f!='')
            then switch ($f/@method)
                    case 'matches' return concat("[matches(", $f/@path, ", '", $f, "')]")
                    case 'equals'  return concat("[", $f/@path, " = '", $f, "']")
                    default return ()
            else ()
    )
    ,'')
};
declare function local:newest($coll, $matched) as item()*
{
    let $ids     := distinct-values($matched/id/@value/string())
    let $newest := for $id in $ids
        let $prs := $coll/Practitioner[id/@value=$id]
        return
            if (count($prs)>1)
            then xxpath:highest(function($e){$e/fhir:meta/fhir:lastUpdated/@value/string()}, $prs)
            else $prs
    return
        $newest
};

declare function local:addNamespaceToXML($noNamespaceXML as element(*),$namespaceURI as xs:string) as element(*)
{
    element {fn:QName($namespaceURI,fn:local-name($noNamespaceXML))}
    {
         $noNamespaceXML/@*
        ,for $node in $noNamespaceXML/node()
            return
                if (exists($node/node()))
                then local:addNamespaceToXML($node,$namespaceURI)
                else if ($node instance of element()) 
                then element {fn:QName($namespaceURI,fn:local-name($node))}{$node/@*}
                else $node
    }
};

(:~
 : PUT: /metis/practitioners
 : Update an existing Practitioner or store a new one.
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/metis/practitioners")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:header-param("lognam", "{$lognam}", "anon")
    %rest:produces("application/xml", "text/xml")
function r-practitioner:putPractitionerXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    )
{
    let $content := if($content/fhir:Practitioner)
        then $content
        else let $lll := util:log-app('TRACE','apps.nabu',$content)
            return
            document { local:addNamespaceToXML($content/*:Practitioner,"http://hl7.org/fhir") }
    let $isNew := not($content/fhir:Practitioner/@xml:id)
    let $cid   := if ($isNew)
        then concat("c-", util:uuid())
        else
            let $id := $content/Practitioner/id/@value/string()
            let $order := $r-practitioner:coll/fhir:Practitioner[fhir:id[@value = $id]]
            let $move := r-practitioner:moveToHistory($order)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Practitioner/fhir:meta/fhir:versionId/@value/string()) + 1
    let $base := $content/fhir:Practitioner/fhir:*[not(
                                               self::meta
                                            or self::id
                                            )]
    let $meta := $content//fhir:meta/fhir:*[
                                               self::fhir:source
                                            or self::fhir:profile
                                            or self::fhir:tag
                                        ]
    let $uuid := if ($isNew) 
        then $cid
        else concat("c-", util:uuid())
    let $data := 
        <Practitioner xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <extension url="http://eNahar.org/nabu/url#lastUpdatedBy">
                    <reference value="{concat('metis/practitioners/',$loguid)}"/>
                    <display value="{$lognam}"/>
                </extension>
                <lastUpdated value="{current-dateTime()}"/>
            </meta>
            { $base }
        </Practitioner>
        
    let $file  := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:metis-practitioners, $file, $data)
            , sm:chmod(xs:anyURI($config:metis-practitioners || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:metis-practitioners || '/' || $file), $config:data-group)))
        return
            r-practitioner:rest-response(200, 'Practitioner sucessfully stored.') 
    } catch * {
        r-practitioner:rest-response(401, 'permission denied. Ask the admin.') 
    }
};
