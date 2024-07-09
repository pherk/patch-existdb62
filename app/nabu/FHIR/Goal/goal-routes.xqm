xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-goal = "http://enahar.org/exist/restxq/nabu/goals";

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

declare variable $r-goal:nabu-goals := "/db/apps/nabuCom/data/Goals";
declare variable $r-goal:coll := collection($r-goal:nabu-goals);
declare variable $r-goal:history     := concat($config:history-data,'/Goals');
declare variable $r-goal:data-perms    := "rwxrw-r--";
declare variable $r-goal:data-group    := "spz";

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
declare function r-goal:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-goal:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-goal:history, $nameHistory)
                    )
        )
};

declare %private function r-goal:prepareResult($hits, $start, $length, $format, $sort)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits :=
        switch ($sort)
        case 'startDate_asc' return
            for $c in $hits
            order by $c/fhir:startDate/@value/string() ascending
            return
                switch($format)
                case 'code' return
                            <Goal xmlns="http://hl7.org/fhir">
                                <selected>false</selected>
                                {$c/fhir:id}
                                {$c/fhir:description}
                            </Goal>
                default return $c
        case 'startDate_desc' return
            for $c in $hits
            order by $c/fhir:startDate/@value/string() descending
            return
                switch($format)
                case 'code' return
                            <Goal xmlns="http://hl7.org/fhir">
                                <selected>false</selected>
                                {$c/fhir:id}
                                {$c/fhir:description}
                            </Goal>
                default return $c
        case 'statusDate' return
            for $c in $hits
            order by $c/fhir:statusDate/@value/string()
            return
                $c
        case 'priority' return
            for $c in $hits
            order by $c/fhir:priority/fhir:coding[fhir:system/@value="http://hl7.org/fhir/ValueSet/goal-priority"]/fhir:code/@value/string()
            return
                $c
        case 'subject' return
            for $c in $hits
            order by $c/fhir:subject/fhir:display/@value/string()
            return
                $c
        default return $hits
    return
        <goals xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </goals>
};


declare %private function r-goal:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/goals/{$id}
 : List goal with id.
 : 
 : @return  <Goal>...</Goal>
 :)
declare
    %rest:GET
    %rest:path("nabu/goals/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-goal:goalByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $goals := $r-goal:coll/fhir:Goal[fhir:id[@value = $id]]
    return
        if (count($goals)=1)
        then $goals
        else if (count($goals)>1)
        then r-goal:rest-response(404, concat('Goal with ID: ',$id, ' too many. Ask the Admin.'))
        else r-goal:rest-response(404, concat('Goal with ID: ',$id, ' not found. Ask the Admin.'))
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
declare function r-goal:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-goal:coll/fhir:Goal[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:subject/fhir:reference/@value with concat('nabu/patients/',$pid)
                , update value $res/fhir:subject/fhir:display/@value with $pnam
                , update value $res/fhir:meta/fhir:extension/fhir:valueReference/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension/fhir:valueReference/fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
        else ()
};
(:~
 : update lifecycleStatus and achievementStatus
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $lifecycleStatus
 : @param $achievementStatus
 : 
 : @return 
 :)
declare 
    %rest:POST
    %rest:path("/nabu/goals/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("lifecycleStatus",  "{$lcs}", "")
    %rest:query-param("achievementStatus", "{$as}", "")
    %rest:query-param("statusDate", "{$sd}", "")
    %rest:produces("application/xml", "text/xml")
function r-goal:updateTwoStatus(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $lcs as xs:string*
    , $as as xs:string*
    , $sd as xs:string*
    ) 
{
    let $asd := switch($as)
        case 'in-progress' return 'in Arbeit'
        case 'improvement' return 'Besserung'
        case 'worsening' return 'Verschlechterung'
        case 'achieved' return 'erreicht'
        case 'sustaining' return 'nachhaltig erreicht'
        case 'no-change' return 'unverändert'
        case 'no-progress' return 'ohne Fortschritt'
        case 'not-attainable' return 'nicht erreichbar'
        case 'not-achieved' return 'nicht erreicht'
        default return 'in Arbeit'

    let $res := $r-goal:coll/fhir:Goal[fhir:id[@value=$id]]
    return
        if (count($res)=1 and r-goal:validLifecycleStatus($lcs) and r-goal:validAchievementStatus($as))
        then    

            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:lifecycleStatus/@value with $lcs
                , update value $res/fhir:achievementStatus/fhir:coding[fhir:system/@value="http://hl7.org/fhir/ValueSet/goal-achievement"]/fhir:code/@value with $as
                , update value $res/fhir:achievementStatus/fhir:coding[fhir:system/@value="http://hl7.org/fhir/ValueSet/goal-achievement"]/fhir:display/@value with $asd
                , update value $res/fhir:achievementStatus/fhir:text/@value with $asd
                , if ($sd="") then ()
                  else update value $res/fhir:statusDate/@value with $sd
                , update value $res/fhir:statusReason/@value with $asd
                , update value $res/fhir:meta/fhir:extension/fhir:valueReference/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension/fhir:valueReference/fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
        else let $lll := util:log-app("ERROR","apps.nabu",$res/fhir:subject)
             let $lll := util:log-app("ERROR","apps.nabu",$lcs)
             let $lll := util:log-app("ERROR","apps.nabu",$as)
            return
                'error'
};

declare %private function r-goal:validLifecycleStatus($lcs)
{
    $lcs=(
          'proposed' 
        , 'planned'
        , 'accepted'
        , 'active'
        , 'on-hold'
        , 'completed'
        , 'cancelled'
        , 'entered-in-error'
        , 'rejected'
        )
};

declare %private function r-goal:validAchievementStatus($as)
{
    $as=(
          'in-progress'
        , 'improving'
        , 'worsening'
        , 'no-change'
        , 'achieved'
        , 'sustaining'
        , 'not-achieved'
        , 'no-progress'
        , 'not-attainable'
        )
};
(:~
 : GET: /nabu/goals/{$id}/_history
 : get goal history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  goal bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/goals/{$id}/_history")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-goal:goalHistoryByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $coll := $r-goal:coll | collection($r-goal:history)
    let $hits  := $coll/fhir:Goal[fhir:id[@value=$id]]
    return
        r-goal:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/goal/{$id}/_history/{$vid}
 : get goal history with id $id and version $vid
 : 
 : @param $id goal id
 : @param $vid version id
 : 
 : @return  goal bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/goals/{$id}/_history/{$vid}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-goal:goalVersionByID(
      $id as xs:string*
    , $vid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $coll := $r-goal:coll | collection($r-goal:history)
    let $hits := $coll/fhir:Goal[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-goal:prepareHistoryBundle($id, $hits)
};

declare %private function r-goal:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/goals/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/goals/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}</id>
                        <updated>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</updated>
                        <published>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/goals/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.9.0
 : category	token	E.g. Treatment, dietary, behavioral, etc.	Goal.category	
 : identifier	token	External Ids for this goal	Goal.identifier	26 Resources
 : patient	reference	Who this goal is intended for	Goal.subject
   (Patient)	31 Resources
 : start-date	date	When goal pursuit begins	Goal.startDate	
 : lifecycleStatus	token	proposed | accepted | active | on-hold | cancelled | entered-in-error | rejected	Goal.lifecycleStatus
 : subject	reference	Who this goal is intended for	Goal.subject
   (Group, Organization, Patient)	
 : target-date	date	Reach goal on or before	Goal.target.dueDate	
 :)

(:~
 : GET: nabu/goals?start=1&length=10&lifecycleStatus=...
 : List goals for subject
 : 
 : @param   $start
 : @param   $length
 : @param   $sender        ref
 : @param   $rangeStart    dateTime
 : @param   $rangeEnd      dateTime
 : @param   $subject       ref
 : @param   $lifecycleStatus        
 : @param   $format        ('full', 'wrapper', 'payload', 'count')
 : 
 : @return  bundle <goals/>
 : 
 : @since v1.0
 :)
declare
    %rest:GET
    %rest:path("nabu/goals")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("expressedBy",  "{$expressedBy}", "")
    %rest:query-param("rangeStart", "{$rangeStart}", "")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("lifecycleStatus",  "{$lifecycleStatus}", "")
    %rest:query-param("achievementStatus",  "{$achievementStatus}", "")
    %rest:query-param("category",  "{$category}", "")
    %rest:query-param("description",  "{$description}", "")
    %rest:query-param("_sort", "{$sort}", "startDate_up")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-goal:goalsXML(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    , $expressedBy as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    , $subject as xs:string*
    , $lifecycleStatus as xs:string*
    , $achievementStatus as xs:string*
    , $category as xs:string*
    , $description as xs:string*
    , $sort as xs:string*
    , $format as xs:string*
    ) as item()
{

    let $lifecycleStatus1 := switch($lifecycleStatus)
        case 'all'           return ("proposed","planned","accepted","active","on-hold","completed","cancelled","rejected")
        case 'active-only'   return ("proposed","planned","accepted","active","on-hold")
        case 'finished-only' return ("completed","cancelled","rejected")        
        default return $lifecycleStatus
    let $aref := "metis/practitioners/" || $expressedBy
    let $sref := "nabu/patients/" || $subject
    let $lll := util:log-app('TRACE','apps.nabu',$lognam)
    let $lll := util:log-app('TRACE','apps.nabu',$subject)
    let $lll := util:log-app('TRACE','apps.nabu',$expressedBy)
    let $lll := util:log-app('TRACE','apps.nabu',$category)
    let $lll := util:log-app('TRACE','apps.nabu',$lifecycleStatus)
    let $lll := util:log-app('TRACE','apps.nabu',$achievementStatus)
    let $lll := util:log-app('TRACE','apps.nabu',$description)
    let $matched0 := 
        if ($expressedBy="" and $subject="")
        then $r-goal:coll/fhir:Goal
        else if ($subject="")
        then $r-goal:coll/fhir:Goal[fhir:expressedBy[fhir:reference/@value=$aref]]
        else if ($expressedBy="")
        then $r-goal:coll/fhir:Goal[fhir:subject[fhir:reference/@value=$sref]]
        else $r-goal:coll/fhir:Goal[fhir:subject[fhir:reference/@value=$sref]][fhir:expressedBy[fhir:reference/@value=$aref]]
    let $matched1 := if ($category="")
        then $matched0
        else $matched0/../fhir:Goal[fhir:category/fhir:coding[fhir:code/@value=$category]]
    let $matched2 := if ($lifecycleStatus="")
        then $matched1
        else $matched1/../fhir:Goal[fhir:lifecycleStatus[@value=$lifecycleStatus1]]
    let $matched3 := if ($achievementStatus="")
        then $matched2
        else $matched2/../fhir:Goal[fhir:achievementStatus/fhir:coding[fhir:code/@value=$achievementStatus]]
    let $matched4 := if ($description="")
        then $matched3
        else if ($description=":missing")
        then $matched3/../fhir:Goal[fhir:description/fhir:coding[fhir:code/@value=""]]
        else $matched3/../fhir:Goal[fhir:description/fhir:coding[fhir:code/@value=$description]]
    return
        switch ($format)
        case 'count' return <goals><count>{count($matched3)}</count></goals> 
        default return 
            r-goal:prepareResult($matched4, $start, $length, $format, $sort)
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
 : PUT: nabu/goals
 : Update an existing goal or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/goals")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-goal:putGoalXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    (:
let $lll := util:log-app('TRACE','apps.nabu',$content)
:)
    let $content := if($content/fhir:Goal)
        then $content
        else if ($content/*:Goal)
        then document { local:addNamespaceToXML($content/*:Goal,"http://hl7.org/fhir") }
        else let $lll := util:log-app('TRACE','apps.nabu',$content)
            return
                error()
    let $isNew := not($content/fhir:Goal/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:Goal/fhir:id/@value/string()
            let $goals := $r-goal:coll/fhir:Goal[fhir:id[@value = $id]]
            let $move := r-goal:moveToHistory($goals)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Goal/fhir:meta/fhir:versionId/@value/string()) + 1
    let $base := $content/fhir:Goal/fhir:*[not(
                                               self::meta
                                            or self::id
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
        <Goal xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </Goal>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-goal:nabu-goals, $file, $data)
            , sm:chmod(xs:anyURI($r-goal:nabu-goals || '/' || $file), $r-goal:data-perms)
            , sm:chgrp(xs:anyURI($r-goal:nabu-goals || '/' || $file), $r-goal:data-group)))
        return
            r-goal:rest-response(200, 'goal sucessfully stored.') 
    } catch * {
        r-goal:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

