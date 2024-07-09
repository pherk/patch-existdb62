xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-qr = "http://enahar.org/exist/restxq/nabu/questionnaireresponses";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace xf="http://www.w3.org/2002/xforms";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-qr:questionnaireresponses := "/db/apps/nabuCom/data/QuestionnaireResponses";
declare variable $r-qr:coll       := collection($r-qr:questionnaireresponses);
declare variable $r-qr:history    := concat($config:history-data,'/QuestionnaireResponses');
declare variable $r-qr:data-perms := "rwxrw-r--";
declare variable $r-qr:data-group := "spz";

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
declare function r-qr:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-qr:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-qr:history, $nameHistory)
                    )
        )
};

declare %private function r-qr:prepareResult($hits, $start, $length, $format)
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
        <questionnaireresponses xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </questionnaireresponses>
};


declare %private function r-qr:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/questionnaireresponses/{$id}
 : List questionnaireResponse with id.
 : 
 : @return  <QuestionnaireResponse>...</QuestionnaireResponse>
 :)
declare
    %rest:GET
    %rest:path("nabu/questionnaireresponses/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-qr:questionnaireResponseByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $questionnaireresponses := $r-qr:coll/fhir:QuestionnaireResponse[fhir:id[@value = $id]]
    return
        if (count($questionnaireresponses)=1)
        then $questionnaireresponses
        else if (count($questionnaireresponses)>1)
        then r-qr:rest-response(404, concat('QuestionnaireResponse with ID: ',$id, ' too many. Ask the Admin.'))
        else r-qr:rest-response(404, concat('QuestionnaireResponse with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: nabu/questionnaireresponses/{$id}/compiled
 : List questionnaireResponse with id.
 : 
 : @return  <QuestionnaireResponse>...</QuestionnaireResponse>
 :)
declare
    %rest:GET
    %rest:path("nabu/questionnaireresponses/{$id}/compiled")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-qr:questionnaireResponseCompiledByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $questionnaireresponses := collection('/db/apps/nabuWorkflow/data/QuestionnaireResponses')/fhir:QuestionnaireResponse[fhir:id[@value = $id]]
    return
        if (count($questionnaireresponses)=1)
        then <data>{$questionnaireresponses}</data>
        else if (count($questionnaireresponses)>1)
        then r-qr:rest-response(404, concat('QuestionnaireResponse with ID: ',$id, ' too many. Ask the Admin.'))
        else r-qr:rest-response(404, concat('QuestionnaireResponse with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: nabu/questionnaireresponses/{$id}/xform
 : List questionnaireResponse with id.
 : 
 : @return  <QuestionnaireResponse>...</QuestionnaireResponse>
 :)
declare
    %rest:GET
    %rest:path("nabu/questionnaireresponses/{$id}/xform")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-qr:questionnaireResponseXFormByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $qr-xform := collection('/db/apps/nabu/FHIR/QuestionnaireResponse')/*[.//xf:model/@id=$id]
    return
        if (count($qr-xform)=1)
        then $qr-xform
        else if (count($qr-xform)>1)
        then r-qr:rest-response(404, concat('QR-XForm with ID: ',$id, ' too many. Ask the Admin.'))
        else r-qr:rest-response(404, concat('QR-XForm with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $pid
 : @param $pnam
 : 
 : @return 
 :)
declare function r-qr:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-qr:coll/fhir:QuestionnaireResponse[fhir:id[@value=$id]]
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
 : GET: /nabu/questionnaireresponses/{$id}/_history
 : get questionnaireResponse history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  questionnaireResponse bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/questionnaireresponses/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-qr:questionnaireResponseHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-qr:coll | collection($r-qr:history)
    let $hits  := $coll/fhir:QuestionnaireResponse[fhir:id[@value=$id]] 
    return
        r-qr:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/questionnaireResponse/{$id}/_history/{$vid}
 : get questionnaireResponse history with id $id and version $vid
 : 
 : @param $id questionnaireResponse id
 : @param $vid version id
 : 
 : @return  questionnaireResponse bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/questionnaireresponses/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-qr:questionnaireResponseVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-qr:coll | collection($r-qr:history)
    let $hits  := $coll/fhir:QuestionnaireResponse[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-qr:prepareHistoryBundle($id, $hits)
};

declare %private function r-qr:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/questionnaireresponses/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/questionnaireresponses/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/questionnaireresponses/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 :)

(:~
 : GET: nabu/questionnaireresponses?start=1&length=10&status=...
 : List questionnaireresponses for subject
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
 : @return  bundle <questionnaireresponses/>
 : 
 : @since v0.8
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/questionnaireresponses")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam",   "{$lognam}",  "")      
    %rest:query-param("qid",     "{$qid}", "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "in-progress")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-qr:questionnaireResponsesXML(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $qid as xs:string*
        ,   $subject as xs:string*
        ,   $status as xs:string*
        ,   $format as xs:string*
        ) as item()
{
    let $qref := "nabu/questionnaires/" || $qid
    let $sref := "nabu/patients/" || $subject

    let $matched0 := 
        if ($qid="" and $subject="")
        then $r-qr:coll/fhir:QuestionnaireResponse
        else if ($qid="")
        then $r-qr:coll/fhir:QuestionnaireResponse[fhir:subject[fhir:reference[@value=$sref]]]
        else if ($subject="")
        then $r-qr:coll/fhir:QuestionnaireResponse[fhir:questionnaire[fhir:reference[@value=$qref]]]
        else 
            $r-qr:coll/fhir:QuestionnaireResponse[fhir:subject[fhir:reference[@value=$sref]]][fhir:questionnaire[fhir:reference[@value=$qref]]]
    let $lll := util:log-app('TRACE','apps.nabu',$matched0/fhir:status/@value/string())
    let $matched := if ($status="")
        then $matched0
        else $matched0[fhir:status[@value!='entered-in-error']]
    return
        switch ($format)
        case 'count' return <questionnaireresponses><count>{count($matched)}</count></questionnaireresponses> 
        default return 
            r-qr:prepareResult($matched, '1', '*', $format)
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
 : PUT: nabu/questionnaireresponses
 : Update an existing questionnaireResponse or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/questionnaireresponses")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-qr:putQuestionnaireResponseXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $lll := util:log-app('TRACE','apps.nabu',$content) 
    let $content := if($content/fhir:QuestionnaireResponse)
        then $content
        else document { local:addNamespaceToXML($content/*:QuestionnaireResponse,"http://hl7.org/fhir") }
    let $isNew := not($content/fhir:QuestionnaireResponse/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:QuestionnaireResponse/fhir:id/@value/string()
            let $questionnaireresponses := $r-qr:coll/fhir:QuestionnaireResponse[fhir:id[@value = $id]]
            let $move := r-qr:moveToHistory($questionnaireresponses)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/QuestionnaireResponse/meta/versionId/@value/string()) + 1
    let $base := $content/QuestionnaireResponse/fhir:*[not(
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
        <QuestionnaireResponse xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </QuestionnaireResponse>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-qr:questionnaireresponses, $file, $data)
            , sm:chmod(xs:anyURI($r-qr:questionnaireresponses || '/' || $file), $r-qr:data-perms)
            , sm:chgrp(xs:anyURI($r-qr:questionnaireresponses || '/' || $file), $r-qr:data-group)))
        return
            r-qr:rest-response(200, 'QuestionnaireResponse sucessfully stored.') 
    } catch * {
        r-qr:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

