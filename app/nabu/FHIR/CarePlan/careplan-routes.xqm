xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-careplan = "http://enahar.org/exist/restxq/nabu/careplans";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";

declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-careplan:nabu-careplans := "/db/apps/nabuCom/data/CarePlans";
declare variable $r-careplan:coll          := collection($r-careplan:nabu-careplans);
declare variable $r-careplan:history       := concat($config:history-data,'/CarePlans');
declare variable $r-careplan:data-perms    := "rwxrw-r--";
declare variable $r-careplan:data-group    := "spz";
declare variable $r-careplan:valid-cp-status  := ('draft','active','suspended','completed','cancelled','entered-in-error','unknown');
declare variable $r-careplan:valid-detail-status  := ('not-started','scheduled','in-progress','completed','cancelled','on-hold','unknown');

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
 : @param $careplan
 : @return ()
 :)
declare function r-careplan:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-careplan:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-careplan:history, $nameHistory)
                    )
        )
};

declare %private function r-careplan:prepareResult($hits, $start, $length, $format)
{

    let $sorted-hits := for $c in $hits/../fhir:CarePlan[fhir:status[@value!='entered-in-error']]
            order by $c/fhir:period/fhir:start/@value/string() collation "?lang=de-DE"
            return
                $c
    let $count := count($sorted-hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <careplans xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </careplans>
};


declare %private function r-careplan:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/careplans/{$id}
 : List careplan with id.
 : 
 : @return  <CarePlan>...</CarePlan>
 :)
declare
    %rest:GET
    %rest:path("nabu/careplans/{$pid}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-careplan:careplanByID(
          $pid as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $careplans := $r-careplan:coll/fhir:CarePlan[fhir:id[@value = $pid]]
    return
        if (count($careplans)=1)
        then $careplans
        else if (count($careplans)>1)
        then r-careplan:rest-response(404, concat('CarePlan with ID: ',$pid, ' too many. Ask the Admin.'))
        else r-careplan:rest-response(404, concat('CarePlan with ID: ',$pid, ' not found. Ask the Admin.'))
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
declare function r-careplan:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-careplan:coll/fhir:CarePlan[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:subject/fhir:reference/@value with concat('nabu/patients/',$pid)
                , update value $res/fhir:subject/fhir:display/@value with $pnam
                , update value $res/fhir:lastModifiedBy/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:lastModifiedBy/fhir:display/@value with $lognam
                , update value $res/fhir:lastModified/@value with current-dateTime()
                ))
        else ()
};


(:~
 : GET: /nabu/careplans/{$id}/_history
 : get careplan history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  careplan bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/careplans/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-careplan:careplanHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-careplan:coll | collection($r-careplan:history)
    let $hits  := $coll/CarePlan[id/@value=$id] 
    return
        r-careplan:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/careplan/{$id}/_history/{$vid}
 : get careplan history with id $id and version $vid
 : 
 : @param $id careplan id
 : @param $vid version id
 : 
 : @return  careplan bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/careplans/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-careplan:careplanVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-careplan:coll | collection($r-careplan:history)
    let $hits  := $coll/fhir:CarePlan[fhir:id[@value=$id]][meta/versionId/@value=$vid]
    return
        r-careplan:prepareHistoryBundle($id, $hits)
};

declare %private function r-careplan:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/careplans/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/careplans/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/careplans/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.0.1
 : category	token	Message category	CarePlan.category
 : encounter	reference	Encounter leading to message	CarePlan.encounter
 : identifier	token	Unique identifier	CarePlan.identifier
 : medium	token	A channel of careplan	CarePlan.medium
 : patient	reference	Focus of message	CarePlan.subject
 : received	date	When received	CarePlan.received
 : recipient	reference	Message recipient	CarePlan.recipient
   (Practitioner, Group, Organization, Device, Patient, RelatedPerson)
 : request	reference	CarePlanRequest producing this message	CarePlan.requestDetail
 : sender	reference	Message sender	CarePlan.sender
   (Practitioner, Organization, Device, Patient, RelatedPerson)
 : sent	date	When sent	CarePlan.sent
 : status	token	in-progress | completed | suspended | rejected | failed	CarePlan.status
 : subject	reference	Focus of message	CarePlan.subject
 :)

(:~
 : GET: nabu/careplans?start=1&length=10&status=...
 : List careplans for subject
 : 
 : @param   $start
 : @param   $length
 : @param   $author        ref
 : @param   $subject       ref
 : @param   $status        ('active')
 : @param   $format        ('full', 'count')
 : 
 : @return  bundle <careplans/>
 : 
 : @since v0.8
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/careplans")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam",   "{$lognam}",  "")      
    %rest:query-param("author",  "{$author}", "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-careplan:careplansXML(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $author as xs:string*
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
    let $ll := util:log-app('TRACE','apps.nabu',count($r-careplan:coll/fhir:CarePlan))

    let $aref := "metis/practitioners/" || $author
    let $sref := "nabu/patients/" || $subject
    let $matched0 := 
        if ($author="" and $subject="")
        then $r-careplan:coll/fhir:CarePlan
        else if ($author="")
        then $r-careplan:coll/fhir:CarePlan[fhir:subject[fhir:reference/@value=$sref]]
        else if ($subject="")
        then $r-careplan:coll/fhir:CarePlan[fhir:author[fhir:reference/@value=$aref]]
        else $r-careplan:coll/fhir:CarePlan[fhir:subject[fhir:reference/@value=$sref]][fhir:author[fhir:reference/@value=$aref]]
    let $ll := util:log-app('TRACE','apps.nabu',concat($subject,': ',count($matched0)))
    let $matched := if ($status="")
        then $matched0
        else $matched0[fhir:status[@value=$status]]
    return
        switch ($format)
        case 'count' return <careplans><count>{count($matched)}</count></careplans> 
        default return 
            r-careplan:prepareResult($matched, '1', '*', $format)
    } catch * {
        r-careplan:rest-response(401, concat('CarePlan: Invalid subject? : ', $subject))
    }
};

(:~
 : POST: nabu/careplans/{$cid}
 :
 : 
 : @return <response>
 :)
declare
    %rest:POST
    %rest:path("nabu/careplans/{$cid}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("status", "{$status}","")
    %rest:produces("application/xml", "text/xml")
function r-careplan:updateCarePlanStatus(
      $cid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $status as xs:string*
    ) as item()
{
    let $cp := $r-careplan:coll/fhir:CarePlan[fhir:id[@value = $cid]]
    let $lll := util:log-app('TRACE','apps.nabu',concat('status: ',$cp/fhir:status/@value, '->', $status))
    return
    try {
        if (count($cp)=1)
        then if (r-careplan:isValidCarePlanStatus($status))
            then    
                let $up := system:as-user('vdba', 'kikl823!',
                (
                  update value $cp/fhir:status/@value with $status
                ))
                return
                r-careplan:rest-response(200, 'careplan status updated.')
            else
                r-careplan:rest-response(200, 'careplan status not valid/relevant.')
        else
            r-careplan:rest-response(404, 'careplan status not updated.') 
    } catch * {
        r-careplan:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-careplan:isValidCarePlanStatus($status as xs:string) as xs:boolean
{
    $status = $r-careplan:valid-cp-status
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
 : PUT: nabu/careplans
 : Update an existing careplan or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/careplans")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-careplan:putCarePlanXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    let $content := if($content/fhir:CarePlan)
        then $content
        else document { local:addNamespaceToXML($content/*:CarePlan,"http://hl7.org/fhir") }
    let $isNew := not($content/fhir:CarePlan/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/CarePlan/id/@value/string()
            let $careplans := $r-careplan:coll/fhir:CarePlan[fhir:id[@value = $id]]
            let $move := r-careplan:moveToHistory($careplans)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/CarePlan/meta/versionId/@value/string()) + 1
    let $base := $content/CarePlan/fhir:*[not(
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
        <CarePlan xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$eid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
            </meta>
            <lastModifiedBy>
                <reference value="{concat('metis/practitioners/',$loguid)}"/>
                <display value="{$lognam}"/>
            </lastModifiedBy>    
            <lastModified value="{current-dateTime()}"/>
            {$base}
        </CarePlan>
        
(:    let $lll := util:log-app('TRACE','apps.nabu',$data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-careplan:nabu-careplans, $file, $data)
            , sm:chmod(xs:anyURI($r-careplan:nabu-careplans || '/' || $file), $r-careplan:data-perms)
            , sm:chgrp(xs:anyURI($r-careplan:nabu-careplans || '/' || $file), $r-careplan:data-group)))
        return
            (
              r-careplan:rest-response(200, 'careplan sucessfully stored.')
            , $data
            )
    } catch * {
        r-careplan:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

