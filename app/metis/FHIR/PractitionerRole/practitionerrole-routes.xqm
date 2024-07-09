xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 : should be FHIR 4.0.1 compatible
 : - returning bundles
 : - naming of Resource: big, without plural
 : 
 : Version 1.0
 :)
module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
import module namespace ical   = "http://enahar.org/lib/ical";

import module namespace config ="http://enahar.org/exist/apps/metis/config"  at "../../modules/config.xqm";
import module namespace date   = "http://enahar.org/exist/apps/metis/date"   at "../../modules/date.xqm";
import module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize" at "/db/apps/nabu/FHIR/meta/serialize-fhir-resources.xqm";

import module namespace r-group = "http://enahar.org/exist/restxq/metis/groups"  at "../Group/group-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "../Practitioner/practitioner-routes.xqm";


declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare namespace fo     ="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  ="http://exist-db.org/xquery/xslfo";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-practrole:metisdata := '/db/apps/metisData/data';
declare variable $r-practrole:metishist := '/db/apps/metisHistory/data';
declare variable $r-practrole:metis-pr := '/db/apps/metisData/data/FHIR/PractitionerRoles';
declare variable $r-practrole:coll := collection($r-practrole:metis-pr);
declare variable $r-practrole:practRoleHistory := $r-practrole:metishist || '/PractitionerRole';

 
(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare %private function r-practrole:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-practrole:practRoleHistory)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-practrole:practRoleHistory, $nameHistory)
                    )
        )
};

declare %private function r-practrole:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-practrole:prepareResultBundleXML($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:text/fhir:div/@value/string() descending
            return
                $c
    return
        <Bundle xmlns="http://hl7.org/fhir">
            <id value="bundle-example"/> 
            <meta> 
                <lastUpdated value="2014-08-18T01:43:30Z"/>
            </meta>  
            <type value="searchset"/>   
            <total value="{$count}"/> 
            <link> 
                <relation value="self"/> 
                <url value="https://example.com/base/PractitionerRole"/> 
            </link> 
            <link> 
                <relation value="next"/> 
                <url value="https://example.com/base/PractitionerRole?page=2"/> 
            </link> 
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            {
                for $r in subsequence($sorted-hits, $start, $len1) 
                return
                    <entry>
                        <fullUrl value=""/>
                        <resource>
                            {$r}
                        </resource>
                        <search>
                            <mode value="match"/>
                            <score value="1"/>
                        </search>
                    </entry>
            }
        </Bundle>
};

declare %private function r-practrole:prepareResultBundleJSON($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:text/*:div/@value/string() descending
            return
                $c
    return
        serialize:resource2json(
        <Bundle xmlns="http://hl7.org/fhir">
            <id value="bundle-example"/> 
            <meta> 
                <lastUpdated value="2014-08-18T01:43:30Z"/>
            </meta>  
            <type value="searchset"/>   
            <total value="3"/> 
            <link> 
                <relation value="self"/> 
                <url value="https://example.com/base/PractitionerRole?patient=347&amp;_include=MedicationRequest.medication"/> 
            </link> 
            <link> 
                <relation value="next"/> 
                <url value="https://example.com/base/PractitionerRole?patient=347&amp;searchId=ff15fd40-ff71-4b48-b366-09c706bed9d0&amp;page=2"/> 
            </link> 
            {
                for $r in subsequence($sorted-hits, $start, $len1)
                return
                    <entry>
                        <fullUrl value="{concat('http://localhost:8080/exist/restxq/metis/PractitionerRole/',$r/fhir:id/@value)}"/>
                        <resource>
                            {$r}
                        </resource>
                        <search>
                            <mode value="match"/>
                            <score value="1"/>
                        </search>
                    </entry>
            }
        </Bundle>
        , false()
        , "4.3"
        )
};

(:~
 : GET: /metis/PractitionerRole/{$id}
 : Retrieve an Practitioner identified by id.
 : 
 : @param $id
 : @return <PractitionerRole/>
 :)
declare 
    %rest:GET
    %rest:path("/metis/PractitionerRole/{$id}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/xml", "text/xml")
function r-practrole:practRoleByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $active as xs:string*
    )
{
    let $prs := $r-practrole:coll/fhir:PractitionerRole[fhir:id[@value = $id]]
    return
        if (count($prs)=1)
        then if ($prs/../fhir:PractitionerRole[fhir:active[@value=$active]])
            then $prs
            else r-practrole:rest-response(404, concat('PractitionerRole with ID: ',$id, ' found, but active != ', $active))
        else r-practrole:rest-response(404, concat('PractitionerRole with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /metis/PractitionerRole/{$id}/_history
 : get practitionerrole history with id $id
 : 
 : @param $id  practitionerrole id
 : 
 : @return  practitioner bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/PractitionerRole/{$id}/_history")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/xml", "text/xml")
function r-practrole:practRoleHistoryByID(
        $id as xs:string*,
        $realm as xs:string*, $loguid as xs:string*,
        $start as xs:string*, $length as xs:string*,
        $active as xs:string*)
{
    let $hits  := $r-practrole:coll/fhir:PractitionerRole[fhir:id[@value=$id]][fhir:active[@value=$active]]
    return
        r-practrole:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /metis/PractionerRole/{$id}/_history/{$vid}
 : get practitioner history with id $id and version $vid
 : 
 : @param $id PractitionerRole id
 : @param $vid version id
 : 
 : @return  PractitionerRole bundle
 :)
declare
    %rest:GET
    %rest:path("/metis/PractitionerRole/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-practrole:practRoleVersionByID(
        $id as xs:string*, $vid as xs:string*,
        $start as xs:string*, $length as xs:string*)
{
    let $hits  := $r-practrole:coll/fhir:PractitionerRole[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-practrole:prepareHistoryBundle($id, $hits)
};

declare %private function r-practrole:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/metis/PractitionerRole/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/metis"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/meta/versionId)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/metis/PractitionerRole/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/metis/PractitionerRole/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : GET: /metis/PractitionerRole/{$id}
 : Retrieve an PractitionerRole identified by id
 : 
 : @param $id
 : @return <PractitionerRole/>
 :)
declare 
    %rest:GET
    %rest:path("/metis/PractitionerRole/{$id}/alias")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("system","{$system}", "http://eNahar.org/nabu/system#metis-account")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/xml", "text/xml")
function r-practrole:practRoleByIdentifier(
        $id as xs:string*
        , $realm as xs:string*, $loguid as xs:string*
        , $system as xs:string*
        , $active as xs:string*)
{
    let $prs := $r-practrole:coll/fhir:PractitionerRole[fhir:identifier[fhir:value/@value = $id]]
    return
        if (count($prs) > 0)
        then if ($prs/../fhir:PractitionerRole[fhir:active[@value=$active]])
            then $prs/../fhir:PractitionerRole[fhir:active[@value=$active]]
            else r-practrole:rest-response(404, concat('PractitionerRole with ID: ',$id, ' found, but active != ', $active))
        else r-practrole:rest-response(404, concat('PractitionerRole with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /metis/PractitionerRole
 : Search PractitionerRoles using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $length   (default: '15')
 : @param $name     family-name
 : @param $tag      tag
 : @param $city     city
 : @param $org      organization ref
 : @þaram $role     role code
 : @param $active   active
 : @return PractitionerRole bundle
 :)
declare 
    %rest:GET
    %rest:path("/metis/PractitionerRole")
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
function r-practrole:practRoles(
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
        then $r-practrole:coll/fhir:PractitionerRole[fhir:code/fhir:coding/fhir:code[@value=$role]]
        else $r-practrole:coll/fhir:PractitionerRole
let $lll := util:log-app('TRACE','apps.nabu',count($hits))
    let $hits1 := if ($org!='')
        then $hits/../fhir:PractitionerRole[fhir:organization/fhir:reference[@value=$org]]
        else $hits
    let $hits2 := if ($name!='')
        then $hits1/../fhir:PractitionerRole[fhir:practitioner/fhir:display[starts-with(@value,$name)]]
        else $hits1
    let $matched := $hits2/../fhir:PractitionerRole[fhir:active[@value=$active]]
let $lll := util:log-app('TRACE','apps.nabu',count($matched))
    let $sorted-hits := for $c in $matched
        order by $c/fhir:practitioner/fhir:display/@value collation "?lang=de-DE"
        return
            $c
    return
        r-practrole:prepareResultBundleXML($sorted-hits, $start, $length)
};

declare %private function r-practrole:isPLZ($str as xs:string) as xs:boolean
{
    (: test if str can be cast to number :)
    string(number($str)) != 'NaN'
};

(:~
 : GET: /metis/PractitionerRole
 : Search PractitionerRoles using a given field and a (lucene) query string.
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
    %rest:path("/metis/PractitionerRole")
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
function r-practrole:practRolesJSON(
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
        then $r-practrole:coll/fhir:PractitionerRole[fhir:code/fhir:coding/fhir:code[@value=$role]][fhir:active[@value=$active]]
        else $r-practrole:coll/fhir:PractitionerRole[fhir:active[@value=$active]]
let $lll := util:log-app('TRACE','apps.nabu',count($hits))
    let $hits1 := if ($org!='')
        then $hits/../fhir:PractitionerRole[$oref=./fhir:organization/fhir:reference/@value]
        else $hits
    let $matched := $hits1/../fhir:PractitionerRole[matches(fhir:practitioner/fhir:display/@value,$name)][matches(fhir:specialty/fhir:coding/fhir:code/@value,$specialty)]
 
    return
    <json:array xmlns:json="http://www.json.org">
    {
        for $u in $matched
        let $prid := $u/fhir:id/@value/string()
        let $uref := $u/fhir:practitioner/fhir:reference/@value/string()
        let $uid  := substring-after($uref,'metis/practitioners/')
        let $name := $u/fhir:practitioner/fhir:display/@value/string()
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
 : GET: /metis/PractitionerRole2pdf
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
 : @return pdf
 :)
declare 
    %rest:GET
    %rest:path("/metis/PractitionerRole2pdf")
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
function r-practrole:practRoles2pdf(
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
            <facet name="role"      method="equals"  path="fhir:code/fhir:coding/fhir:code/@value">{$role}</facet>
            <facet name="specialty" method="equals"  path="fhir:specialty/fhir:coding/fhir:code/@value">{$specialty}</facet>
            <facet name="tag"       method="matches" path="fhir:meta/fhir:tag/fhir:text/@value">{$tag}</facet>
            <facet name="active"    method="equals"  path="fhir:active/@value">{$active}</facet>
        </facets>

    let $hits := if ($role)
        then $r-practrole:coll/fhir:PractitionerRole[role/coding/code[@value=$role]][active/@value=$active]
        else $r-practrole:coll/fhir:PractitionerRole[active/@value=$active]
    let $hits1 := if ($org)
        then $hits[$org=./organization/reference/@value]
        else $hits
    let $matched :=
        if (r-practrole:isPLZ($city))
        then $hits1[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(specialty/coding/code/@value,$specialty)][matches(address/postalCode/@value,concat('^',$city))]
        else if ($city!='')
            then $hits1[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(specialty/coding/code/@value,$specialty)][matches(address/city/@value,$city)]
            else $hits1[matches(meta/tag/text/@value,$tag)][matches(name/family/@value,$name)][matches(specialty/coding/code/@value,$specialty)]

    let $sorted-hits := for $c in $matched
        order by $c/name/family/@value collation "?lang=de-DE"
        return
            $c
let $result := teic:table2tei($sorted-hits, $facets)
let $fo  := tei2fo:report($result)
let $today := current-dateTime()
let $pdf := xslfo:render($fo, "application/pdf", ())
return
    (   <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="application/pdf"/>
                <http:header name="Content-Disposition" value="attachment;filename=practitionerroles-{$today}.pdf"/>
            </http:response>
         </rest:response>
    , $pdf)
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
 : PUT: /metis/PractitionerRole
 : Update an existing PractitionerRole or store a new one.
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/metis/PractitionerRole")
    %rest:query-param("realm", "{$realm}", "kikl-spz")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:produces("application/xml", "text/xml")
function r-practrole:putPractitionerRoleXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    )
{
    let $content := if($content/fhir:PractitionerRole)
        then $content
        else let $lll := util:log-app('TRACE','apps.nabu',$content)
            return
            document { local:addNamespaceToXML($content/*:PractitionerRole,"http://hl7.org/fhir") }
    let $lll := util:log-app('TRACE','apps.nabu',$content//fhir:practitioner)
    let $isNew := not($content//@xml:id)
    let $lll := util:log-app('TRACE','apps.nabu',$content//fhir:practitioner)
    let $cid   := if ($isNew)
        then concat("c-", util:uuid())
        else
            let $id := $content//fhir:id/@value/string()
            let $order := $r-practrole:coll/fhir:PractitionerRole[fhir:id[@value = $id]]
            let $move := r-practrole:moveToHistory($order)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content//fhir:meta/fhir:versionId/@value/string()) + 1
    let $lll := util:log-app('TRACE','apps.nabu',$content//fhir:practitioner)
    let $base := $content/fhir:PractitionerRole/fhir:*[not(
                                               self::meta
                                            or self::id
                                            )]
    let $lll := util:log-app('TRACE','apps.nabu',$content//fhir:practitioner)
    let $meta := $content//fhir:meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $lll := util:log-app('TRACE','apps.nabu',$content//fhir:practitioner)
(: 
 : let $lll := util:log-app('TRACE','apps.nabu',$content/fhir:PractitionerRole)
 : :)
    let $uuid := if ($isNew) 
        then $cid
        else concat("c-", util:uuid())
    let $data := 
        <PractitionerRole xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                    <reference value="metis/practitioners/{$loguid}"/>
                    <display value="{$lognam}"/>
                </extension>
            </meta>
            { $base }
        </PractitionerRole>
(: 
    let $lll := util:log-app('TRACE','apps.nabu',$data)        
:)
    let $file  := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-practrole:metis-pr, $file, $data)
            , sm:chmod(xs:anyURI($r-practrole:metis-pr || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($r-practrole:metis-pr || '/' || $file), $config:data-group)))
        return
            (
            r-practrole:rest-response(200, 'PractitionerRole sucessfully stored.') 
            , $data
            )
    } catch * {
        r-practrole:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

(:~
 : GET: /metis/PractitionerRole/{$uid}/perms
 : @uid user id
 : @return <permissions xml:id="{$uid}"><perm>...</perm></permissions>
 :)
declare 
    %rest:GET
    %rest:path("metis/PractitionerRole/{$uid}/perms")
    %rest:produces("application/xml")
function r-practrole:perms($uid as xs:string*)
{
    if ($uid!='')
    then 
        let $groups:= r-group:roles("1","*","","","")
        let $user  := r-practrole:practRoleByID($uid, 'kikl-spz', $uid, '', 'true')

        let $roles := distinct-values($user//fhir:code/fhir:coding/fhir:code/@value)

        let $ups   := for $g in $groups/fhir:Group[fhir:code/fhir:text/@value=$roles]
                return
                    $g/fhir:characteristics[fhir:code/fhir:coding/fhir:system/@value="#metis-permission"][fhir:valueBoolean/@value]/fhir:code/fhir:coding/fhir:code/@value
        return
            <permissions xml:id="{$uid}">
                <perm>basic</perm>
                {
                    for $p in distinct-values($ups)
                    return
                        <perm>{$p}</perm>
                }
            </permissions>
    else <permissions><perm>basic</perm></permissions>
};
        (:  :)

(:~
 : GET: /metis/PractitionerRole/{$uid}/group
 : 
 : @uid user id
 : @return xs:string*
 : 
 : TODO move to Group
 :)
declare
    %rest:GET
    %rest:path("metis/PractitionerRole/{$uid}/group")
    %rest:produces("application/xml", "text/xml")
function r-practrole:group($uid as xs:string*)
{
    let $u := r-practrole:practRoleByID($uid, 'kikl-spz', 'u-admin', 'admin', 'true')
    return
        if ($u)
        then $u/fhir:code[1]/fhir:coding/fhir:code/@value/string()
        else r-practrole:rest-response(404, 'user not found. Ask the admin.')
};

(:~
 : GET: /metis/roles/{$uid}/roles
 : maps group as role into roles
 : @uid user id
 : @return <roles/>
 :)
declare
    %rest:GET
    %rest:path("metis/PractitionerRole/{$uid}/roles")
    %rest:query-param("realm", "{$realm}", "kikl-spz")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:produces("application/xml", "text/xml")
function r-practrole:rolesByID(
      $uid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()*
{
    let $user := r-practrole:practRoleByID($uid, $realm, $loguid, $lognam,'true')
    return
        if ($user/fhir:id)
        then 
            let $rs := distinct-values($user/fhir:code/fhir:coding/fhir:code/@value)
            let $auth := $realm = $rs
            return
                if ($auth)
                then
                    <roles>{
                        for $r in $rs
                        return
                            <role>{$r}</role>
                    }</roles>
                else
                    r-practrole:rest-response(404, 'user not in realm. Ask the admin.')
        else r-practrole:rest-response(404, 'user not found. Ask the admin.')
};

(:~
 : GET: /metis/PractitionerRole/{$uid}
 : 
 : @param $uid user id
 : @return <user/>
 : 
 : @deprecated soon TODO use practRoles instead
 :)
declare 
    %rest:GET
    %rest:path("metis/PractitionerRole/{$uid}")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-practrole:userByID(
    $uid as xs:string*
    , $format as xs:string*) as item()
{
    let $lll := util:log-app('TRACE','apps.nabu',$uid)
    let $uref := concat('metis/practitioners/',$uid)
    let $u := $r-practrole:coll/fhir:PractitionerRole[fhir:practitioner[fhir:reference[@value = $uref]]][fhir:active[@value='true']]
    return
        if (count($u/fhir:id)=1)
        then
            switch($format)
            case 'ref'  return
                <practitioners xmlns="">
                    <count>1</count>
                    <start>1</start>
                    <length>1</length>
                    <user xmlns="http://hl7.org/fhir">
                        <reference value="{$u/fhir:practitioner/fhir:reference/@value/string()}"/>
                        <display value="{$u/fhir:practitioner/fhir:display/@value/string()}"/>
                    </user>
                </practitioners>
            default return $u
        else
            let $lll := util:log-app('ERROR','apps.nabu',$u)
            return
                ()
};

(:~
 : GET: /metis/PractitionerRole/{$alias}/alias
 : Search user using identifier alias
 : 
 : @param $alias
 : @return <user/>
 :  
 : @deprecated soon TODO use practitioner instead
 :)
declare 
    %rest:GET
    %rest:path("metis/PractitionerRole/{$alias}/alias")
    %rest:produces("application/xml", "text/xml")
function r-practrole:userByAlias($alias as xs:string*) as item()
{
    r-practrole:practRoleByIdentifier($alias, 'kikl-spz', 'u-admin', "http://eNahar.org/nabu/system#metis-account", 'true')
};

(: 
 : JSON functions as Javascript rest end points
:)


(:~
 : GET: /metis/PractitionerRole
 : Search user using family name and/or org field
 : 
 : @param $start  ( 1)
 : @param $length (10)
 : @param $family ()
 : @param $role   ()
 : @param $org    ()
 : @return  bundle practitioner
 :)
declare 
    %rest:GET
    %rest:path("metis/PractitionerRole/users")
    %rest:query-param("name",   "{$family}",   "")
    %rest:query-param("role",   "{$role}",   "kikl-spz")
    %rest:query-param("org",    "{$org}",   "")
    %rest:query-param("_format","{$format}" , "full")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-practrole:users(
    $family as xs:string*,
    $role as xs:string*,
    $org as xs:string*,
    $format as xs:string*) as item()
{
    let $bundle := r-practrole:practRoles("1","*",$family, '', $org, $role,'','','true')
    return
           <practitioners xmlns="">
                <count>{$bundle/fhir:count/@value/string()}</count>
                <start>{$bundle/fhir:start/@value/string()}</start>
                <length>{$bundle/fhir:length/@value/string()}</length>
            {
                for $u in $bundle/fhir:entry/fhir:resource/fhir:PractitionerRole
                return
                switch($format)
                case 'ref'  return
                        <user xmlns="http://hl7.org/fhir">
                            <reference value="{$u/fhir:practitioner/fhir:reference/@value/string()}"/>
                            <display value="{$u/fhir:practitioner/fhir:display/@value/string()}"/>
                        </user>
                case 'compact'  return
                        <user xmlns="http://hl7.org/fhir">
                            <reference value="{$u/fhir:practitioner/fhir:reference/@value/string()}"/>
                            <display value="{$u/fhir:practitioner/fhir:display/@value/string()}"/>
                            <roles value="{string-join($u/fhir:code/fhir:coding/fhir:code/@value,' ')}"/>
                            <realm value="{$role}"/>
                        </user>
                default return $u
            }
            </practitioners>
};


(:~
 : GET: /metis/PractitionerRole/birthdates
 : Search user using family name and/or org field
 : 
 : @param $start  ( 1)
 : @param $length (10)
 : @param $family ()
 : @param $org    ()
 : @return  birthdays as PDF
 :)
declare 
    %rest:GET
    %rest:path("metis/Practitioner2birthdates")
    %rest:query-param("start",  "{$start}",  "1")      
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("name",   "{$family}",   "")
    %rest:query-param("org",    "{$org}",   "")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-practrole:userBirthDates($start as xs:string*, $length as xs:string*, 
    $family as xs:string*, $org as xs:string*)
{
    let $facets := 
        <facets xmlns="">
            <facet name="name"      method="matches" path="fhir:name/fhir:family/@value"></facet>
            <facet name="birthdate" method="matches" path="fhir:birthDate/@value"></facet>
        </facets>
    let $users := r-practrole:users($family, '', $org, 'true')
    let $ps    := ()
    let $data := for $u in $ps/fhir:Practitioner[fhir:birthDate/@value!='']
                order by substring($u/fhir:birthDate/@value,6)
                return $u
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header("Geburtstagsliste") }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                    <table rows="{count($data)}" cols="4:4:1"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <head>Geburtstagsliste</head>
                    {
                        for $m in (1 to 12)
                        for $r at $i in $data[$m = xs:integer(tokenize(fhir:birthDate/@value,'-')[2])]
                        let $toks := tokenize($r/fhir:birthDate/@value,'-')
                        return
                            if ($m=1 and $toks[3]='01') (: do not show 01.01.xxxx :)
                            then ()
                            else <row role="data">
                                    <cell role="label">{if ($i=1) then $ical:infos/*:monat[@value=$m]/@label/string() else ''}</cell>
                                    <cell role="data">{concat($r/fhir:name/fhir:family/@value,', ', $r/fhir:name/fhir:given/@value)}</cell>
                                    <cell role="data">{concat($toks[3],'.',$toks[2])}</cell>
                                </row>
                    }
                    </table>
                </div>
            </body>
        </text>
    </TEI>
    let $fo  := tei2fo:report($result)

    let $pdf := xslfo:render($fo, "application/pdf", ())
    return
    (   <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="application/pdf"/>
                <http:header name="Content-Disposition" value="attachment;filename=birthdates.pdf"/>
            </http:response>
         </rest:response>
    , $pdf)

};



(:~
 : PUT: /metis/PractitionerRole/{$uid}/passwd
 : Update an existing password.
 : 
 : @param $uid
 : @return
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/metis/PractitionerRole/{$uid}/passwd")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:header-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-practrole:changePasswdXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $uid as xs:string*
    )
{
    let $lll := util:log-app('TRACE','apps.nabu',$content)
    let $opw  := $content//oldPassword
    let $npw  := $content//newPassword
    let $cpw  := $content//confirmPassword
    let $isAuth := if ($uid = $loguid)
        then 'basic' = r-practrole:perms($uid)/perm
        else 'perm_updateAccount' = r-practrole:perms($loguid)/perm
    return
        if ($isAuth and r-practrole:isValidPW($opw,$npw,$cpw))
        then try {
            let $userAlias := r-practrole:practRoleByID($uid, 'kikl-spz', 'u-admin','admin','true')/fhir:identifier[fhir:system/@value="http://eNahar.org/nabu/system#metis-account"]/fhir:value/@value/string()
            let $logAlias  := r-practrole:practRoleByID($loguid, 'kikl-spz', 'u-admin','admin','true')/fhir:identifier[fhir:system/@value="http://eNahar.org/nabu/system#metis-account"]/fhir:value/@value/string()
            let $sys       := system:as-user('admin', 'kikl968', sm:passwd($userAlias, $npw))
            return
                r-practrole:rest-response(200, 'password successfully stored.')
        } catch * {
                r-practrole:rest-response(401, 'unexpected error. Ask the admin.') 
        }
        else    r-practrole:rest-response(401, 'invalid password or permission denied. Ask the admin.') 
};

declare %private function r-practrole:isValidPW($opw as xs:string, $npw as xs:string, $cpw as xs:string) as xs:boolean
{
    ($opw!='' and $npw!='' and $cpw!='' and $opw!=$npw and $npw=$cpw)
};
