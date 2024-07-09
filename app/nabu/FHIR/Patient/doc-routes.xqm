xquery version "3.0";
(:~
: Defines all the RestXQ endpoints used by the XForms.
: @author Peter Herkenrath
: @version 1.0
: @see http://enahar.org
:
:)
module namespace r-doc = "http://enahar.org/exist/restxq/nabu/documents";

import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";


declare %private function r-doc:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-doc:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <docs>
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </docs>
};

(:~
 : Composition Search parameter from FHIR 0.3 
 : Name	        Type	    Description	Paths
 : attester	    reference	Who attested the composition	            (Organization, Patient, Practitioner)
 : author	    reference	Who and/or what authored the composition	(Device, Patient, Practitioner, RelatedPerson)
 : class	    token	    Categorization of Composition	            
 : confidentiality	token	As defined by affinity domain
 : context  	token	    Code(s) that apply to the event being documented
 : date	        date	    Composition editing time
 : identifier	token	    Logical identifier of composition
 : patient     reference	Who and/or what the composition is about	(Patient)
 : period	    date	    The period covered by the documentation
 : section	    reference	The Content of the section
 : section-code	token	    Classification of section (recommended)
 : status	    token	    preliminary | final | appended | amended | entered in error
 : subject	    reference	Who and/or what the composition is about	(Device, Location, Patient, Practitioner, Group)
 : title	    string	    Human Readable name/title
 : type	        token	    Kind of composition (LOINC if possible)
 :)
(:~
 : GET: /nabu/documents/{$id}
 : get documents of with id $id
 : 
 : @param $id doc id
 : 
 : @return  <document>...</document>
 :)
declare
    %rest:GET
    %rest:path("/nabu/documents/{$id}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-doc:documentsByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $hits  := collection($config:nabu-patients)/document[id=$id] 
    let $hit := xxpath:highest(function($d){xs:integer($d/version)}, $hits)
    return
        $hit
};

(:~
 : GET: /nabu/documents/{$id}/_history
 : get document history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  doc bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/documents/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-doc:documentHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $hits  := collection($config:nabu-patients)/document[id=$id] 
    return
        r-doc:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/documents/{$id}/_history/{$vid}
 : get document history with id $id and version $vid
 : 
 : @param $id doc id
 : @param $vid version id
 : 
 : @return  doc bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/documents/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-doc:documentVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $hits  := collection($config:nabu-patients)/document[id=$id][version=$vid]
    return
        r-doc:prepareHistoryBundle($id, $hits)
};

declare %private function r-doc:prepareHistoryBundle($id, $entries)
{
    let $serverip := 'http://enahar.org'
    return
        <feed>
            <id></id>
            <version>0</version>
            <type value="history"/>
            <title/>
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/documents/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/nabu"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/version)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/nabu/documents/{$id}/_history/{$e/version/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/documents/{$id}/_history/{$e/version/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : GET: /nabu/patients/{$pid}/documents
 : get documents of patient with id $pid
 : 
 : @param $pid patient id
 : 
 : @return doc bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/patients/{$pid}/documents")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-doc:patDocumentsByID($pid as xs:string*,
        $start as xs:string*, $length as xs:string*)
{
    let $hits := collection($config:nabu-patients)/document[subject/ref/@value=$pid]
    let $ids   := distinct-values($hits/id/string())
    let $valid-hits := for $id in $ids
            return 
                xxpath:highest(function($d){xs:integer($d/version)}, $hits[id=$id])
    let $sorted-hits := $valid-hits
    return
        r-doc:prepareResult($sorted-hits, $start, $length)
};

(:~
 : Search patient docs using a given field and a (lucene) query string.
 : 
 : @param $start
 : @param $length
 : @param #$name
 : @param #$bday
 : @param #$pid
 : @param $patient-uuid
 : @param #$docRange
 : @param #$docID
 : @param $docClass
 : 
 : @return doc bundle
 : 
 : @stability provisional, #items not yet implemented
 :)
declare 
    %rest:GET
    %rest:path("/nabu/search-docs")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "15")
    %rest:query-param("name", "{$name}", "")
    %rest:query-param("bday", "{$bday}", "")
    %rest:query-param("pid",  "{$pid}",  "")
    %rest:query-param("patient-uuid",  "{$patient-uuid}", "")
    %rest:query-param("docRange",      "{$docRange}", "")
    %rest:query-param("docClass",      "{$docClass}", "")
    %rest:produces("application/xml", "text/xml")
function r-doc:search-docs($start as xs:string*, $length as xs:string*,
                $name as xs:string*, $bday as xs:string*, $pid as xs:string*,
                $patient-uuid as xs:string*,
                $docRange as xs:string*, $docClass as xs:string*) {
    
    let $hits := if($docClass="all")
        then collection($config:nabu-patients)/document[subject/ref/@value=$patient-uuid]
        else collection($config:nabu-patients)/document[subject/ref/@value=$patient-uuid][class=$docClass]
    let $ids   := distinct-values($hits/id/string())
    let $valid-hits := for $id in $ids
            return 
                xxpath:highest(function($d){xs:integer($d/version)}, $hits[id=$id])
    let $sorted-hits := $valid-hits
    return
        r-doc:prepareResult($sorted-hits, $start, $length)
};



(:~
 : PUT: /nabu/patients/{$pid}/documents
 : Update an existing document of a patient or store a new one.
 : 
 : @param $content request body (xml)
 : @param $uuid patient id
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/nabu/patients/{$pid}/documents")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:header-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-doc:create-or-edit-document(
          $content as document-node()*
        , $pid as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        )
{
    let $d  := $content/document
    let $isNew   := not($d/@xml:id)

    let $did   := if ($isNew)
        then  concat("d-", util:uuid())
        else  $d/@xml:id/string()
    let $version := if ($isNew) 
        then "0"
        else xs:integer($d/version/string()) + 1
    let $uuid := if ($isNew)
        then $did
        else concat("d-", util:uuid())
    
    let $format   := if ($d/class=('pheno')) (: document formats saved as xml not as encoded html :)
        then 'text/xml'
        else 'text/html'
    let $editable := if ($d/class='pheno')
        then 'true'
        else 'false'

    let $data := <document xml:id="{$uuid}">
            <id>{$did}"</id>
            <version>{$version}</version>
            <lastModifiedBy>
                <ref value="{$loguid}"/>
                <display text=""/>
            </lastModifiedBy>    
            <lastModified value="{current-dateTime()}"/>
            {$d/class}
            {$d/status}
            {$d/subject}
            {$d/title}
            <format>{$format}</format>
            <fileName/>
            <fileSize/>
            {$d/author}
            {$d/resource}
            <editable>{$editable}</editable>
            <save>false</save>
        </document>

    let $lll := util:log-system-out($data)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('admin', '', (
            xmldb:store($config:nabu-patients || '/documents/', $file, $data)
            , sm:chmod(xs:anyURI($config:nabu-patients || '/documents/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:nabu-patients || '/documents/' || $file), $config:data-group)))
        return
            r-doc:rest-response(200, 'doc sucessfully stored.') 
    } catch * {
        r-doc:rest-response(401, 'permission denied. Ask the admin.') 
    }
};


