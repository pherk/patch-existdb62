xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-plandef = "http://enahar.org/exist/restxq/nabu/plandefs";

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

declare variable $r-plandef:nabu-plandefs := "/db/apps/nabuWorkflow/data/PlanDefinitions";
declare variable $r-plandef:coll := collection($r-plandef:nabu-plandefs);
declare variable $r-plandef:history     := concat($config:history-data,'/PlanDefinitions');
declare variable $r-plandef:data-perms    := "rwxrw-r--";
declare variable $r-plandef:data-group    := "spz";

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
declare function r-plandef:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-plandef:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-plandef:history, $nameHistory)
                    )
        )
};

declare %private function r-plandef:prepareResult($hits, $start, $length, $format)
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
        <plandefs xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </plandefs>
};


declare %private function r-plandef:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/plandefs/{$id}
 : List plandef with id.
 : 
 : @return  <PlanDefinition>...</PlanDefinition>
 :)
declare
    %rest:GET
    %rest:path("nabu/plandefs/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:produces("application/xml", "text/xml")
function r-plandef:plandefByID($id as xs:string*, $realm as xs:string*, $loguid as xs:string*) as item()
{
    let $plandefs := $r-plandef:coll/PlanDefinition[fhir:id[@value = $pid]]
    return
        if (count($plandefs)=1)
        then $plandefs
        else if (count($plandefs)>1)
        then r-plandef:rest-response(404, concat('PlanDefinition with ID: ',$id, ' too many. Ask the Admin.'))
        else r-plandef:rest-response(404, concat('PlanDefinition with ID: ',$id, ' not found. Ask the Admin.'))
};


(:~
 : GET: /nabu/plandefs/{$id}/_history
 : get plandef history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  plandef bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/plandefs/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-plandef:plandefHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-plandef:coll | collection($r-plandef:history)
    let $hits  := $coll/fhir:PlanDefinition[fhir:id[@value=$id]]
    return
        r-plandef:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/plandef/{$id}/_history/{$vid}
 : get plandef history with id $id and version $vid
 : 
 : @param $id plandef id
 : @param $vid version id
 : 
 : @return  plandef bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/plandefs/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-plandef:plandefVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-plandef:coll | collection($r-plandef:history)
    let $hits  := $coll/fhir:PlanDefinition[fhir:id[@value=$id]][meta/versionId/@value=$vid]
    return
        r-plandef:prepareHistoryBundle($id, $hits)
};

declare %private function r-plandef:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/plandefs/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/plandefs/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/plandefs/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.9.0
 : category	token	E.g. Treatment, dietary, behavioral, etc.	PlanDefinition.category	
 : identifier	token	External Ids for this plandef	PlanDefinition.identifier	26 Resources
 : patient	reference	Who this plandef is intended for	PlanDefinition.subject
   (Patient)	31 Resources
 : start-date	date	When plandef pursuit begins	PlanDefinition.startDate	
 : status	token	proposed | accepted | planned | in-progress | on-target | ahead-of-target | behind-target | sustaining | achieved | on-hold | cancelled | entered-in-error | rejected	PlanDefinition.status	
 : subject	reference	Who this plandef is intended for	PlanDefinition.subject
   (Group, Organization, Patient)	
 : target-date	date	Reach plandef on or before	PlanDefinition.target.dueDate	
 :)

(:~
 : GET: nabu/plandefs?start=1&length=10&status=...
 : List plandefs for subject
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
 : @return  bundle <plandefs/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/plandefs")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("sender",  "{$sender}")
    %rest:query-param("rangeStart", "{$rangeStart}")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "")
    %rest:query-param("status",  "{$status}", "in-progress")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-plandef:plandefs(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $start as xs:string*
        ,   $length as xs:string*
        ,   $sender as xs:string*
        ,   $rangeStart as xs:string*
        ,   $rangeEnd as xs:string*
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
        if ($sender="")
        then $r-plandef:coll/PlanDefinition[status/@value=$status]
        else $r-plandef:coll/PlanDefinition[sender/reference/@value=$aref][status/@value=$status]

    return
        switch ($format)
        case 'count' return <plandefs><count>{count($matched)}</count></plandefs> 
        default return 
            r-plandef:prepareResult($matched, $start, $length, $format)
    } catch * {
        r-plandef:rest-response(404, concat('Invalid time filter? : ', $rangeStart, '-', $rangeEnd))
    }
};

(:~
 : PUT: nabu/plandefs
 : Update an existing plandef or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/plandefs")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-plandef:putPlanDefinitionXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew := not($content/fhir:PlanDefinition/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/PlanDefinition/id/@value/string()
            let $plandefs := $r-plandef:coll/fhir:PlanDefinition[fhir:id/@value = $id]
            let $move := r-plandef:moveToHistory($plandefs)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/PlanDefinition/meta/versionId/@value/string()) + 1
    let $base := $content/PlanDefinition/fhir:*[not(
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
        <PlanDefinition xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </PlanDefinition>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-plandef:nabu-plandefs, $file, $data)
            , sm:chmod(xs:anyURI($r-plandef:nabu-plandefs || '/' || $file), $r-plandef:data-perms)
            , sm:chgrp(xs:anyURI($r-plandef:nabu-plandefs || '/' || $file), $r-plandef:data-group)))
        return
            r-plandef:rest-response(200, 'plandef sucessfully stored.') 
    } catch * {
        r-plandef:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

