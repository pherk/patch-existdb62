xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-obs = "http://enahar.org/exist/restxq/nabu/observations";

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

declare variable $r-obs:observations := "/db/apps/nabuCom/data/Observations";
declare variable $r-obs:coll       := collection($r-obs:observations);
declare variable $r-obs:history    := concat($config:history-data,'/Observations');
declare variable $r-obs:data-perms := "rwxrw-r--";
declare variable $r-obs:data-group := "spz";

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
declare function r-obs:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-obs:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-obs:history, $nameHistory)
                    )
        )
};

declare %private function r-obs:prepareResult($hits, $start, $length, $format)
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
        <observations xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </observations>
};


declare %private function r-obs:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/observations/{$id}
 : List observation with id.
 : 
 : @return  <Observation>...</Observation>
 :)
declare
    %rest:GET
    %rest:path("nabu/observations/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-obs:observationByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $observations := $r-obs:coll/fhir:Observation[fhir:id[@value = $id]]
    return
        if (count($observations)=1)
        then $observations
        else if (count($observations)>1)
        then r-obs:rest-response(404, concat('Observation with ID: ',$id, ' too many. Ask the Admin.'))
        else r-obs:rest-response(404, concat('Observation with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: nabu/observations/{$id}/compiled
 : List observation with id.
 : 
 : @return  <Observation>...</Observation>
 :)
declare
    %rest:GET
    %rest:path("nabu/observations/{$id}/compiled")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-obs:observationCompiledByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $observations := collection('/db/apps/nabuWorkflow/data/Observations')/fhir:Observation[fhir:id[@value = $id]]
    return
        if (count($observations)=1)
        then <data>{$observations}</data>
        else if (count($observations)>1)
        then r-obs:rest-response(404, concat('Observation with ID: ',$id, ' too many. Ask the Admin.'))
        else r-obs:rest-response(404, concat('QuestionanireResponse with ID: ',$id, ' not found. Ask the Admin.'))
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
declare function r-obs:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-obs:coll/fhir:Observation[fhir:id[@value=$id]]
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
 : GET: /nabu/observations/{$id}/_history
 : get observation history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  observation bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/observations/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-obs:observationHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-obs:coll | collection($r-obs:history)
    let $hits  := $coll/fhir:Observation[fhir:id[@value=$id]] 
    return
        r-obs:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/observation/{$id}/_history/{$vid}
 : get observation history with id $id and version $vid
 : 
 : @param $id observation id
 : @param $vid version id
 : 
 : @return  observation bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/observations/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-obs:observationVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-obs:coll | collection($r-obs:history)
    let $hits  := $coll/fhir:Observation[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-obs:prepareHistoryBundle($id, $hits)
};

declare %private function r-obs:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/observations/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/observations/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/observations/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
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
 : GET: nabu/observations?start=1&length=10&status=...
 : List observations for subject
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
 : @return  bundle <observations/>
 : 
 : @since v0.8
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/observations")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam",   "{$lognam}",  "")      
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "final")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-obs:observationsXML(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
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

    let $sref := "nabu/patients/" || $subject
    let $matched0 := 
        if ($subject="")
        then $r-obs:coll/fhir:Observation
        else $r-obs:coll/fhir:Observation[fhir:subject[fhir:reference/@value=$sref]]
    let $matched := if ($status="")
        then $matched0
        else $matched0[fhir:status[@value=$status]]
    return
        switch ($format)
        case 'count' return <observations><count>{count($matched)}</count></observations> 
        default return 
            r-obs:prepareResult($matched, '1', '*', $format)
    } catch * {
        r-obs:rest-response(404, concat('Observation: Invalid subject? : ', $subject))
    }
};

(:~
 : PUT: nabu/observations
 : Update an existing observation or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/observations")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-obs:putObservationXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew := not($content/fhir:Observation/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:Observation/fhir:id/@value/string()
            let $observations := $r-obs:coll/fhir:Observation[fhir:id[@value = $id]]
            let $move := r-obs:moveToHistory($observations)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Observation/meta/versionId/@value/string()) + 1
    let $base := $content/Observation/fhir:*[not(
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
        <Observation xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </Observation>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-obs:observations, $file, $data)
            , sm:chmod(xs:anyURI($r-obs:observations || '/' || $file), $r-obs:data-perms)
            , sm:chgrp(xs:anyURI($r-obs:observations || '/' || $file), $r-obs:data-group)))
        return
            r-obs:rest-response(200, 'Observation sucessfully stored.') 
    } catch * {
        r-obs:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

