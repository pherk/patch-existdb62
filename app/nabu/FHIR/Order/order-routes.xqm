xquery version "3.0";

(: 
 : Defines the RestXQ endpoints.
 : @author Peter Herkenrath
 : @version 1.0
 : @see http://www.enahar.org
 :
 :)
 
module namespace r-order = "http://enahar.org/exist/restxq/nabu/orders";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config     = "http://enahar.org/exist/apps/nabu/config"        at "../../modules/config.xqm";
import module namespace date       = "http://enahar.org/exist/apps/nabu/date"          at "../../modules/date.xqm";
import module namespace r-user     = "http://enahar.org/exist/restxq/metis/users"      at "/db/apps/metis/FHIR/user/user-routes.xqm";

import module namespace requestgrp = "http://enahar.org/exist/apps/nabu/requestgroup"  at "../../FHIR/RequestGroup/requestgroup.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http   = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-order:orders       := 'nabu/orders/';
declare variable $r-order:practitioners:= 'metis/practitioners/';
declare variable $r-order:patients     := 'nabu/patients/';
declare variable $r-order:schedules    := 'enahar/schedules/';

declare variable $r-order:base         := '/db/apps/nabuData/data/FHIR/Orders';
declare variable $r-order:coll         := collection($r-order:base);
declare variable $r-order:history      := concat($config:history-data,'/Orders');
declare variable $r-order:valid-status := ('draft','active','completed','cancelled','entered-in-error');

(:~
 : 
 : HTTP RESPONSE CODES USED
 : 
 : 200 - Operation Success
 : 420 - Operation Failed
 : 400 - Bad Request Syntax
 : 404 - Resource Not Available
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
declare function r-order:moveToHistory(
      $orders as element()*
    ) 
{
    for $o in $orders
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-order:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-order:history, $nameHistory)
                    )
        )
};


declare %private function r-order:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};


declare %private function r-order:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <orders xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </orders>
};

(:~
 : GET: nabu/orders/{$id}
 : List order with id.
 : 
 : @return  <Order>...</Order>
 :)
declare
    %rest:GET
    %rest:path("nabu/orders/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-order:orderByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $ods := $r-order:coll/Order[fhir:id[@value=$id]]
    return
        if (count($ods)=1) then
            $ods
        else r-order:rest-response(404, concat('Order with ID: ',$id, ' error. Ask the Admin.'))
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
declare function r-order:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-order:coll/fhir:Order[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:subject/fhir:reference/@value with concat('nabu/patients/', $pid)
                , update value $res/fhir:subject/fhir:display/@value with $pnam
                , update value $res/fhir:lastModifiedBy/fhir:reference/@value with concat('metis/practitioners/', $loguid)
                , update value $res/fhir:lastModifiedBy/fhir:display/@value with $lognam
                , update value $res/fhir:lastModified/@value with current-dateTime()
                ))
        else ()
};


(:~
 : GET: /nabu/orders/{$id}/_history
 : get order history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  order bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/orders/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-order:orderHistoryByID($id as xs:string*,
        $start as xs:string*, $length as xs:string*)
{
    let $coll  := $r-order:coll | collection($r-order:history)
    let $hits  := $coll/fhir:Order[fhir:id[@value=$id]]
    return
        r-order:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/order/{$id}/_history/{$vid}
 : get order history with id $id and version $vid
 : 
 : @param $id order id
 : @param $vid version id
 : 
 : @return  order bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/orders/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-order:orderVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll  := $r-order:coll | collection($r-order:history)
    let $hits  := $coll/fhir:Order[fhir:id[@value=$id]][meta/versionId/@value=$vid]
    return
        r-order:prepareHistoryBundle($id, $hits)
};

declare %private function r-order:prepareHistoryBundle($id, $entries)
{
    let $serverip := 'http://enahar.org'
    return
        <feed>
            <id vlaue=""/>
            <meta>
                <lastUpdated value="{current-dateTime()}"/>
                <versionId value="0"/>
            </meta>
            <type vlaue="history"/>
            <title value=""/>
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/orders/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/nabu"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name value="eNahar FHIR Server"/>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/meta/versionId/@value)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/nabu/orders/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/orders/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : 
 : List order with id.
 : 
 : @return  <Order>...</Order>
 :)
declare
function r-order:teamTasks($realm as xs:string, $loguid as xs:string) as item()
{
    <ok/>
};

(:~
 : 
 : List order with id.
 : 
 : @return  <Order>...</Order>
 :)
declare
function r-order:actionTasks($realm as xs:string, $loguid as xs:string, $type as xs:string) as item()
{
    <ok/>
};

(:~
 : Composition Search parameter from FHIR 0.4
 : authority	reference	If required by policy	Order.authority
 : date         date	When the order was made	Order.date
 : detail	    reference	What action is being ordered	Order.detail
 : patient	    reference	Patient this order is about	 (same as subject!)
 : source	    reference	Who initiated the order	Order.source
 : subject	    reference	Patient this order is about	Order.subject
 : target	    reference	Who is intended to fulfill the order	Order.target (Device, Organization, Practitioner)
 : when	date	A formal schedule	Order.when.schedule
 : when_code	token	Code specifies when request should be done. The code may simply be a priority code
 :)
(:~
 : GET: nabu/orders?start=1&length=10&status=...
 : List orders for user and return them as XML.
 : 
 : @param   $start
 : @param   $length
 : @param   $subject reference
 : @param   $source reference
 : @param   $target reference
 : @param   $reason
 : @param   $status
 : @param   $date
 : @param   $tag
 : @return  bundle <Order/>
 :)
declare
    %rest:GET
    %rest:path("nabu/orders")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}",  "1")
    %rest:query-param("length", "{$length}", "10")
    %rest:query-param("subject","{$subject}", "")
    %rest:query-param("source", "{$source}", "")
    %rest:query-param("target", "{$target}", "")
    %rest:query-param("reason", "{$reason}", "appointment")
    %rest:query-param("status", "{$status}", "active")
    %rest:query-param("actor",   "{$actor}")
    %rest:query-param("service", "{$role}",  "")
    %rest:query-param("schedule", "{$schedule}", "")
    %rest:query-param("rangeStart", "{$rangeStart}")
    %rest:query-param("rangeEnd",   "{$rangeEnd}")
    %rest:query-param("tag",     "{$tag}",    "spz")
    %rest:query-param("_sort",   "{$sortBy}", "date:desc")
    %rest:query-param("acq",  "{$acq}", "")
    %rest:query-param("ro", "{$reorderOnly}","false")
    %rest:produces("application/xml", "text/xml")
function r-order:orders(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start  as xs:string*
    , $length as xs:string*
    , $subject as xs:string*
    , $source as xs:string*
    , $target as xs:string*
    , $reason as xs:string*
    , $status as xs:string*
    , $actor as xs:string*
    , $role as xs:string*
    , $schedule as xs:string*
    , $rangeStart as xs:string*, $rangeEnd as xs:string*
    , $tag as xs:string*
    , $sortBy as xs:string*
    , $acq as xs:string*
    , $reorderOnly as xs:string*
    ) as item()
{
    let $aref    := concat($r-order:practitioners, $actor)
    let $sref    := concat($r-order:practitioners, $source)
    let $tref    := concat($r-order:practitioners, $target)
    let $pref    := concat($r-order:patients, $subject)
    let $hits00  := $r-order:coll/fhir:Order[fhir:status[@value=$status]][fhir:reason/fhir:coding[fhir:code/@value=$reason]]
    let $hits0   := if ($reorderOnly='true')
                    then $hits00/../fhir:Order[fhir:detail/fhir:reorder[@value='true']]
                    else $hits00
    let $hits1  := if ($actor=':missing')
                    then $hits0/../fhir:Order[fhir:detail/fhir:actor[fhir:reference[@value='']]]
                    else if ($actor and $acq='')
                    then $hits0/../fhir:Order[fhir:detail/fhir:actor[fhir:reference[@value=$aref]]]
                    else if ($actor and $acq!='')
                    then $hits0/../fhir:Order[fhir:detail[fhir:actor[fhir:reference[@value=$aref]]][fhir:status[@value=$acq]]]
                    else $hits0
    let $hits2  := if ($role=':missing')
                    then $hits1/../fhir:Order[fhir:detail/fhir:actor[fhir:role[@value='']]]
                    else if ($role)
                    then if ($acq='')
                        then $hits1/../fhir:Order[fhir:detail/fhir:actor[fhir:role[@value=$role]]]
                        else $hits1/../fhir:Order[fhir:detail[fhir:status[@value=$acq]][fhir:actor[fhir:role[@value=$role]]]]
                    else $hits1
    let $hits2a := if ($schedule=':missing')
                    then $hits2/../fhir:Order[fhir:detail/fhir:schedule[fhir:reference[@value='']]]
                    else if ($schedule)
                    then
                        let $schedref := concat('enahar/schedules/',$schedule)
                        return
                            if ($acq='')
                            then $hits2/../fhir:Order[fhir:detail/fhir:schedule[fhir:reference[@value=$schedref]]]
                            else $hits2/../fhir:Order[fhir:detail[fhir:status[@value=$acq]]/fhir:schedule[fhir:reference[@value=$schedref]]]
                    else $hits2
    let $hits3  := if ($source='')
                    then $hits2a
                    else $hits2a/../fhir:order[fhir:source[fhir:reference/@value=$sref]]
    let $hits4  := if ($target='')
                    then $hits3
                    else $hits3/../fhir:Order[fhir:target[fhir:reference/@value=$tref]] |
                         $hits3/../fhir:Order[fhir:target[fhir:reference/@value='']] (: [fhir:target/fhir:role/@value=$role]  target role only :)
    let $hits5  := if ($subject='')
                    then $hits4
                    else $hits4/../fhir:Order[fhir:subject/fhir:reference[@value=$pref]]
    let $valid  :=  if ($rangeStart)
                    then $hits5/../fhir:Order[fhir:date[@value>$rangeStart]][fhir:date[@value<$rangeEnd]]
                    else $hits5

    let $sorted-hits := 
        switch ($sortBy)
        case "when-schedule" return (: due date :)
            for $e in $valid
            order by $e/when/schedule/event/@value/string() collation "?lang=de-DE"
            return
                $e
        case "when-code-1" return (: priority :)
                $valid[when/code/coding/code/@value="urgent"]
        case "when-code-2" return (: priority :)
            for $e in $valid[when/code/coding/code/@value="high"]
            order by $e/fhir:date/@value/string() 
            return
                $e
        case "when-code-3" return (: priority :)
                $valid[when/code/coding/code/@value="normal"]
        case "when-code-4" return (: priority :)
                $valid[when/code/coding/code/@value="low"]
        case "date:desc" return
            for $e in $valid
            order by $e/fhir:date/@value/string() descending 
            return
                $e
        default return
            for $e in $valid
            order by $e/fhir:date/@value/string() 
            return
                $e
    return
        r-order:prepareResult($sorted-hits, $start, $length)
};

(:~
 : GET: nabu/ordersBySubject?status=...
 : List orders for user and return them as XML.
 : 
 : @param   $subject reference
 : @param   $status

 : @return  bundle <Order/>
 :)
declare
    %rest:GET
    %rest:path("nabu/ordersBySubject/{$subject}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("status", "{$status}", "")
    %rest:produces("application/xml", "text/xml")
function r-order:orderBySubject(
          $subject as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $status as xs:string*
    ) as item()
{
    (: TODO: remove hack for wrong patient path in tickets :)
    let $pref    := (concat($r-order:patients, $subject),concat('metis/patients/',$subject))
    let $hits   := if ($status = "")
        then $r-order:coll/Order[fhir:subject[fhir:reference[@value=$pref]]]
        else $r-order:coll/Order[fhir:subject[fhir:reference[@value=$pref]]][fhir:status[@value=$status]]
    let $sorted-hits := 
            for $e in $hits
            order by $e/fhir:date/@value/string() 
            return
                $e
    return
        r-order:prepareResult($sorted-hits, '1', '*')
};

(:~
 : POST: nabu/orders
 : Update an existing order because an tentative encounter was rejected
 : 
 : @param $content encounter ressource
 : @return <response>
 : 
 : TODO set ./*:when/*:code/*:coding/*:code/@value='urgent'
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/orders")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}", '')
    %rest:query-param("lognam", "{$lognam}", 'anon')
    %rest:query-param("reason",  "{$reason}")
    %rest:query-param("prio", "{$prio}", 'normal')
    %rest:query-param("prio-display", "{$prio-display}", 'normal')
    %rest:query-param("deadline", "{$deadline}", 'default')
    %rest:produces("application/xml", "text/xml")
function r-order:reopenOrder(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $reason as xs:string*
    , $prio as xs:string*
    , $prio-display as xs:string*
    , $deadline as xs:string*
    ) as item()*
{
    let $enc   := $content/fhir:Encounter
    (: get order reference and detail reference :)
    let $oref  := tokenize(substring-after($enc/fhir:appointment/reference/@value,$r-order:orders),'\?')
    let $odref := if ($oref[2])
        then substring-after($oref[2],'detail=')
        else ''
    let $oo    := $r-order:coll/fhir:Order[fhir:id[@value=$oref[1]]]
    let $uuid  := $oo/@xml:id
    let $base  := $oo/fhir:*[not(self::status)][not(self::when)][not(self::detail)]
    let $details := $oo/fhir:detail
    let $sched := if ($deadline='default' or $deadline='')
            then $oo/fhir:when/fhir:schedule
            else
                <schedule xmlns="http://hl7.org/fhir">
                    <event value="{$deadline}"/>
                </schedule>
    let $when  := 
            <when xmlns="http://hl7.org/fhir">
                <code>
                    <coding>
                        <system value="#order-priority"/>
                        <code value="{$prio}"/>
                        <display value="{$prio-display}"/>
                    </coding>
                    <text value="{$prio-display}"/>
                </code>
                { $sched }
            </when>
    let $data := 
        <Order xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            { $base }
            { $when }
            { r-order:reopenDetails($details,$odref) }
            <status value="active"/>
        </Order>
    return
        r-order:putOrderXML(document {$data},$realm,$loguid, $lognam)
};

declare %private function r-order:reopenDetails($details, $odref) as item()*
{
    for $d in $details
    return
        if ($d/@id=$odref)
        then r-order:reopenDetail($d)
        else $d
};

declare %private function r-order:reopenDetail($d) as item()*
{
    let $db := $d/fhir:*[not(self::process)][not(self::proposal)][not(self::status)][not(self::reorder)]
    return
        <detail id="{$d/@id/string()}" xmlns="http://hl7.org/fhir">
            <process value="true"/>
            { $db }
            <proposal>
                <start value=""/>
                <end value=""/>
            </proposal>
            <reorder value="true"/>
            <status value="active"/>
        </detail>
};
declare function r-order:node-type($node)
{
 if ($node instance of element()) then 'element'
 else if ($node instance of attribute()) then 'attribute'
 else if ($node instance of text()) then 'text'
 else if ($node instance of document-node()) then 'document-node'
 else if ($node instance of comment()) then 'comment'
 else if ($node instance of processing-instruction())
         then 'processing-instruction'
 else 'unknown'
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
 : PUT: nabu/orders
 : Update an existing order or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/orders")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}", '')
    %rest:query-param("lognam", "{$lognam}", 'anon')
    %rest:produces("application/xml", "text/xml")
function r-order:putOrderXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    (: let $lll := util:log-app('TRACE','apps.nabu',$content) :)
    let $content := if($content/fhir:Order)
        then $content
        else if ($content/*:Order)
        then document { local:addNamespaceToXML($content/*:Order,"http://hl7.org/fhir") }
        else let $lll := util:log-app('TRACE','apps.nabu',$content)
            return
                error()
(: 
let $lll := util:log-app('TRACE','apps.nabu',r-order:node-type($content))
let $lll := util:log-app('TRACE','apps.nabu',$content)
let $lll := util:log-app('TRACE','apps.nabu',$content/fhir:Order/*:id/@value)
:)
    let $isNew := not($content/fhir:Order/@xml:id)
    let $oid   := if ($isNew)
        then concat("o-", util:uuid())
        else 
            let $id := $content/Order/id/@value/string()
            let $order := $r-order:coll/fhir:Order[fhir:id[@value = $id]]
            let $move := r-order:moveToHistory($order)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Order/meta/versionId/@value/string()) + 1
    let $base := $content/Order/fhir:*[not(
                                               self::meta
                                            or self::id
                                            or self::lastModified
                                            or self::lastModifiedBy
                                            or self::when
                                          )]
    let $meta := $content//meta/fhir:*[not(self::versionId)]
    let $lastModifiedBy := if ($loguid = '' and $content/fhir:Order/fhir:lastModifiedBy)
        then
            $content/Order/fhir:lastModifiedBy
        else
            <lastModifiedBy  xmlns="http://hl7.org/fhir">
                <reference value="{if ($loguid != '') then concat('metis/practitioners/',$loguid) else ''}"/>
                <display value="{$lognam}"/>
            </lastModifiedBy>  
    let $when := $content//when
    let $uuid := if ($isNew) 
        then $oid
        else concat("o-", util:uuid())
    let $data := 
        <Order xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$oid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
            </meta>
            { $lastModifiedBy }  
            <lastModified value="{current-dateTime()}"/>
            { r-order:mapWhen($when, $base) }
            { $base }
        </Order>
        
(: 
    let $lll := util:log-app('TRACE','apps.nabu',$data)
:)
    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:nabu-orders, $file, $data)
            , sm:chmod(xs:anyURI($config:nabu-orders || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:nabu-orders || '/' || $file), $config:data-group)))
        return
            (
              r-order:rest-response(200, 'order sucessfully stored.')
            , $data
            )
    } catch * {
        r-order:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-order:mapWhen($when, $base) as item()
{
    let $code := $when/code
    let $due := if($base[fhir:status/@value='completed'])
        then $when//event/@value/string()
        else if ($when//start) (: backwards compatibility issue, old task structure :)
            then r-order:mapDate($when//start/@value)
            else if ($base/proposal)   (: regular order :)
                then r-order:calcNextDueDate($base)
                else r-order:mapDate($when/schedule/event/@value) (: probably task :)
    return
        <when xmlns="http://hl7.org/fhir">
            { $code }
            <schedule>
                <event value="{$due}"/>
            </schedule>
        </when>
};

declare %private function r-order:mapDate($d as xs:string*) as xs:dateTime
{
    try {
        date:easyDateTime($d)
    } catch * {
        adjust-dateTime-to-timezone(current-dateTime(),())
    }
};

declare %private function r-order:calcNextDueDate($base as item()*) as xs:dateTime
{
    try {
        let $due := for $d in distinct-values($base[fhir:status/@value='active']/spec/begin/@value)
            return
                date:easyDateTime($d)
        return
            if (count($due)>0)
            then min($due)
            else adjust-dateTime-to-timezone(current-dateTime(),())
    } catch * {
        adjust-dateTime-to-timezone(current-dateTime(),())
    }
};

(:~ pre 0.8 deprecated
 : POST: nabu/app2order
 : Use an existing apppointment to setup a new order
 : 
 : @param $content appointment ressource
 : @return <response>
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/app2order")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}", '')
    %rest:query-param("lognam", "{$lognam}", 'anon')
    %rest:produces("application/xml", "text/xml")
function r-order:newOrderFromAppointment(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $app   := $content/Appointment
    (: get order reference and detail reference :)
    let $oref  := tokenize(substring-after($app/order/reference/@value,$r-order:orders),'\?')
    let $odref := if ($oref[2])
        then substring-after($oref[2],'detail=')
        else ''
let $lll := util:log-app("DEBUG","nabu", $oref[1])
    let $oo    := $r-order:coll/Order[fhir:id/@value=$oref[1]]
    let $od := if ($odref='')
        then $oo/fhir:detail[fhir:actor/fhir:reference/@value=$app/fhir:participant[fhir:type/fhir:coding[fhir:code/@value!='patient']]/fhir:actor/fhir:reference/@value]
        else $oo/fhir:detail[@id=$odref]
let $lll := util:log-app("DEBUG","nabu", $od)
    let $pref  := $oo//fhir:subject/fhir:reference/@value/string()
    let $pdis  := $oo//fhir:subject/fhir:display/@value/string()

    let $new := 
                <Order>
                    <id value=""/>
                    <meta>
                        <versionId value="0"/>
                    </meta>
                    <identifier/>
                    <date value="{adjust-dateTime-to-timezone(current-dateTime(),())}"/>
                    <subject>
                        <reference value="{$pref}"/>
                        <display value="{$pdis}"/>
                    </subject>
                    <source>
                        <reference value="{concat('/metis/practitioners/',$loguid)}"/>
                        <display value="{$lognam}"/>
                    </source>
                    <target>
                        <role value="spz-ateam"/>
                        <reference value=""/>
                        <display value="SPZ-Team"/>
                    </target>
                    <reason>
                        <coding>
                            <system value="#order-reason"/>
                            <code value="appointment"/>
                            <display value="Amb. Besuch"/>
                        </coding>
                        <text value="Amb. Besuch"/>
                    </reason>
                    <description value=""/>
                    <comment value=""/>
                    <authority>
                        <reference value="metis/organizations/kikl-spz"/>
                        <display value="SPZ Kinderklinik"/>
                    </authority>
                    <when>
                        <code>
                            <coding>
                                <system value="#order-priority"/>
                                <code value="normal"/>
                                <display value="normal"/>
                            </coding>
                            <text value="normal"/>
                        </code>
                        <schedule>
                            <event value=""/>
                        </schedule>
                    </when>
                    { r-order:reopenDetail($od) }
                    <status value="active"/>
                </Order>
    return
        r-order:putOrderXML(document {$new},$realm,$loguid, $lognam)
};

(:~
 : PUT: nabu/encounters/{$cid}/status/{$status}
 : Update an existing encounter.
 :
 : 
 : @return <response>
 :)
declare
    %rest:POST
    %rest:path("nabu/orders/{$oid}/details/{$did}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("status", "{$new-status}")
    %rest:query-param("outcome", "{$outcome}","")
    %rest:produces("application/xml", "text/xml")
function r-order:updateStatus(
      $oid as xs:string*
    , $did as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $new-status as xs:string*
    , $outcome as xs:string*
    ) as item()
{

    let $order  := collection($r-order:base)/fhir:Order[fhir:id[@value = $oid]]
    let $lll  := util:log-app('TRACE','apps.nabu',$new-status)
    return
    try {
        if (count($order) = 1 and r-order:isValid($new-status))
        then   
            let $upd := r-order:doUpdateMove($order,$did,$new-status)
            return
                r-order:rest-response(200, 'order status updated.')
        else
            r-order:rest-response(404, 'order status not updated.') 
    } catch * {
        r-order:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-order:doUpdateMove(
      $order
    , $did as xs:string*
    , $new-status as xs:string
    ) as xs:boolean
{
    let $old-status := $order/fhir:detail[@id=$did]/fhir:status/@value/string()
    return
        if ($old-status)
        then
            if ($old-status=$new-status)
            then false()
            else
                let $gstatus := requestgrp:checkGroupStatus($order/fhir:detail,$old-status,$did,$new-status)
                let $upd := system:as-user('vdba', 'kikl823!',
                    (
                      update replace $order/fhir:detail[@id=$did]/fhir:status/@value with $new-status
                    , update replace $order/fhir:status/@value with $gstatus
                    ))
                return true()
        else
            false()
};

declare %private function r-order:isValid($status as xs:string) as xs:boolean
{
    $status = $r-order:valid-status
};
