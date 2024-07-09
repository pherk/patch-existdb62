xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-protocol = "http://enahar.org/exist/restxq/nabu/protocols";

import module namespace config = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-protocol:nabu-protocols := "/db/apps/nabuWorkflow/data/Protocols";
declare variable $r-protocol:coll          := collection($r-protocol:nabu-protocols);
declare variable $r-protocol:history       := concat($config:history-data,'/Protocols');
declare variable $r-protocol:data-perms    := "rwxrw-r--";
declare variable $r-protocol:data-group    := "spz";

(:~
 : 
 : HTTP RESPONSE CODES USED
 : 
 : 200 - Operation Success
 : 420 - Operation Failed
 : 400 - Bad Request Syntax
 : 410 - Resource Not Available
 : 405 - restXQ operation call error
 : 500 - Internal Server Error
 : 
 : Response header contains a 'mf-message' field where the value has meaning in context.
 : 
 :)

(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare function r-protocol:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-protocol:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-protocol:history, $nameHistory)
                    )
        )
};

declare %private function r-protocol:prepareResult($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/sent collation "?lang=de-DE"
            return
                $c
    return
        <protocols xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </protocols>
};


declare %private function r-protocol:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
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

(:~
 : GET: nabu/protocols/{$id}
 : List protocol with id.
 : 
 : @return  <Protocol>...</Protocol>
 :)
declare
    %rest:GET
    %rest:path("nabu/protocols/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-protocol:protocolByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $protocols := $r-protocol:coll/Protocol[id/@value=$id]
    return
        if (count($protocols)=1)
        then $protocols
        else if (count($protocols)>1)
        then r-protocol:rest-response(404, concat('Protocol with ID: ',$id, ' too many. Ask the Admin.'))
        else r-protocol:rest-response(404, concat('Protocol with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : update subject of communication
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $pid
 : @param $pnam
 : 
 : @return 
 :)
declare function r-protocol:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-protocol:coll/Protocol[id/@value=$id]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:subject/fhir:reference/@value with concat('nabu/patients/',$pid)
                , update value $res/fhir:subject/fhir:display/@value with $pnam
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
        else ()
};


(:~
 : GET: /nabu/protocols/{$id}/_history
 : get protocol history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  protocol bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/protocols/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-protocol:protocolHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-protocol | collection($r-protocol:history)
    let $hits  := $coll/Protocol[id/@value=$id] 
    return
        r-protocol:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/protocol/{$id}/_history/{$vid}
 : get protocol history with id $id and version $vid
 : 
 : @param $id protocol id
 : @param $vid version id
 : 
 : @return  protocol bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/protocols/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-protocol:protocolVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-protocol | collection($r-protocol:history)
    let $hits  := $coll/Protocol[id/@value=$id][meta/versionId/@value=$vid]
    return
        r-protocol:prepareHistoryBundle($id, $hits)
};

declare %private function r-protocol:prepareHistoryBundle($id, $entries)
{
    let $serverip := 'http://enahar.org'
    return
        <feed>
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <type value="history"/>
            <title value=""/>
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/protocols/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/nabu"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/meta/versionId/@value)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/nabu/protocols/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/protocols/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.0.1
 : category	token	Message category	Protocol.category
 : encounter	reference	Encounter leading to message	Protocol.encounter
 : identifier	token	Unique identifier	Protocol.identifier
 : medium	token	A channel of protocol	Protocol.medium
 : patient	reference	Focus of message	Protocol.subject
 : received	date	When received	Protocol.received
 : recipient	reference	Message recipient	Protocol.recipient
   (Practitioner, Group, Organization, Device, Patient, RelatedPerson)
 : request	reference	ProtocolRequest producing this message	Protocol.requestDetail
 : sender	reference	Message sender	Protocol.sender
   (Practitioner, Organization, Device, Patient, RelatedPerson)
 : sent	date	When sent	Protocol.sent
 : status	token	in-progress | completed | suspended | rejected | failed	Protocol.status
 : subject	reference	Focus of message	Protocol.subject
 :)

(:~
 : GET: nabu/protocols?start=1&length=10&status=...
 : List protocols for subject
 : 
 : @param   $start
 : @param   $length
 : @param   $sender        ref
 : @param   $rangeStart    dateTime
 : @param   $rangeEnd      dateTime
 : @param   $subject       ref
 : @param   $status        ('in-progress', 'enroll', 'ready', 'printed', 'cancelled')
 : @param   $format        ('full', 'wrapper', 'payload', 'count')
 : 
 : @return  bundle <protocols/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/protocols")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("sender",  "{$sender}")
    %rest:query-param("rangeStart", "{$rangeStart}")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "in-progress")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-protocol:protocols(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $start as xs:string*
        ,   $length as xs:string*
        ,   $sender as xs:string*
        ,   $rangeStart as xs:string*
        ,   $rangeEnd as xs:string*
        ,   $subject as xs:string*
        ,   $status as xs:string*
        ,   $format as xs:string*
        ) as item()
{
    try{
(:~ 
 :  namespace interaction with util:eval.
 :  you can exec as long as you will, but the next call an other routine fails with error
 :  namespace "config" not defined

    let $facets := 
        <facets xmlns="">
            <facet name="sender"  method="equals" path="fhir:sender/fhir:reference/@value">{$sender}</facet>
            <facet name="sender"  method="equals" path="fhir:sender/fhir:reference/@value">{$name}</facet>
            <facet name="sender"  method="equals" path="fhir:sender/fhir:reference/@value">{$name}</facet>
            <facet name="sender"  method="equals" path="fhir:sender/fhir:reference/@value">{$name}</facet>
            <facet name="sender"  method="equals" path="fhir:sender/fhir:reference/@value">{$name}</facet>
        </facets>

    let $coll    := collection('/db/apps/metisData/data/FHIR/Practitioners')
    let $filter  := local:facet-filters($facets)
    let $matched := util:eval("$coll/*:Practitioner" || $filter)
:)
    let $aref := "metis/practitioners/" || $sender
    let $sref := "nabu/patients/" || $subject
    let $matched := 
        if ($sender="" and $subject="")
        then $r-protocol:coll/Protocol[status/@value=$status]
        else if ($sender="")
        then $r-protocol:coll/Protocol[sender/reference/@value=$aref][status/@value=$status]
        else if ($subject="")
        then $r-protocol:coll/Protocol[subject/reference/@value=$sref][status/@value=$status]
        else $r-protocol:coll/Protocol[subject/reference/@value=$sref][sender/reference/@value=$aref][status/@value=$status]

    return
        switch ($format)
        case 'count' return <protocols><count>{count($matched)}</count></protocols> 
        default return 
            r-protocol:prepareResult($matched, $start, $length, $format)
    } catch * {
        r-protocol:rest-response(404, concat('Invalid time filter? : ', $rangeStart, '-', $rangeEnd))
    }
};

(:~
 : PUT: nabu/protocols
 : Update an existing protocol or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/protocols")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-protocol:putProtocolXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew := not($content/fhir:Protocol/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/Protocol/id/@value/string()
            let $protocols := $r-protocol:coll/fhir:Protocol[fhir:id/@value = $id]
            let $move := r-protocol:moveToHistory($protocols)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Protocol/meta/versionId/@value/string()) + 1
    let $base := $content/Protocol/fhir:*[not(
                                               self::id
                                            or self::meta
                                            )]
    let $meta := $content//meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $uuid := if ($isNew) 
        then $eid
        else concat("c-", util:uuid())
    let $data := 
        <Protocol xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$eid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
            </meta>
            {$base}
        </Protocol>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-protocol:nabu-protocols, $file, $data)
            , sm:chmod(xs:anyURI($r-protocol:nabu-protocols || '/' || $file), $r-protocol:data-perms)
            , sm:chgrp(xs:anyURI($r-protocol:nabu-protocols || '/' || $file), $r-protocol:data-group)))
        return
            r-protocol:rest-response(200, 'protocol sucessfully stored.') 
    } catch * {
        r-protocol:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

