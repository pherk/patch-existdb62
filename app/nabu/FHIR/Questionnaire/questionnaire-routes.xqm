xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-questionnaire = "http://enahar.org/exist/restxq/nabu/questionnaires";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
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

declare variable $r-questionnaire:questionnaires := "/db/apps/nabuWorkflow/data/Questionnaires";
declare variable $r-questionnaire:coll       := collection($r-questionnaire:questionnaires);
declare variable $r-questionnaire:history    := concat($config:history-data,'/Questionnaires');
declare variable $r-questionnaire:data-perms := "rwxrw-r--";
declare variable $r-questionnaire:data-group := "spz";

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
declare function r-questionnaire:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-questionnaire:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-questionnaire:history, $nameHistory)
                    )
        )
};

declare %private function r-questionnaire:prepareResult($hits, $start, $length, $format)
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
        <questionnaires xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </questionnaires>
};


declare %private function r-questionnaire:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/questionnaire/{$id}
 : List questionnaire with id.
 : 
 : @return  <Questionnaire>...</Questionnaire>
 :)
declare
    %rest:GET
    %rest:path("nabu/questionnaires/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-questionnaire:questionnaireByIDXML(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $questionnaires := collection($r-questionnaire:questionnaires)/fhir:Questionnaire[fhir:id[@value = $id]]
    return
        if (count($questionnaires)=1)
        then $questionnaires
        else if (count($questionnaires)>1)
        then r-questionnaire:rest-response(404, concat('Questionnaire with ID: ',$id, ' too many. Ask the Admin.'))
        else r-questionnaire:rest-response(404, concat('Questionnaire with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: nabu/questionnaires/{$id}/compiled
 : List questionnaire with id.
 : 
 : @return  <Questionnaire>...</Questionnaire>
 :)
declare
    %rest:GET
    %rest:path("nabu/questionnaires/{$id}/compiled")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-questionnaire:questionnaireCompiledByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $questionnaires := collection($r-questionnaire:questionnaires)/fhir:Questionnaire[fhir:id[@value = $id]]
    return
        if (count($questionnaires)=1)
        then $questionnaires
        else if (count($questionnaires)>1)
        then r-questionnaire:rest-response(404, concat('QuestionnaireResponse with ID: ',$id, ' too many. Ask the Admin.'))
        else r-questionnaire:rest-response(404, concat('QuestionnaireResponse with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : update subject
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $pid
 : @param $pnam
 : 
 : @return 
 :)
declare function r-questionnaire:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-questionnaire:coll/fhir:Questionnaire[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:subject/fhir:reference/@value with concat('nabu/patients/', $pid)
                , update value $res/fhir:subject/fhir:display/@value with $pnam
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
        else ()
};


(:~
 : GET: /nabu/questionnaires/{$id}/_history
 : get questionnaireResponse history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  questionnaireResponse bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/questionnaires/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-questionnaire:questionnaireHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-questionnaire:coll | collection($r-questionnaire:history)
    let $hits  := $coll/fhir:Questionnaire[fhir:id[@value=$id]] 
    return
        r-questionnaire:prepareHistoryBundle($id, $hits)
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
    %rest:path("/nabu/questionnaires/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-questionnaire:questionnaireVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-questionnaire:coll | collection($r-questionnaire:history)
    let $hits  := $coll/fhir:Questionnaire[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-questionnaire:prepareHistoryBundle($id, $hits)
};

declare %private function r-questionnaire:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/questionnaires/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/questionnaires/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/questionnaires/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
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
 : GET: nabu/questionnaires?start=1&length=10&status=...
 : List questionnaires for subject
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
 : @return  bundle <questionnaires/>
 : 
 : @since v0.8
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/questionnaires")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam",   "{$lognam}",  "")      
    %rest:query-param("author",  "{$author}", "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "in-progress")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-questionnaire:questionnairesXML(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $author as xs:string*
        ,   $subject as xs:string*
        ,   $status as xs:string*
        ,   $format as xs:string*
        ) as item()
{
    let $aref := "metis/practitioners/" || $author
    let $sref := "nabu/patients/" || $subject
    let $matched := 
        if ($author="" and $subject="")
        then $r-questionnaire:coll/fhir:Questionnaire[fhir:status[@value=$status]]
        else if ($author="")
        then $r-questionnaire:coll/fhir:Questionnaire[fhir:subject[fhir:reference/@value=$sref]][fhir:status[@value=$status]]
        else if ($subject="")
        then $r-questionnaire:coll/fhir:Questionnaire[fhir:author[fhir:reference/@value=$aref]][fhir:status[@value=$status]]
        else $r-questionnaire:coll/fhir:Questionnaire[fhir:subject[fhir:reference/@value=$sref]][fhir:author[fhir:reference[@value=$aref]]][fhir:status[@value=$status]]

    return
        switch ($format)
        case 'count' return <questionnaires><count>{count($matched)}</count></questionnaires> 
        default return 
            r-questionnaire:prepareResult($matched, '1', '*', $format)
};

(:~
 : PUT: nabu/questionnaires
 : Update an existing questionnaireResponse or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/questionnaires")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-questionnaire:putQuestionnaireXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew := not($content/fhir:Questionnaire/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:Questionnaire/fhir:id/@value/string()
            let $questionnaires := $r-questionnaire:coll/fhir:Questionnaire[fhir:id[@value = $id]]
            let $move := r-questionnaire:moveToHistory($questionnaires)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Questionnaire/meta/versionId/@value/string()) + 1
    let $base := $content/fhir:Questionnaire/fhir:*[not(
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
        <Questionnaire xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </Questionnaire>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-questionnaire:nabu-questionnaires, $file, $data)
            , sm:chmod(xs:anyURI($r-questionnaire:nabu-questionnaires || '/' || $file), $r-questionnaire:data-perms)
            , sm:chgrp(xs:anyURI($r-questionnaire:nabu-questionnaires || '/' || $file), $r-questionnaire:data-group)))
        return
            r-questionnaire:rest-response(200, 'questionnaire sucessfully stored.') 
    } catch * {
        r-questionnaire:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

