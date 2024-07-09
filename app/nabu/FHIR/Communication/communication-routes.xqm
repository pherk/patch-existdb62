xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-comm = "http://enahar.org/exist/restxq/nabu/communications";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";


declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-comm:base := '/db/apps/nabuCommunication/data';

declare variable $r-comm:history := concat($config:history-data,'/Communications');

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
declare function r-comm:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-comm:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-comm:history, $nameHistory)
                    )
        )
};

declare %private function r-comm:prepareResult($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <communications xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            {   
                if (count($hits) > 0)
                then
                    let $sorted-hits := for $c in $hits
                        order by $c/fhir:sent/@value descending
                        return
                            $c
                    let $data := subsequence($sorted-hits, $start, $len1)
                    return
                        switch ($format)
                        case 'metadata' return
                                for $d in $data
                                return
                                    <doc>
                                        {$d/*:id}
                                        <label value="{tokenize($d/*:sent/@value,'T')[1]}"/>
                                        <note value="{$d/*:note/@value/string()}"/>
                                    </doc>
                        default return $data 
                else
                    ()
            }
        </communications>
};


declare %private function r-comm:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(: 
 : select (sub-) collections for efficiency
 : 
 :)
declare %private function r-comm:collections(
      $tmin as xs:string
    , $tmax as xs:string
    , $base as xs:string
    ) as xs:string*
{
    let $openrange := $tmin='' and $tmax=''
    let $years := if ($openrange)
        then $base
        else
            let $ymin := if ($tmin!='')
                then let $y := xs:int(substring($tmin,1,4))
                    return max(($y,2004))
                else 2004
            let $ymax := if ($tmax!='')
                then let $y := xs:int(substring($tmax,1,4))
                    return min(($y,2026))
                else 2026
            let $inc := 0
            for $y in ($ymin to ($ymax+$inc))
            return
                concat($base,'/',$y)
    let $lll := util:log-app('TRACE','apps.nabu',string-join(($tmin,$tmax,$openrange,$years),':'))
    return
        $years
};
declare function r-comm:targetColl(
      $start as xs:string
    , $base as xs:string
    ) as xs:string
{
    let $year   := substring($start,1,4)
    return
        if (xs:integer($year)>2003 and xs:integer($year)<2026)
        then
            concat($base,'/',$year)
        else '/db/apps/nabuCommunication/data/invalid'
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
 : GET: nabu/communications/{$id}
 : List communication with id.
 : 
 : @return  <Communication>...</Communication>
 :)
declare
    %rest:GET
    %rest:path("nabu/communications/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-comm:communicationByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $coms := collection($r-comm:base)/fhir:Communication[fhir:id[@value = $id]]
    return
        if (count($coms)=1)
        then $coms
        else if (count($coms)>1)
        then r-comm:rest-response(403, concat('Communication with ID: ',$id, ' too many. Ask the Admin.'))
        else r-comm:rest-response(404, concat('Communication with ID: ',$id, ' not found. Ask the Admin.'))
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
declare function r-comm:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := collection($r-comm:base)/fhir:Communication[fhir:id[@value=$id]]
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
 : GET: nabu/communications/{$id}/payload
 : List communication with id.
 : 
 : @return  <Communication>...</Communication>
 :)
declare
    %rest:GET
    %rest:path("nabu/communications/{$id}/payload")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:produces("application/xml", "text/xml")
function r-comm:communicationPayloadByID($id as xs:string*, $realm as xs:string*, $loguid as xs:string*) as item()
{
    let $com := collection($r-comm:base)/fhir:Communication[fhir:id[@value=$id]]
    return
        if (count($com)=1)
        then $com/fhir:payload/fhir:contentTEI/tei:body
        else if (count($com)>1)
        then r-comm:rest-response(403, concat('Communication with ID: ',$id, ' too many. Ask the Admin.'))
        else r-comm:rest-response(404, concat('Communication with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /nabu/communications/{$id}/_history
 : get communication history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  communication bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/communications/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-comm:communicationHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := collection($r-comm:base) | collection($r-comm:history)
    let $hits  := $coll/fhir:Communication[fhir:id[@value=$id]]
    return
        r-comm:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/communication/{$id}/_history/{$vid}
 : get communication history with id $id and version $vid
 : 
 : @param $id communication id
 : @param $vid version id
 : 
 : @return  communication bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/communications/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-comm:communicationVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := collection($r-comm:base) | collection($r-comm:history)
    let $hits  := $coll/fhir:Communication[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-comm:prepareHistoryBundle($id, $hits)
};

declare %private function r-comm:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/communications/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/nabu"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/fhir:meta/fhir:versionId/@value)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/nabu/communications/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}</id>
                        <updated>{$e/fhir:lastModified/@value/string()}</updated>
                        <published>{$e/fhir:lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/communications/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.0.1
 : category	token	Message category	Communication.category
 : encounter	reference	Encounter leading to message	Communication.encounter
 : identifier	token	Unique identifier	Communication.identifier
 : medium	token	A channel of communication	Communication.medium
 : patient	reference	Focus of message	Communication.subject
 : received	date	When received	Communication.received
 : recipient	reference	Message recipient	Communication.recipient
   (Practitioner, Group, Organization, Device, Patient, RelatedPerson)
 : request	reference	CommunicationRequest producing this message	Communication.requestDetail
 : sender	reference	Message sender	Communication.sender
   (Practitioner, Organization, Device, Patient, RelatedPerson)
 : sent	date	When sent	Communication.sent
 : status	token	in-progress | completed | suspended | rejected | failed	Communication.status
 : subject	reference	Focus of message	Communication.subject
 :)

(:~
 : GET: nabu/communications?start=1&length=10&status=...
 : List communications for subject
 : 
 : @param   $start
 : @param   $length
 : @param   $sender        ref
 : @param   $rangeStart    dateTime
 : @param   $rangeEnd      dateTime
 : @param   $subject       ref
 : @param   $status        ('in-progress', 'completed', 'suspended', 'rejected', 'failed')
 : @param   $format        ('full', 'wrapper', 'payload', 'count')
 : 
 : @return  bundle <communications/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/communications")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("sender",  "{$sender}", "")
    %rest:query-param("rangeStart", "{$rangeStart}")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "in-progress")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-comm:communicationsXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $sender as xs:string*
        , $rangeStart as xs:string*
        , $rangeEnd as xs:string*
        , $subject as xs:string*
        , $status as xs:string*
        , $format as xs:string*
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
    let $aref := "metis/practitioners/" || $sender[1]
    let $sref := "nabu/patients/" || $subject[1]
    let $matched0 := 
        if ($sender="" and $subject="")
        then collection($r-comm:base)/fhir:Communication[fhir:status[@value=$status]]
        else if ($sender="")
        then collection($r-comm:base)/fhir:Communication[fhir:subject[fhir:reference/@value=$sref]][fhir:status[@value=$status]]
        else if ($subject="")
        then collection($r-comm:base)/fhir:Communication[fhir:sender[fhir:reference/@value=$aref]][fhir:status[@value=$status]]
        else collection($r-comm:base)/fhir:Communication[fhir:subject[fhir:reference/@value=$sref]][fhir:sender[fhir:reference[@value=$aref]]][fhir:status[@value=$status]]
    let $matched := if ($rangeStart and $rangeEnd)
        then
            let $tmin := xs:dateTime($rangeStart)
            let $tmax := xs:dateTime($rangeEnd)
            return
                $matched0/../fhir:Communication[fhir:sent[@value>$tmin]][fhir:sent[@value<$tmax]]
        else
            $matched0
    return
        switch ($format)
        case 'count' return 
                <communications>
                    <count>{count($matched)}</count>
                </communications> 
        case 'metadata' return r-comm:prepareResult($matched, $start, $length, $format)
        default return 
            r-comm:prepareResult($matched, $start, $length, $format)
    } catch * {
        r-comm:rest-response(404, concat('Invalid args? : ', $sender[1], '-', $subject[1]))
    }
};

(:~
 : GET: nabu/communicationsBySubject/{$id}
 : List communications for subject
 : 
 : @param   $id
 : 
 : @return  bundle <communications/>
 : 
 : @since v0.7
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/communicationsBySubject/{$subject}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("status", "{$status}", "")
    %rest:produces("application/xml", "text/xml")
function r-comm:communicationBySubject(
          $subject as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $status as xs:string*
        ) as item()
{
    try{
    let $sref := "nabu/patients/" || $subject
    let $matched := if ($status="")
        then collection($r-comm:base)/fhir:Communication[fhir:subject[fhir:reference/@value=$sref]]
        else collection($r-comm:base)/fhir:Communication[fhir:subject[fhir:reference/@value=$sref]][fhir:status[@value=$status]]
    let $sorted-hits := for $e in $matched
            order by $e/fhir:sent/@value collation "?lang=de-DE"
            return
                $e
    return
        r-comm:prepareResult($sorted-hits, '1', '*','metadata')
    } catch * {
        r-comm:rest-response(404, concat('Invalid subject? : ', $subject))
    }
};


(:~
 : PUT: nabu/communications
 : Update an existing communication or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/communications")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-comm:putCommunicationXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
let $lll := util:log-app('TRACE','apps.nabu',$content/fhir:Communication/@xml:id)
    let $isNew := not($content/fhir:Communication/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:Communication/fhir:id/@value/string()
            let $comms := collection($r-comm:base)/fhir:Communication[fhir:id[@value = $id]]
            let $move := r-comm:moveToHistory($comms)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Communication/fhir:meta/fhir:versionId/@value/string()) + 1
    let $base := $content/fhir:Communication/fhir:*[not(
                                               self::meta
                                            or self::id
                                            or self::lastModified
                                            or self::lastModifiedBy
                                            )]
    let $meta := $content//meta/fhir:*[not(self::versionId)]
    let $uuid := if ($isNew) 
        then $eid
        else concat("c-", util:uuid())
    let $data := 
        <Communication xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </Communication>
        
(:    let $lll := util:log-app('TRACE','apps.nabu',$data) :)

    let $file := $uuid || ".xml"
    let $target := r-comm:targetColl($data/fhir:sent/@value,$r-comm:base)
    let $lll := util:log-app('TRACE','apps.nabu',$target)
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($target, $file, $data)
            , sm:chmod(xs:anyURI($target || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($target || '/' || $file), $config:data-group)))
        return
            r-comm:rest-response(200, 'communication sucessfully stored.') 
    } catch * {
        r-comm:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

(:~
 : GET: /nabu/communications2pdf
 : Search leaves using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $end      (default: '*')
 : @param $name     family-name
 : @param $type
 : @return leaves as pdf
 :)
declare 
    %rest:GET
    %rest:path("/nabu/communications2pdf")
    %rest:query-param("realm",   "{$realm}", "spz-admin")
    %rest:query-param("loguid",  "{$loguid}" , "exportBot")
    %rest:query-param("start",    "{$start}",  "1")      
    %rest:query-param("length",   "{$length}", "*")      
    %rest:query-param("rangeStart", "{$rangeStart}", "")    
    %rest:query-param("rangeEnd", "{$rangeEnd}",   "")
    %rest:query-param("id",       "{$id}",   "")
    %rest:query-param("subject",  "{$subject}", "")
    %rest:query-param("status",   "{$status}", "")
    %rest:query-param("printed",  "{$printed}", "false")
    %rest:produces("application/xml", "text/xml")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-comm:comms2PDF(
          $realm as xs:string*,   $loguid as xs:string*
        , $start as xs:string*,   $length as xs:string*
        , $rangeStart as xs:string*, $rangeEnd as xs:string*
        , $id as xs:string*
        , $subject as xs:string*
        , $status as xs:string*
        , $printed as xs:string*
        )
{
    let $nl := "&#10;"
    let $tmin := if ($rangeStart)
        then xs:dateTime($rangeStart)
        else current-dateTime()
    let $tmax := if ($rangeEnd)
        then xs:dateTime($rangeEnd)
        else current-dateTime() + xs:dayTimeDuration('P1D') 
    let $sref := "nabu/patients/" || $subject
    let $matched := if ($id!='')
        then collection($r-comm:base)/Communication[fhir:id[@value=$id]]
        else if ($subject='')
            then collection($r-comm:base)/fhir:Communication[fhir:status[@value=$status]][fhir:sent/@value>$tmin][fhir:sent/@value<$tmax]
            else collection($r-comm:base)/fhir:Communication[fhir:subject[fhir:reference/@value=$sref]][fhir:status[@value=$status]][fhir:sent/@value>$tmin][fhir:sent/@value<$tmax]

    let $sorted-hits := for $e in $matched
            order by $e/fhir:sent/@value/string() collation "?lang=de-DE"
            return
                $e
    let $lll := util:log-app('TRACE','apps.nabu',count($sorted-hits))
    let $printdate := adjust-dateTime-to-timezone(current-dateTime(),())
    let $fo  := tei2fo:letter($sorted-hits//fhir:contentTEI/tei:body, true())
    return
        if (count($fo/fo:page-sequence) > 0)
        then 
            let $pdf := xslfo:render($fo, "application/pdf", ())
            let $status := 
                if ($printed="true")
                then
                    for $e in $matched
                    return
                        try {
                            system:as-user('vdba', 'kikl823!',
                                (
                                  update value $e/fhir:status/@value with 'printed'
                                , update insert 
                                    <extension xmlns="http://hl7.org/fhir" url="#print-date">
                                        <valueDateTime value="{$printdate}"/>
                                    </extension>
                                    following 
                                        $e/fhir:sent
                                ))
                        } catch * {
                            let $err := util:log-app('ERROR','apps.nabu', 'permission denied')
                            return
                                r-comm:rest-response(401, 'permission denied. Ask the admin.') 
                        }
                else ()
            return
            (   <rest:response>
                    <http:response status="200">
                        <http:header name="Content-Type" value="application/pdf"/>
                        <http:header
                            name="Content-Disposition" 
                            value="{concat('attachment;filename=br', adjust-dateTime-to-timezone(current-dateTime(),()),'.pdf')}"/>
                    </http:response>
                </rest:response>
            , $pdf)
        else
            r-comm:rest-response(404, 'call empty') 
};
