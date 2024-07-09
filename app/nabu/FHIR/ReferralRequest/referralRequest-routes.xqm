xquery version "3.0";

(: 
 : ReferralRequest should replace Order at some timepoint
 : @author Peter Herkenrath
 : @version 1.0
 : @see http://www.enahar.org
 :
 :)
module namespace r-referral-req = "http://enahar.org/exist/restxq/nabu/referral-reqs";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace date   = "http://enahar.org/exist/apps/nabu/date"      at "../../modules/date.xqm";
import module namespace r-user = "http://enahar.org/exist/restxq/metis/users"  at "/db/apps/metis/FHIR/user/user-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http   = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-referral-req:referral-reqs := 'nabu/referral-reqs/';
declare variable $r-referral-req:practitioners := 'metis/practitioners/';
declare variable $r-referral-req:patients      := 'nabu/patients/';
declare variable $r-referral-req:schedules     := 'enahar/schedules/';

declare variable $r-referral-req:coll         := collection('/db/apps/nabuData/data/FHIR/ReferralRequests');
declare variable $r-referral-req:history      := concat($config:history-data,'/ReferralRequests');

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
 : @param $referral-req
 : @return ()
 :)
declare function r-referral-req:moveToHistory(
      $referral-reqs as element()*
    ) 
{
    for $o in $referral-reqs
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-referral-req:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-referral-req:history, $nameHistory)
                    )
        )
};

declare function r-referral-req:mapSpec($o as item()) as item()
{
  let $base := $o/fhir:*[not(self::detail)]
  let $details := $o/fhir:detail
  return
    <ReferralRequest xmlns="http://hl7.org/fhir" xml:id="{$o/@xml:id/string()}">
        { $base }
        {
            for $d at $id in $details
            let $start:= $d/fhir:search/fhir:start/@value/string()
            let $end  := $d/fhir:search/fhir:end/@value/string()
            let $begin:= try {
                    format-dateTime($start,'[Y0001]-[M01]-[D01]')
                } catch * {
                    $start
                }
            let $uuid := util:uuid()
            return
                if (exists($d/duration)) (: old format :)
                then
                    let $db := $d/fhir:*[not(self::duration)][not(self::proposal)][not(self::search)]
                    let $dur  := $d/duration/@value/string()
                    let $prop := $d/proposal/display/@value/string()
                    let $acq  := switch($d/proposal/acq/@value)
                        case 'tentative' return 'closed'
                        case 'accepted'  return 'closed'
                        default return $d/proposal/acq/@value/string()
                    return
                        <detail id="{$uuid}">
                            { $db }
                            <proposal>
                                <start value="{$start}"/>
                                <end value="{$end}"/>
                                <acq value="{$acq}"/>
                            </proposal>
                            <spec>
                                <combination value="{$id}"/>
                                <interdisciplinary value="false"/>
                                <begin value="{$begin}"/>
                                <daytime value="any"/>
                                <dow value="any"/>
                                <duration value="{$dur}"/>
                            </spec>
                        </detail>
                else
                    let $db := $d/fhir:*[not(self::proposal)][not(self::spec)][not(self::search)]
                    let $prop := $d/proposal/display/@value/string()
                    let $acq  := switch($d/proposal/acq/@value)
                        case 'tentative' return 'closed'
                        case 'accepted'  return 'closed'
                        default return $d/proposal/acq/@value/string()
                    return
                        if ( $d/fhir:spec/fhir:begin)
                        then
                            $d
                        else 
                            let $spec := $d/fhir:spec
                            let $comb := $spec/fhir:combination/@value/string()
                            let $idb  := $spec/fhir:interdisciplinary/@value/string()
                            let $dur  := $spec/fhir:duration/@value/string()
                            return
                            <detail id="{$uuid}">
                                { $db }
                                <spec>
                                    <combination value="{$comb}"/>
                                    <interdisciplinary value="{$idb}"/>
                                    <begin value="{$begin}"/>
                                    <daytime value="any"/>
                                    <dow value="any"/>
                                    <duration value="{$dur}"/>
                                </spec>
                                <proposal>
                                    <start value="{$start}"/>
                                    <end value="{$end}"/>
                                    <acq value="{$acq}"/>
                                </proposal>
                            </detail>
        }
    </ReferralRequest>
};

declare %private function r-referral-req:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};


declare %private function r-referral-req:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <referral-reqs xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </referral-reqs>
};

(:~
 : GET: nabu/referral-reqs/{$id}
 : List referral-req with id.
 : 
 : @return  <ReferralRequest>...</ReferralRequest>
 :)
declare
    %rest:GET
    %rest:path("nabu/referral-reqs/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-referral-req:referral-reqByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $ods := $r-referral-req:coll/ReferralRequest[fhir:id[@value=$id]]
    return
        if (count($ods)=1) then
            $ods
        else r-referral-req:rest-response(404, concat('ReferralRequest with ID: ',$id, ' error. Ask the Admin.'))
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
declare function r-referral-req:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-referral-req:coll/fhir:ReferralRequest[fhir:id[@value=$id]]
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
 : GET: /nabu/referral-reqs/{$id}/_history
 : get referral-req history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  referral-req bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/referral-reqs/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-referral-req:referral-reqHistoryByID($id as xs:string*,
        $start as xs:string*, $length as xs:string*)
{
    let $coll  := $r-referral-req:coll | collection($r-referral-req:history)
    let $hits  := $coll/fhir:ReferralRequest[fhir:id[@value=$id]]
    return
        r-referral-req:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/referral-req/{$id}/_history/{$vid}
 : get referral-req history with id $id and version $vid
 : 
 : @param $id referral-req id
 : @param $vid version id
 : 
 : @return  referral-req bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/referral-reqs/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-referral-req:referral-reqVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll  := $r-referral-req:coll | collection($r-referral-req:history)
    let $hits  := $coll/fhir:ReferralRequest[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-referral-req:prepareHistoryBundle($id, $hits)
};

declare %private function r-referral-req:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/referral-reqs/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/nabu"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name value="eNahar FHIR Server"/>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/fhir:meta/fhir:versionId/@value)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/nabu/referral-reqs/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/referral-reqs/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : 
 : List referral-req with id.
 : 
 : @return  <ReferralRequest>...</ReferralRequest>
 :)
declare
function r-referral-req:teamTasks($realm as xs:string, $loguid as xs:string) as item()
{
    <ok/>
};

(:~
 : 
 : List referral-req with id.
 : 
 : @return  <ReferralRequest>...</ReferralRequest>
 :)
declare
function r-referral-req:actionTasks($realm as xs:string, $loguid as xs:string, $type as xs:string) as item()
{
    <ok/>
};

(:~
 : Composition Search parameter from FHIR 0.4
 : authority	reference	If required by policy	ReferralRequest.authority
 : date         date	When the referral-req was made	ReferralRequest.date
 : detail	    reference	What action is being referral-reqed	ReferralRequest.detail
 : patient	    reference	Patient this referral-req is about	 (same as subject!)
 : source	    reference	Who initiated the referral-req	ReferralRequest.source
 : subject	    reference	Patient this referral-req is about	ReferralRequest.subject
 : target	    reference	Who is intended to fulfill the referral-req	ReferralRequest.target (Device, Organization, Practitioner)
 : when	date	A formal schedule	ReferralRequest.when.schedule
 : when_code	token	Code specifies when request should be done. The code may simply be a priority code
 :)
(:~
 : GET: nabu/referral-reqs?start=1&length=10&status=...
 : List referral-reqs for user and return them as XML.
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
 : @return  bundle <ReferralRequest/>
 :)
declare
    %rest:GET
    %rest:path("nabu/referral-reqs")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}",  "1")
    %rest:query-param("length", "{$length}", "10")
    %rest:query-param("subject","{$subject}", "")
    %rest:query-param("source", "{$source}", "")
    %rest:query-param("target", "{$target}", "")
    %rest:query-param("reason", "{$reason}", "appointment")
    %rest:query-param("status", "{$status}", "assigned")
    %rest:query-param("actor",   "{$actor}", "")
    %rest:query-param("service", "{$role}",  "")
    %rest:query-param("rangeStart", "{$rangeStart}", "1994-06-01T08:00:00")
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "2021-04-01T19:00:00")
    %rest:query-param("tag",     "{$tag}",    "spz")
    %rest:query-param("_sort",   "{$sortBy}", "date:desc")
    %rest:query-param("acq",  "{$acq}", "")
    %rest:produces("application/xml", "text/xml")
function r-referral-req:referral-reqs(
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
    , $rangeStart as xs:string*, $rangeEnd as xs:string*
    , $tag as xs:string*
    , $sortBy as xs:string*
    , $acq as xs:string*
    ) as item()
{
    let $aref    := concat($r-referral-req:practitioners, $actor)
    let $sref    := concat($r-referral-req:practitioners, $source)
    let $tref    := concat($r-referral-req:practitioners, $target)
    (: TODO: remove hack for wrong patient path in tickets :)
    let $pref    := (concat($r-referral-req:patients, $subject),concat('metis/patients/',$subject))
    let $hits   := $r-referral-req:coll/ReferralRequest[fhir:extension/fhir:status/fhir:coding/fhir:code/@value=$status][fhir:reason/fhir:coding/fhir:code/@value=$reason]
    let $hits0  := $hits
    let $hits1  := if ($actor='')
                    then $hits0
                    else if ($acq='')
                        then $hits0[fhir:detail/fhir:actor[fhir:reference[@value=$aref]]]
                        else $hits0[fhir:detail/fhir:actor[fhir:reference[@value=$aref]]][fhir:detail/fhir:proposal/fhir:acq/@value=$acq]
    let $hits2  := if ($role='')
                    then $hits1
                    else if ($acq='')
                        then $hits0[fhir:detail[fhir:actor/fhir:role/@value=$role]]
                        else $hits0[fhir:detail[fhir:actor/fhir:role/@value=$role][fhir:proposal/fhir:acq/@value=$acq]]
    let $hits3  := if ($source='')
                    then $hits2
                    else $hits2[fhir:source[fhir:reference/@value=$sref]]
    let $hits4  := if ($target='')
                    then $hits3
                    else $hits3[fhir:target[fhir:reference/@value=$tref]] |
                         $hits3[fhir:target[fhir:reference/@value='']] (: [fhir:target/fhir:role/@value=$role]  target role only :)
    let $valid  := if ($subject='')
                    then $hits4[fhir:date[@value>$rangeStart]][fhir:date[@value<$rangeEnd]]
                    else $hits4[fhir:subject[fhir:reference[@value = $pref]]][fhir:date[@value>$rangeStart]][fhir:date[@value<$rangeEnd]]
    let $sorted-hits := 
        switch ($sortBy)
        case "when-schedule" return (: due date :)
            for $e in $valid
            order by $e/when/schedule/event/@value/string() collation "?lang=de-DE"
            return
                $e
        case "when-code" return (: priority :)
let $lll := util:log-app('DEBUG','nabu',concat('ReferralRequest Prio: ' , count($valid[when/code/coding/code/@value=("urgent","high")])))
return
            (
                $valid[when/code/coding/code/@value="urgent"]
            ,   $valid[when/code/coding/code/@value="high"]
            )
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
        r-referral-req:prepareResult($sorted-hits, $start, $length)
};

(:~
 : GET: nabu/referral-reqsBySubject?status=...
 : List referral-reqs for user and return them as XML.
 : 
 : @param   $subject reference
 : @param   $status

 : @return  bundle <ReferralRequest/>
 :)
declare
    %rest:GET
    %rest:path("nabu/referral-reqsBySubject/{$subject}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("status", "{$status}", "")
    %rest:produces("application/xml", "text/xml")
function r-referral-req:referral-reqBySubject(
          $subject as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $status as xs:string*
    ) as item()
{
    (: TODO: remove hack for wrong patient path in tickets :)
    let $pref    := (concat($r-referral-req:patients, $subject),concat('metis/patients/',$subject))
    let $hits   := if ($status = "")
        then $r-referral-req:coll/ReferralRequest[fhir:subject[fhir:reference[@value=$pref]]]
        else $r-referral-req:coll/ReferralRequest[fhir:subject[fhir:reference[@value=$pref]]][fhir:extension/fhir:status/fhir:coding/fhir:code/@value=$status]
    let $sorted-hits := 
            for $e in $hits
            order by $e/fhir:date/@value/string() 
            return
                $e
    return
        r-referral-req:prepareResult($sorted-hits, '1', '*')
};

(:~
 : POST: nabu/referral-reqs
 : Update an existing referral-req because an tentative appointment was rejected
 : 
 : @param $content appointment ressource
 : @return <response>
 : 
 : TODO set ./*:when/*:code/*:coding/*:code/@value='urgent'
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/referral-reqs")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}", '')
    %rest:query-param("lognam", "{$lognam}", 'anon')
    %rest:produces("application/xml", "text/xml")
function r-referral-req:reopenReferralRequest(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $app   := $content/Appointment
    (: get referral-req reference and detail reference :)
    let $oref  := tokenize(substring-after($app/referral-req/reference/@value,$r-referral-req:referral-reqs),'\?')
    let $odref := if ($oref[2])
        then substring-after($oref[2],'detail=')
        else ''
    let $oo    := $r-referral-req:coll/fhir:ReferralRequest[fhir:id[@value=$oref[1]]]
    let $uuid  := $oo/@xml:id
    let $base  := $oo/fhir:*[not(self::extension)][not(self::detail)]
    let $details := $oo/fhir:detail
    let $data := 
        <ReferralRequest xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            { $base }
            { r-referral-req:reopenDetails($details,$odref) }
            <extension url="#referral-req-status">
                <status>
                    <coding>
                        <system value="#referral-req-status"/>
                        <code value="assigned"/>
                        <display value="wieder geöffnet"/>
                    </coding>
                    <text value="wieder geöffnet"/>
                </status>
            </extension>
        </ReferralRequest>
    return
        r-referral-req:putReferralRequestXML(document {$data},$realm,$loguid, $lognam)
};

declare %private function r-referral-req:reopenDetails($details, $odref) as item()*
{
    for $d in $details
    return
        if ($d/@id=$odref)
        then r-referral-req:reopenDetail($d)
        else $d
};

declare %private function r-referral-req:reopenDetail($d) as item()*
{
    let $db := $d/fhir:*[not(self::proposal)]
    return
        <detail id="{$d/@id/string()}" xmlns="http://hl7.org/fhir">
            { $db }
            <proposal>
                <start value=""/>
                <end value=""/>
                <acq value="open"/>
            </proposal>
        </detail>
};

(:~
 : PUT: nabu/referral-reqs
 : Update an existing referral-req or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/referral-reqs")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}", '')
    %rest:query-param("lognam", "{$lognam}", 'anon')
    %rest:produces("application/xml", "text/xml")
function r-referral-req:putReferralRequestXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew := not($content/ReferralRequest/@xml:id)
    let $oid   := if ($isNew)
        then concat("o-", util:uuid())
        else 
            let $id := $content/ReferralRequest/id/@value/string()
            let $referral-req := $r-referral-req:coll/fhir:ReferralRequest[fhir:id[@value = $id]]
            let $move := r-referral-req:moveToHistory($referral-req)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/ReferralRequest/meta/versionId/@value/string()) + 1
    let $base := $content/ReferralRequest/fhir:*[not(
                                               self::id
                                            or self::meta
                                            )]
    let $meta := $content//meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $when := $content//when
    let $uuid := if ($isNew) 
        then $oid
        else concat("o-", util:uuid())
    let $data := 
        <ReferralRequest xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$oid}"/>
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
            { r-referral-req:mapWhen($when, $base) }
            { $base }
        </ReferralRequest>
        
(: 
    let $lll := util:log-system-out($data)
:)
    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:nabu-referral-reqs, $file, $data)
            , sm:chmod(xs:anyURI($config:nabu-referral-reqs || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:nabu-referral-reqs || '/' || $file), $config:data-group)))
        return
            r-referral-req:rest-response(200, 'referral-req sucessfully stored.') 
    } catch * {
        r-referral-req:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-referral-req:mapWhen($when, $base) as item()
{
    let $code := $when/code
    let $due := if($base[extension[@url="#referral-req-status"]//code/@value='resolved'])
        then $when//event/@value/string()
        else if ($when//start) (: backwards compatibility issue, old task structure :)
            then r-referral-req:mapDate($when//start/@value)
            else if ($base/proposal)   (: regular referral-req :)
                then r-referral-req:calcNextDueDate($base)
                else r-referral-req:mapDate($when/schedule/event/@value) (: probably task :)
    return
        <when xmlns="http://hl7.org/fhir">
            { $code }
            <schedule>
                <event value="{$due}"/>
            </schedule>
        </when>
};

declare %private function r-referral-req:mapDate($d as xs:string*) as xs:dateTime
{
    try {
        date:easyDateTime($d)
    } catch * {
        adjust-dateTime-to-timezone(current-dateTime(),())
    }
};

declare %private function r-referral-req:calcNextDueDate($base as item()*) as xs:dateTime
{
    try {
        let $due := for $d in distinct-values($base[proposal/acq/@value='open']/spec/begin/@value)
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

(:~
 : POST: nabu/app2referral-req
 : Use an existing apppointment to setup a new referral-req
 : 
 : @param $content appointment ressource
 : @return <response>
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/app2referral-req")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}", '')
    %rest:query-param("lognam", "{$lognam}", 'anon')
    %rest:produces("application/xml", "text/xml")
function r-referral-req:newReferralRequestFromAppointment(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $app   := $content/Appointment
    (: get referral-req reference and detail reference :)
    let $oref  := tokenize(substring-after($app/referral-req/reference/@value,$r-referral-req:referral-reqs),'\?')
    let $odref := if ($oref[2])
        then substring-after($oref[2],'detail=')
        else ''
let $lll := util:log-app("DEBUG","nabu", $oref[1])
    let $oo    := $r-referral-req:coll/ReferralRequest[fhir:id/@value=$oref[1]]
    let $od := if ($odref='')
        then $oo/fhir:detail[fhir:actor/fhir:reference/@value=$app/fhir:participant[fhir:type/fhir:coding/fhir:code/@value!='patient']/fhir:actor/fhir:reference/@value]
        else $oo/fhir:detail[@id=$odref]
let $lll := util:log-app("DEBUG","nabu", $od)
    let $pref  := $oo//fhir:subject/fhir:reference/@value/string()
    let $pdis  := $oo//fhir:subject/fhir:display/@value/string()

    let $new := 
                <ReferralRequest>
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
                            <system value="#referral-req-reason"/>
                            <code value="appointment"/>
                            <display value="Amb. Besuch"/>
                        </coding>
                        <text value="Amb. Besuch"/>
                    </reason>
                    <authority>
                        <reference value="metis/organizations/kikl-spz"/>
                        <display value="SPZ Kinderklinik"/>
                    </authority>
                    <when>
                        <code>
                            <coding>
                                <system value="#referral-req-priority"/>
                                <code value="normal"/>
                                <display value="normal"/>
                            </coding>
                            <text value="normal"/>
                        </code>
                        <schedule>
                            <event value=""/>
                        </schedule>
                    </when>
                    { r-referral-req:reopenDetail($od) }
                    <extension url="#referral-req-status">
                        <status>
                            <coding>
                                <system value="#referral-req-status"/>
                                <code value="assigned"/>
                                <display value="zugewiesen"/>
                            </coding>
                            <text value="zugewiesen"/>
                        </status>
                    </extension>
                </ReferralRequest>
    return
        r-referral-req:putReferralRequestXML(document {$new},$realm,$loguid, $lognam)
};
