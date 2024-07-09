xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 : 
 : CareTeam participant incongruent to other participant properties e.g. Encounter
 : mapping is done in computeActorUpdate
 :)
module namespace r-careteam = "http://enahar.org/exist/restxq/nabu/careteams";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";
import module namespace r-eoc = "http://enahar.org/exist/restxq/nabu/eocs"    at "../../FHIR/EpisodeOfCare/episodeofcare-routes.xqm";

declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-careteam:nabu-careteams := "/db/apps/nabuCom/data/CareTeams";
declare variable $r-careteam:coll := collection($r-careteam:nabu-careteams);
declare variable $r-careteam:history     := concat($config:history-data,'/CareTeams');
declare variable $r-careteam:data-perms    := "rwxrw-r--";
declare variable $r-careteam:data-group    := "spz";

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
declare function r-careteam:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-careteam:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-careteam:history, $nameHistory)
                    )
        )
};

declare %private function r-careteam:prepareResult($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:period/fhir:start/@value/string() descending
            return
                $c
    return
        <careteams xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </careteams>
};


declare %private function r-careteam:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/careteams/{$id}
 : List careteam with id.
 : 
 : @return  <CareTeam>...</CareTeam>
 :)
declare
    %rest:GET
    %rest:path("nabu/careteams/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:produces("application/xml", "text/xml")
function r-careteam:careteamByID($id as xs:string*, $realm as xs:string*, $loguid as xs:string*) as item()
{
    let $careteams := $r-careteam:coll/CareTeam[fhir:id[@value = $pid]]
    return
        if (count($careteams)=1)
        then $careteams
        else if (count($careteams)>1)
        then r-careteam:rest-response(404, concat('CareTeam with ID: ',$id, ' too many. Ask the Admin.'))
        else r-careteam:rest-response(404, concat('CareTeam with ID: ',$id, ' not found. Ask the Admin.'))
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
declare function r-careteam:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-careteam:coll/fhir:CareTeam[fhir:id[@value=$id]]
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
 : update actor
 : 
 : @param $content  participant property of Encounter
 : @param $realm
 : @param $loguid
 : @param $sid
 : 
 : @return 
 : @since v0.8.45
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/careteams")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("subject", "{$sid}")
    %rest:produces("application/xml", "text/xml")
function r-careteam:updateActor(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $sid as xs:string*
    ) 
{
    let $lll := util:log-app('TRACE','apps.nabu',$content)
    let $cts := r-careteam:careteamsXML($realm,$loguid,$lognam, $sid,'active','full')/fhir:CareTeam
    let $lll := if ($cts)
        then ()
        else let $lll1 := util:log-app('ERROR','apps.nabu',concat('no active careteam: ',$sid))
             return ()
    let $actor := $content/fhir:participant (: from Encounter :)
    let $lll := util:log-app('TRACE','apps.nabu',$actor)
    let $lll := util:log-app('TRACE','apps.nabu',$cts)
    let $res := $r-careteam:coll/fhir:CareTeam[fhir:id[@value=$cts/fhir:id/@value]] (: get real node :)
    let $lll := util:log-app('TRACE','apps.nabu',$res)
    let $update := r-careteam:computeActorUpdate($res,$actor)
    let $lll := util:log-app('TRACE','apps.nabu',$update)
    return
        if ($update/fhir:old)
        then
            (:
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:participant[fhir:member/fhir:reference[@value=$update/fhir:actor]]/fhir:period/fhir:end/@value with $update/fhir:encdate/string()
                , update value $res/fhir:lastModifiedBy/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:lastModifiedBy/fhir:display/@value with $lognam
                , update value $res/fhir:lastModified/@value with current-dateTime()
                ))
                :)
            let $meta := $res/fhir:meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
            let $part := $res/fhir:participant[fhir:member/fhir:reference[@value=$update/fhir:actor]]
            let $other:= $res/fhir:participant[not(fhir:member/fhir:reference[@value=$update/fhir:actor])]
            let $pupd := <participant xmlns="http://hl7.org/fhir">
                           {$part/fhir:role}
                           <period xmlns="http://hl7.org/fhir">
                               <start value="{$part/fhir:period/fhir:start/@value}"/>
                               <end value="{$update/fhir:encdate/string()}"/>
                            </period>
                           {$part/fhir:member}
                         </participant>
            let $ct :=  <CareTeam xmlns="http://hl7.org/fhir" xml:id="{$res/@xml:id}">
                            {$res/fhir:id}
                            <meta>
                                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                                    <valueReference>
                                        <reference value="{concat('metis/practitioners/',$loguid)}"/>
                                        <display value="{$lognam}"/>
                                    </valueReference>
                                </extension>
                                {$res/fhir:meta/fhir:versionId}
                                <lastUpdated value="{current-dateTime()}"/>
                                {$meta}
                            </meta>
                            {$res/fhir:identifier}
                            {$res/fhir:status}
                            {$res/fhir:category}
                            {$res/fhir:name}
                            {$res/fhir:subject}
                            <period>
                                {$res/fhir:period/fhir:start}
                                <end value="{current-dateTime()}"/>
                            </period>
                            {$pupd}
                            {$other}
                            {$res/fhir:managingOrganization}
                            {$res/fhir:note}
                        </CareTeam>
        
            let $rupd := r-careteam:putCareTeamXML(document {$ct}, $realm, $loguid, $lognam)
            return ()
        else if ($update/fhir:new)
        then
            let $cm := r-careteam:updateEoC(
                      $realm,$loguid,$lognam
                    , $res/fhir:id/@value/string()
                    , $update/fhir:participant
                    )
            let $meta := $res/fhir:meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
            let $ct :=  <CareTeam xmlns="http://hl7.org/fhir" xml:id="{$res/@xml:id}">
                            {$res/fhir:id}
                            <meta>
                                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                                    <valueReference>
                                        <reference value="{concat('metis/practitioners/',$loguid)}"/>
                                        <display value="{$lognam}"/>
                                    </valueReference>
                                </extension>
                                {$res/fhir:meta/fhir:versionId}
                                <lastUpdated value="{current-dateTime()}"/>
                                {$meta}
                            </meta>
                            {$res/fhir:identifier}
                            {$res/fhir:status}
                            {$res/fhir:category}
                            {$res/fhir:name}
                            {$res/fhir:subject}
                            <period>
                                {$res/fhir:period/fhir:start}
                                <end value="{current-dateTime()}"/>
                            </period>
                            {$update/fhir:participant}
                            {$res/fhir:participant}
                            {$res/fhir:managingOrganization}
                            {$res/fhir:note}
                        </CareTeam>
        
            let $rupd := r-careteam:putCareTeamXML(document {$ct}, $realm, $loguid, $lognam)
            return ()
        else let $lll := util:log-app('ERROR','apps.nabu',$update/fhir:error/string())
            return
                ()
};

declare %private function r-careteam:updateEoC(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $eocid as xs:string*
        , $ctpart as element(fhir:participant)
        )
{
    if ($ctpart/fhir:type/fhir:coding/fhir:code/@value = ('spz-arzt','spz-psych','spz-gbafg','spz-nme','spz-moto','spz-mmc','worktime'))
    then
        let $cmref := $ctpart/fhir:member/fhir:reference/@value
        let $cmdsp := $ctpart/fhir:member/fhir:display/@value
        return
            r-eoc:updateCM($realm, $loguid, $lognam, $eocid, $cmref, $cmdsp)
    else    r-eoc:updateStatus((), $eocid, $realm, $loguid, $lognam, 'active')
};

declare %private function r-careteam:computeActorUpdate(
          $res as element(fhir:CareTeam)?
        , $part as element(fhir:participant)
        ) as element(fhir:update)
{
    if ($res)
    then
        let $lll := util:log-app('TRACE','apps.nabu',$res)
        let $lll := util:log-app('TRACE','apps.nabu',$part)
        let $aref := $part/fhir:individual/fhir:reference/@value/string()
        let $old := $res/fhir:participant[fhir:member/fhir:reference[@value=$aref]]
        return
            if ($old)
            then
                <update xmlns="http://hl7.org/fhir">
                    <old/>
                    <actor>{$aref}</actor>
                    <encdate>{$part/fhir:period/fhir:start/@value/string()}</encdate> 
                </update>
            else
                <update xmlns="http://hl7.org/fhir">
                  <new/>
                  <participant>
                    <role>
                        <coding>
                            <system value="http://eNahar.org/nabu/system#careteam-participant-role"/>
                            { $part/fhir:type/fhir:coding/fhir:* }
                        </coding>
                        { $part/fhir:type/fhir:text }
                    </role>
                    <member>
                        { $part/fhir:actor/fhir:reference }
                        { $part/fhir:actor/fhir:display }
                    </member>
                    { $part/fhir:period }
                  </participant>
                </update>
    else
        <update  xmlns="http://hl7.org/fhir">
            <error>no Careteam</error>
        </update>
};

(:~
 : POST update status
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $lognam
 : @param $status
 : 
 : @return 
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/careteams/{$id}/status/{$status}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-careteam:updateStatus(
      $content as document-node()*
    , $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $status as xs:string*
    ) 
{
    let $res := $r-careteam:coll/fhir:CareTeam[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:status/@value with $status
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
        else ()
};

(:~
 : GET: /nabu/careteams/{$id}/_history
 : get careteam history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  careteam bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/careteams/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-careteam:careteamHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-careteam:coll | collection($r-careteam:history)
    let $hits  := $coll/fhir:CareTeam[fhir:id[@value=$id]]
    return
        r-careteam:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/careteam/{$id}/_history/{$vid}
 : get careteam history with id $id and version $vid
 : 
 : @param $id careteam id
 : @param $vid version id
 : 
 : @return  careteam bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/careteams/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-careteam:careteamVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-careteam:coll | collection($r-careteam:history)
    let $hits  := $coll/fhir:CareTeam[fhir:id[@value=$id]][meta/versionId/@value=$vid]
    return
        r-careteam:prepareHistoryBundle($id, $hits)
};

declare %private function r-careteam:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/careteams/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/careteams/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/careteams/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.0.1
 : category	token	Message category	CareTeam.category
 : encounter	reference	Encounter leading to message	CareTeam.encounter
 : identifier	token	Unique identifier	CareTeam.identifier
 : medium	token	A channel of careteam	CareTeam.medium
 : patient	reference	Focus of message	CareTeam.subject
 : received	date	When received	CareTeam.received
 : recipient	reference	Message recipient	CareTeam.recipient
   (Practitioner, Group, Organization, Device, Patient, RelatedPerson)
 : request	reference	CareTeamRequest producing this message	CareTeam.requestDetail
 : sender	reference	Message sender	CareTeam.sender
   (Practitioner, Organization, Device, Patient, RelatedPerson)
 : sent	date	When sent	CareTeam.sent
 : status	token	in-progress | completed | suspended | rejected | failed	CareTeam.status
 : subject	reference	Focus of message	CareTeam.subject
 :)

(:~
 : GET: nabu/careteams?start=1&length=10&status=...
 : List careteams for subject
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
 : @return  bundle <careteams/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/careteams")
    %rest:query-param("realm",   "{$realm}")
    %rest:query-param("loguid",  "{$loguid}")
    %rest:query-param("lognam",  "{$lognam}")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-careteam:careteamsXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $subject as xs:string*
        , $status as xs:string*
        , $format as xs:string*
        ) as item()
{
    let $sref := "nabu/patients/" || $subject
    let $matched := 
        if ($subject="")
        then $r-careteam:coll/fhir:CareTeam[fhir:status[@value=$status]]
        else $r-careteam:coll/fhir:CareTeam[fhir:subject[fhir:reference/@value=$sref]][fhir:status[@value=$status]]
    return
        switch ($format)
        case 'count' return <careteams><count>{count($matched)}</count></careteams> 
        default return 
            r-careteam:prepareResult($matched, "1", "*", $format)
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
 : PUT: nabu/careteams
 : Update an existing careteam or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/careteams")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-careteam:putCareTeamXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    let $content := if($content/fhir:CareTeam)
        then $content
        else if ($content/*:CareTeam)
        then document { local:addNamespaceToXML($content/*:CareTeam,"http://hl7.org/fhir") }
        else let $lll := util:log-app('TRACE','apps.nabu',$content)
            return
                error()
    let $isNew := not($content/fhir:CareTeam/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/CareTeam/id/@value/string()
            let $careteams := $r-careteam:coll/fhir:CareTeam[fhir:id[@value = $id]]
            let $move := r-careteam:moveToHistory($careteams)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/CareTeam/meta/versionId/@value/string()) + 1
    let $base := $content/CareTeam/fhir:*[not(
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
        <CareTeam xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$eid}"/>
            <meta>
                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                    <valueReference>
                        <reference value="{concat('metis/practitioners/',$loguid)}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                {$meta}
            </meta>
            {$base}
        </CareTeam>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-careteam:nabu-careteams, $file, $data)
            , sm:chmod(xs:anyURI($r-careteam:nabu-careteams || '/' || $file), $r-careteam:data-perms)
            , sm:chgrp(xs:anyURI($r-careteam:nabu-careteams || '/' || $file), $r-careteam:data-group)))
        return
            (
              r-careteam:rest-response(200, 'careteam sucessfully stored.')
            , $data
            )
    } catch * {
        r-careteam:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

