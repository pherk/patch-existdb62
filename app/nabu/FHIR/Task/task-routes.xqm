xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-task = "http://enahar.org/exist/restxq/nabu/tasks";

import module namespace config = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace date   = "http://enahar.org/exist/apps/nabu/date"    at "../../modules/date.xqm";
import module namespace tasklist = "http://enahar.org/exist/apps/nabu/task-list" at "../Task/task-list.xqm";

import module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize" at "../../FHIR/meta/serialize-fhir-resources.xqm";
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

declare variable $r-task:base := "/db/apps/nabuCom/data/Tasks";

declare variable $r-task:history    := concat($config:history-data,'/Tasks');
declare variable $r-task:data-perms := "rwxrw-r--";
declare variable $r-task:data-group := "spz";
declare variable $r-task:valid-status  := ('received','accepted','completed','cancelled','entered-in-error','unknown');

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
declare %private function r-task:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-task:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-task:history, $nameHistory)
                    )
        )
};

declare %private function r-task:prepareResult($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:authoredOn/@value/string() descending
            return
                $c
    return
        <tasks xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </tasks>
};

declare %private function r-task:prepareResultBundleXML($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:authoredOn/@value/string() descending
            return
                $c
    return
        <Bundle xmlns="http://hl7.org/fhir">
            <id value="bundle-example"/> 
            <meta> 
                <lastUpdated value="2014-08-18T01:43:30Z"/>
            </meta>  
            <type value="searchset"/>   
            <total value="3"/> 
            <link> 
                <relation value="self"/> 
                <url value="https://example.com/base/Task?patient=347&amp;_include=MedicationRequest.medication"/> 
            </link> 
            <link> 
                <relation value="next"/> 
                <url value="https://example.com/base/Task?patient=347&amp;searchId=ff15fd40-ff71-4b48-b366-09c706bed9d0&amp;page=2"/> 
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

declare %private function r-task:prepareResultBundleJSON($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:authoredOn/@value/string() descending
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
                <url value="https://example.com/base/Task?patient=347&amp;_include=MedicationRequest.medication"/> 
            </link> 
            <link> 
                <relation value="next"/> 
                <url value="https://example.com/base/Task?patient=347&amp;searchId=ff15fd40-ff71-4b48-b366-09c706bed9d0&amp;page=2"/> 
            </link> 
            {
                for $r in subsequence($sorted-hits, $start, $len1)
                return
                    <entry>
                        <fullUrl value="{concat('http://localhost:8080/exist/restxq/nabu/tasks/',$r/fhir:id/@value)}"/>
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


declare %private function r-task:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-task:facet-filter(
          $facets as node()
        ) as xs:string?
{
    string-join(
    (
        for $f in $facets/*:facet
        let $closer := if(contains($f/@path,'[')) then "]]" else "]"
        return
            if ($f and $f!='')
            then 
                switch ($f/@method)
                    case 'matches' return concat("[matches(", $f/@path, ", '", $f, "')]")
                    case 'equals'  return 
                        let $toks := tokenize($f,' ')
                        let $value := if (count($toks)=1) 
                                then concat("'", $toks, "'")
                                else if (count($toks)>1)
                                then concat(
                                         "("
                                        , string-join(
                                              for $v in $toks
                                              return 
                                                concat("'",$v,"'")
                                            , ',')
                                        , ")"
                                        )
                                else ''
                        return
                            concat("[", $f/@path, " = ", $value, $closer)
                    default return ()
            else ()
    )
    ,'')
};

(:~
 : GET: nabu/tasks/{$id}
 : List task with id.
 : 
 : @return  <Task>...</Task>
 :)
declare
    %rest:GET
    %rest:path("nabu/tasks/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-task:taskByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $tasks := collection($r-task:base)/Task[fhir:id[@value=$id]]
    return
        if (count($tasks)=1)
        then $tasks
        else if (count($tasks)>1)
        then r-task:rest-response(404, concat('Task with ID: ',$id, ' too many. Ask the Admin.'))
        else r-task:rest-response(404, concat('Task with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : update subject 
 : 
 : TODO??? <for/> = subject?
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $pid
 : @param $pnam
 : 
 : @return 
 :)
declare function r-task:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := collection($r-task:base)/fhir:Task[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:for/fhir:reference/@value with concat('nabu/patients/',$pid)
                , update value $res/fhir:for/fhir:display/@value with $pnam
                , update value $res/fhir:meta/fhir:extension[@url='http://eNahar.org/nabu/extension#lastUpdatedBy']/valueReference/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension[@url='http://eNahar.org/nabu/extension#lastUpdatedBy']/valueReference/fhir:display/@value with $lognam
                , update value $res/fhir:meta/lastUpdated/@value with current-dateTime()
                ))
        else ()
};

(:~
 : GET: /nabu/tasks/{$id}/_history
 : get task history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  task bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/tasks/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-task:taskHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := collection($r-task:base) | collection($r-task:history)
    let $hits  := $coll/fhir:Task[fhir:id[@value=$id]]
    return
        r-task:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/task/{$id}/_history/{$vid}
 : get task history with id $id and version $vid
 : 
 : @param $id task id
 : @param $vid version id
 : 
 : @return  task bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/tasks/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-task:taskVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := collection($r-task:base) | collection($r-task:history)
    let $hits  := $coll/fhir:Task[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-task:prepareHistoryBundle($id, $hits)
};

declare %private function r-task:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/tasks/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/tasks/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}</id>
                        <updated>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</updated>
                        <published>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/tasks/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.0.1
 : category	token	Message category	Task.category
 : encounter	reference	Encounter leading to message	Task.encounter
 : identifier	token	Unique identifier	Task.identifier
 : medium	token	A channel of task	Task.medium
 : patient	reference	Focus of message	Task.subject
 : received	date	When received	Task.received
 : recipient	reference	Message recipient	Task.recipient
   (Practitioner, Group, Organization, Device, Patient, RelatedPerson)
 : request	reference	TaskRequest producing this message	Task.requestDetail
 : sender	reference	Message sender	Task.sender
   (Practitioner, Organization, Device, Patient, RelatedPerson)
 : sent	date	When sent	Task.sent
 : status	token	in-progress | completed | suspended | rejected | failed	Task.status
 : subject	reference	Focus of message	Task.subject
 :)

(:~
 : GET: nabu/tasks?start=1&length=10&status=...
 : List tasks for subject
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
 : @return  bundle <tasks/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/tasks")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam","{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("code",  "{$code}", "task")
    %rest:query-param("owner",  "{$owner}" , "")
    %rest:query-param("recipient", "{$recipient}", "")
    %rest:query-param("recipient-role", "{$recipient-role}", "")
    %rest:query-param("rangeStart", "{$rangeStart}")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "received")
    %rest:query-param("_format", "{$format}", "full")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-task:tasksXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ,   $start as xs:string*
        ,   $length as xs:string*
        , $code as xs:string*
        ,   $owner as xs:string*
        ,   $recipient as xs:string*
        , $recipient-role as xs:string*
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
    let $coll := collection($r-task:base)
    let $oref := "metis/practitioners/" || $owner
    let $rref := "metis/practitioners/" || $recipient
    let $sref := "nabu/patients/" || $subject
    let $matched := 
        if ($recipient="")
        then if ($subject="" and $owner="")
            then if ($recipient-role="")
                then $coll/fhir:Task[fhir:status[@value=$status]][fhir:code/fhir:coding[fhir:code/@value=$code]]
                else $coll/fhir:Task[fhir:status[@value=$status]][fhir:restriction/fhir:recipient[fhir:reference/@value=""][fhir:extension[@url="http://eNahar.org/nabu/extension#task-recipient-role"]/fhir:valueString/@value=$recipient-role]]
            else if ($subject="")
            then $coll/fhir:Task[fhir:owner[fhir:reference/@value=$oref]][fhir:status[@value=$status]]
            else if ($owner="")
            then $coll/fhir:Task[fhir:for[fhir:reference/@value=$sref]][fhir:status[matches(@value,$status)]]
            else $coll/fhir:Task[fhir:for[fhir:reference/@value=$sref]][fhir:owner[fhir:reference/@value=$oref]][fhir:status[@value=$status]]
        else if ($subject="" and $owner="")
        then if ($recipient-role="")
                then $coll/fhir:Task[fhir:restriction/fhir:recipient[fhir:reference/@value=$rref]][fhir:status[@value=$status]]
                else $coll/fhir:Task[fhir:restriction/fhir:recipient[fhir:reference/@value=$rref]][fhir:status[@value=$status]] |
             $coll/fhir:Task[fhir:status[@value=$status]][fhir:restriction/fhir:recipient[fhir:reference/@value=""][fhir:extension[@url="http://eNahar.org/nabu/extension#task-recipient-role"]/fhir:valueString/@value=$recipient-role]]
        else $coll/fhir:Task[fhir:for[fhir:reference/@value=$sref]][fhir:restriction/fhir:recipient[fhir:reference/@value=$rref]][fhir:owner[fhir:reference/@value=$oref]][fhir:status[@value=$status]]
    return
        switch ($format)
        case 'count' return <tasks><count>{count($matched)}</count></tasks> 
        default return 
            r-task:prepareResult($matched, $start, $length, $format)
    } catch * {
        r-task:rest-response(404, concat('Invalid time filter? : ', $rangeStart, '-', $rangeEnd))
    }
};

(:~
 : GET: nabu/tasks?start=1&length=10&status=...
 : List tasks for subject
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
 : @return  bundle <tasks/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/tasks")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam","{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("owner",  "{$owner}" , "")
    %rest:query-param("recipient", "{$recipient}", "")
    %rest:query-param("rangeStart", "{$rangeStart}")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "received")
    %rest:query-param("_format", "{$format}", "full")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
function r-task:tasksJSON(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ,   $start as xs:string*
        ,   $length as xs:string*
        ,   $owner as xs:string*
        ,   $recipient as xs:string*
        ,   $rangeStart as xs:string*
        ,   $rangeEnd as xs:string*
        ,   $subject as xs:string*
        ,   $status as xs:string*
        ,   $format as xs:string*
        ) as item()
{
(:~ 
 :  namespace interaction with util:eval.
 :  you can exec as long as you will, but the next call an other routine fails with error
 :  namespace "config" not defined
:)
(: 
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
    let $coll := collection($r-task:base)
    let $oref := "metis/practitioners/" || $owner
    let $rref := "metis/practitioners/" || $recipient
    let $sref := "nabu/patients/" || $subject
    let $matched := 
        if ($recipient="" and $subject="" and $owner="")
        then $coll/fhir:Task[fhir:status[@value=$status]]
        else if ($recipient="" and $subject="")
        then $coll/fhir:Task[fhir:owner[fhir:reference/@value=$oref]][fhir:status[@value=$status]]
        else if ($recipient="" and $owner="")
        then $coll/fhir:Task[fhir:for[fhir:reference/@value=$sref]][fhir:status[matches(@value,$status)]]
        else if ($subject="" and $owner="")
        then $coll/fhir:Task[fhir:restriction/fhir:recipient[fhir:reference/@value=$rref]][fhir:status[@value=$status]]
        else $coll/fhir:Task[fhir:for[fhir:reference/@value=$sref]][fhir:restriction/fhir:recipient[fhir:reference/@value=$rref]][fhir:owner[fhir:reference/@value=$oref]][fhir:status[@value=$status]]

    return
        r-task:prepareResultBundleJSON($matched, $start, $length)
};


(:~
 : PUT: nabu/tasks/{$cid}/status/{$status}
 : Update an existing task.
 :
 : 
 : @return <response>
 :)
declare
    %rest:PUT
    %rest:path("nabu/tasks/{$cid}/status/{$status}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-task:updateStatus(
      $cid as xs:string*
    , $status as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
let $lll := util:log-system-out($status)
    let $cp := collection($r-task:base)/fhir:Task[fhir:id[@value = $cid]]
    return
    try {
        if (count($cp)=1 and r-task:isValid($status))
        then    
            let $up := system:as-user('vdba', 'kikl823!',
                (
                  update value $cp/fhir:status/@value with $status
                ))
            return
            r-task:rest-response(200, 'task status updated.')
        else
            r-task:rest-response(404, 'task status not updated.') 
    } catch * {
        r-task:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-task:isValid($status as xs:string) as xs:boolean
{
    $status = $r-task:valid-status
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
 : GET: /nabu/tasks2pdf
 : Search Task using a given field and a (lucene) query string.
 : 
 : @return tasks as pdf
 :)
declare 
    %rest:GET
    %rest:path("/nabu/tasks2pdf")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("recipient",  "{$recipient}")
    %rest:query-param("role",       "{$role}")  
    %rest:query-param("code",       "{$code}",  "task")
    %rest:query-param("for",        "{$for}")
    %rest:query-param("rangeStart", "{$rangeStart}", "2004-01-01")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2021-04-01")
    %rest:query-param("status",     "{$status}",  "accepted")
    %rest:query-param("_sort",      "{$sort}", "date")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-task:tasks2PDF(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $recipient as xs:string*
    , $role as xs:string*
    , $code as xs:string*
    , $for as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    , $status as xs:string*
    , $sort as xs:string*
    )
{
    let $params := map {
          'recipient' : $recipient
        , 'role'      : $role
        , 'code'      : $code
        , 'for'       : $for
        , 'rangeStart': $rangeStart
        , 'rangeEnd'  : $rangeEnd
        , 'status'    : $status
        , 'sort'      : $sort
        }
    let $tmin := if (contains($rangeStart,'T'))
            then xs:dateTime($rangeStart)
            else dateTime(xs:date($rangeStart), xs:time('00:00:00'))
    let $tmax := if (contains($rangeEnd,'T'))
            then xs:dateTime($rangeEnd)
            else dateTime(xs:date($rangeEnd), xs:time('23:59:59'))
    let $rref := if (not($recipient) or $recipient='')
            then ''
            else concat('metis/practitioners/', $recipient)
    
    let $facets := 
        <facets xmlns="">
            <facet name="recipient"  method="equals" path="fhir:restriction/fhir:recipient[fhir:reference/@value">{$rref}</facet>
            <facet name="role"       method="equals" path="fhir:restriction/fhir:recipient/fhir:extension/fhir:valueString/@value">{$role}</facet>
            <facet name="code"       method="equals"  path="fhir:code/fhir:coding[fhir:code/@value">{$code}</facet>
            <facet name="for"        method="equals"  path="fhir:for[fhir:reference/@value">{$for}</facet>
            <!--
            <facet name="rangeStart" method="equals"  path="fhir:/fhir:start/@value">{$rangeStart}</facet>
            <facet name="rangeEnd"   method="equals" path="fhir:/fhir:end/@value">{$rangeEnd}</facet>
            -->
            <facet name="status"     method="equals"  path="fhir:status[@value">{$status}</facet>
        </facets>
        

    let $facetfilter := r-task:facet-filter($facets)
    let $filter := concat('collection(',$r-task:base,')/fhir:Task',$facetfilter)
    let $lll := util:log-app('TRACE','apps.nabu',$filter)

    let $matched := util:eval($filter)
    let $lll := util:log-app('TRACE','apps.nabu',count($matched))

    let $result := 
        switch ($code)
        case 'task' return tasklist:prepareSimpleList($matched,$params)
        case 'team' return tasklist:prepareTeamList($matched, $params)
        default return ()
    let $filename := 
        switch ($code)
        case 'task' return 'task-'
        case 'team' return 'team-'
        default return 'error'
    let $range := concat(format-dateTime($tmin,'[D01].[M01]'),'-', format-dateTime($tmax,'[D01].[M01].[Y01]'))
    return
        if ($result)
        then 
            let $fo  := tei2fo:report($result)
            let $pdf := xslfo:render($fo, "application/pdf", ())
            let $file := concat($filename,$range,'.pdf')
            return
            (   <rest:response>
                    <http:response status="200">
                        <http:header name="Content-Type" value="application/pdf"/>
                        <http:header name="Content-Disposition" value="attachment;filename={$file}"/>
                    </http:response>
                 </rest:response>
            ,   $pdf
            )
        else
            r-task:rest-response(404, 'Task List empty')
            
};

(:~
 : PUT: nabu/tasks
 : Update an existing task or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/tasks")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-task:putTaskXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    let $content := if($content/fhir:Task)
        then $content
        else document { local:addNamespaceToXML($content/*:Task,"http://hl7.org/fhir") }
    let $isNew := not($content/fhir:Task/@xml:id)
    let $eid   := if ($isNew)
        then concat("t-", util:uuid())
        else 
            let $id := $content/Task/id/@value/string()
            let $tasks := collection($r-task:base)/fhir:Task[fhir:id[@value = $id]]
            let $move := r-task:moveToHistory($tasks)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Task/meta/versionId/@value/string()) + 1
    let $base := $content/Task/fhir:*[not(
                                               self::id
                                            or self::meta
                                            or self::restriction
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
        <Task xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$eid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                    <valueReference>
                        <reference value="{concat('metis/practitioners/',$loguid)}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
                <lastUpdated value="{current-dateTime()}"/>
            </meta>
            {$base}
            {r-task:mapDeadline($content/fhir:Task/fhir:restriction)}
        </Task>
(:         
    let $lll := util:log-system-out($data) 
:)
    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-task:base, $file, $data)
            , sm:chmod(xs:anyURI($r-task:base || '/' || $file), $r-task:data-perms)
            , sm:chgrp(xs:anyURI($r-task:base || '/' || $file), $r-task:data-group)))
        return
            (
              r-task:rest-response(200, 'task sucessfully stored.')
            , $data
            )
    } catch * {
        r-task:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-task:mapDeadline(
          $r as element(fhir:restriction)
        ) as element(fhir:restriction)
{
    let $dl  := try {
                    date:easyDateTime($r/fhir:period/fhir:end/@value/string())
            } catch * {
                    adjust-dateTime-to-timezone(current-dateTime(),())
            }
    return
        <restriction xmlns="http://hl7.org/fhir">
            <period>
                <start value="{$r/fhir:period/fhir:start/@value/string()}"/>
                <end value="{$dl}"/>
            </period>
            {$r/fhir:recipient}
        </restriction>
};
