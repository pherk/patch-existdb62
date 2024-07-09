xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-condition = "http://enahar.org/exist/restxq/nabu/conditions";

import module namespace config = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace nutil = "http://enahar.org/exist/apps/nabu/utils"    at "../../modules/utils.xqm";
import module namespace condition = "http://enahar.org/exist/apps/nabu/condition"    at "../../FHIR/Condition/condition.xqm";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei    = "http://www.tei-c.org/ns/1.0";
declare namespace json   = "http://www.json.org";
declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http   = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-condition:nabu-conditions := "/db/apps/nabuCom/data/Conditions";
declare variable $r-condition:coll       := collection($r-condition:nabu-conditions);
declare variable $r-condition:history    := concat($config:history-data,'/Conditions');
declare variable $r-condition:data-perms := "rwxrw-r--";
declare variable $r-condition:data-group := "spz";
declare variable $r-condition:infos  := doc('/db/apps/nabu/FHIR/Condition/condition-infos.xml');
declare variable $r-condition:valid-verificationStatus  := ('unconfirmed','provisional','differential','confirmed','refuted','entered-in-error');

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
declare function r-condition:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-condition:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-condition:history, $nameHistory)
                    )
        )
};

declare %private function r-condition:prepareResultXML($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            return
                switch($format)
                case 'code' return
                            <Condition xmlns="http://hl7.org/fhir">
                                <selected>false</selected>
                                {$c/fhir:id}
                                {$c/fhir:code}
                            </Condition>
                default return $c
    return
        <conditions xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            {
                subsequence($sorted-hits, $start, $len1)
            }
        </conditions>
};

declare %private function r-condition:prepareResultJSON($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            return
                $c
    return
        <json:value xmlns:json="http://www.json.org">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>

            {   
                for $p in subsequence($sorted-hits, $start , $len1)
                return
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                    {  local:element2json($p) }
                    </json:value>
            }
        </json:value>
};

(: 
    Return attributes for JSON serialization ^M
:)
declare function local:attributes2json($el as element()) {
    for $at in $el/@*
    return
        $at/string()
};

(:
    Return elements for JSON serialization
:)
declare function local:element2json($els as element()*) as element()* {
    for $el in $els
    return 
        element {$el/local-name()}
            {
              local:attributes2json($el)
            , local:element2json($el/*)
            }
};

declare %private function r-condition:rest-response($code as xs:integer, $message as xs:string)
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
                    case 'matches' return concat("[matches(", $f/@qname, "/", $f/@match, "'", $f, "')]")
                    case 'equals'  return concat("[", $f/@qname, "[",$f/@match, " = ", local:var_to_val($f), "]]")
                    default return ()
            else ()
    )
    ,'')
};

declare function local:var_to_val($var as node()) as xs:string
{
    let $toks := tokenize($var, ' ')
    return
        if (count($toks)=1)
        then concat("'", $var, "'")
        else let $vals := 
                for $t in $toks
                return
                    concat("'", $t, "'")
            return
                concat("(",string-join($vals,','),")")
};

(:~
 : GET: nabu/conditions/{$id}
 : List condition with id.
 : 
 : @return  <Condition>...</Condition>
 :)
declare
    %rest:GET
    %rest:path("nabu/conditions/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-condition:conditionByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $conditions := $r-condition:coll/Condition[fhir:id[@value = $pid]]
    return
        if (count($conditions)=1)
        then $conditions
        else if (count($conditions)>1)
        then r-condition:rest-response(404, concat('Condition with ID: ',$id, ' too many. Ask the Admin.'))
        else r-condition:rest-response(404, concat('Condition with ID: ',$id, ' not found. Ask the Admin.'))
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
declare function r-condition:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-condition:coll/fhir:Condition[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:subject/fhir:reference/@value with concat('nabu/patients/',$pid)
                , update value $res/fhir:subject/fhir:display/@value with $pnam
                , update value $res/fhir:meta/fhir:extension/fhir:valueReference/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension/fhir:valueReference/fhir:display/@value with $lognam
                , update value $res/fhir:meta/lastUpdated/@value with current-dateTime()
                ))
        else ()
};


(:~
 : GET: nabu/conditionsBySubject/{$uid}
 : List Conditions for subject $uid and return them as XML.
 : 
 : @param   $status  FHIR status
 : @return  bundle <Conditions/>
 
declare
    %rest:GET
    %rest:path("nabu/conditionsBySubject/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("status", "{$status}",  "active")
    %rest:query-param("verification", "{$verification}",  "confirmed")
    %rest:query-param("code",   "{$code}",  "diagnosis")
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-condition:conditionsBySubject(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $status as xs:string*
        , $verification as xs:string*
        , $code as xs:string*
    ) as item()
{
    try {
        let $sref    := concat('nabu/patients/',$id)
        let $matched := $r-condition:coll/fhir:Condition[fhir:subject[reference/@value=$sref]]
        (: [category//code/@value=$code][clinicalStatus/@value=$status][verificationStatus/@value=$verification] :)
        let $sorted-hits := for $a in $matched
                order by $a/fhir:recordedDate/@value/string() collation "?lang=de-DE"
                return
                    $a
        return
            r-condition:prepareResult($sorted-hits, '1', '*','full')
    } catch * {
        r-condition:rest-response(404, concat('Invalid subject? : ', $id))
    }
};
:)

(:~
 : GET: /nabu/conditions/{$id}/_history
 : get condition history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  condition bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/conditions/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-condition:conditionHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll  := $r-condition:coll | collection($r-condition:history)
    let $hits  := $coll/fhir:Condition[fhir:id[@value=$id]]
    return
        r-condition:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/condition/{$id}/_history/{$vid}
 : get condition history with id $id and version $vid
 : 
 : @param $id condition id
 : @param $vid version id
 : 
 : @return  condition bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/conditions/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-condition:conditionVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll  := $r-condition:coll | collection($r-condition:history)
    let $hits  := $coll/fhir:Condition[fhir:id[@value=$id]][meta/versionId/@value=$vid]
    return
        r-condition:prepareHistoryBundle($id, $hits)
};

declare %private function r-condition:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/conditions/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/conditions/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/conditions/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 4.0
 : abatement-age	quantity	Abatement as age or age range	Condition.abatement[x]
 : abatement-boolean	token	Abatement boolean (boolean is true or non-boolean values are present)	Condition.abatement[x]
 : abatement-date	date	Date-related abatements (dateTime and period)	Condition.abatement[x]
 : abatement-info	quantity	Abatement as a string	Condition.abatement[x]
 : asserter	reference	Person who asserts this condition	Condition.asserter
 : body-site	token	Anatomical location, if relevant	Condition.bodySite
 : category	token	The category of the condition	Condition.category
 : clinicalstatus	token	The clinical status of the condition	Condition.clinicalStatus
 : code	token	Code for the condition	Condition.code
 : context	reference	Encounter when condition first asserted	Condition.context
 : recordedDate	date	A date, when the Condition statement was documented	Condition.dateRecorded
 : evidence	token	Manifestation/symptom	Condition.evidence.code
 : identifier	token	A unique identifier of the condition record	Condition.identifier
 : onset-age	quantity	Onsets as age or age range	Condition.onset[x]
 : onset-date	date	Date related onsets (dateTime and Period)	Condition.onset[x]
 : onset-info	string	Onsets as a string	Condition.onset[x]
 : patient	reference	Who has the condition?	Condition.subject
 : severity	token	The severity of the condition	Condition.severity
 : stage	token	Simple summary (disease specific)	Condition.stage.summary
 : subject	reference	Who has the condition?	Condition.subject
 :)

(:~
 : GET: nabu/conditions?start=1&length=10&status=...
 : List conditions for subject
 : 
 : @param   $start
 : @param   $length
 : @param   $onsetStart    dateTime
 : @param   $onsetEnd      dateTime
 : @param   $subject       ref
 : @param   $status
 : @param   $verification
 : @param   $code
 : @param   $format        ('full', 'count')
 : 
 : @return  bundle <conditions/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/conditions")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam","{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("onsetStart", "{$onsetStart}")    
    %rest:query-param("onsetEnd",   "{$onsetEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "")
    %rest:query-param("verification", "{$verification}", "")
    %rest:query-param("category",  "{$category}", "")
    %rest:query-param("code",  "{$code}", "")
    %rest:query-param("_format", "{$format}", "full")
    %rest:query-param("_sort",   "{$sort}", "cat")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-condition:conditionsXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $onsetStart as xs:string*
        , $onsetEnd as xs:string*
        , $subject as xs:string*
        , $status as xs:string*
        , $verification as xs:string*
        , $category as xs:string*
        , $code as xs:string*
        , $format as xs:string*
        , $sort as xs:string*
        ) as item()
{
    try{
        let $lll := util:log-app('TRACE','apps.nabu',$code)
        let $code1 := tokenize($code,' ')
        let $verification := if($verification='active')
            then
                ("confirmed", "refuted", "differential", "provisional", "unconfirmed")
                
                (:
                  <verification>unconfirmed</verification>
                , <verification>refuted</verification>
                , <verification>provisional</verification>
                , <verification>differential</verification>
                , <verification>confirmed</verification>
                :)
            else
                $verification
(:~ 
 :  namespace interaction with util:eval.
 :  you can exec as long as you will, but the next call an other routine fails with error
 :  namespace "config" not defined
 :)
    let $facets := 
        <facets xmlns="">
            <facet name="category"      method="equals" qname="fhir:category" match="fhir:coding[fhir:code/@value">{$category}</facet>
            <facet name="status"        method="equals" qname="fhir:clinicalStatus" match="fhir:coding[fhir:code/@value">{$status}</facet>
            <facet name="verification"  method="equals" qname="fhir:verificationStatus" match="fhir:coding[fhir:code/@value">{$verification}</facet>
            <facet name="code"          method="equals" qname="fhir:code" match="fhir:coding[fhir:code/@value">{$code1}</facet>
        </facets>
    let $sref := concat('nabu/patients/', $subject)
    let $hits := if ($subject = '')
        then switch($category)
            case 'finding' return $r-condition:coll/fhir:Condition[fhir:category[fhir:coding[fhir:code/@value='finding']]][fhir:code[fhir:coding[fhir:code/@value=$code1]]]
            case 'diagnosis' return $r-condition:coll/fhir:Condition[fhir:code[fhir:coding[fhir:code/@value=$code1]]][fhir:category[fhir:coding[fhir:code/@value='diagnosis']]][fhir:clinicalStatus/fhir:coding[fhir:code/@value=$status]][fhir:verificationStatus/fhir:coding[fhir:code/@value=$verification]]
            default return $r-condition:coll/fhir:Condition[fhir:category[fhir:coding[fhir:code/@value=$category]]][fhir:code[fhir:coding[fhir:code/@value=$code]]][fhir:clinicalStatus/fhir:coding[fhir:code/@value=$status]][fhir:verificationStatus/fhir:coding[fhir:code/@value=$verification]]
        else let $cs0 := $r-condition:coll/fhir:Condition[fhir:subject[fhir:reference/@value=$sref]]
             let $cs1 := $cs0/../fhir:Condition[fhir:category[fhir:coding[fhir:code/@value=$category]]]
             return
                 $cs1/../fhir:Condition[fhir:verificationStatus/fhir:coding[fhir:code/@value=$verification]]
(: 
let $lll := util:log-app('TRACE','apps.nabu',count($r-condition:coll/fhir:Condition[fhir:subject[fhir:reference[@value=$sref]]]))
:)
(: 
    let $filter  := local:facet-filters($facets)
let $lll := util:log-app('TRACE','apps.nabu',$filter)
    let $matched := util:eval("$hits" || $filter)
:)
    let $matched := $hits
let $lll := util:log-app('TRACE','apps.nabu',count($matched))

    let $sorted-hits := switch($sort)
        case 'date' return for $a in $matched
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
        case 'cat' return 
            let $unc := for $a in $matched/../fhir:Condition[not(fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']])]
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            let $hd  := for $a in $matched/../fhir:Condition[fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']]/fhir:code/@value='HD']
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            let $nd  := for $a in $matched/../fhir:Condition[fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']]/fhir:code/@value='ND']
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            let $bd  := for $a in $matched/../fhir:Condition[fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']]/fhir:code/@value='BD']
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            let $noc := for $a in $matched/../fhir:Condition[fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']]/fhir:code/@value='']
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            return
                ($hd,$nd,$bd,$noc,$unc)
        case 'subject' return for $a in $matched
            order by $a/fhir:subject/fhir:display/@value/string() ascending
            return
                $a
        case 'tag' return for $a in $matched
            order by $a/fhir:code/fhir:coding/fhir:code/@value/string(),$a/fhir:subject/fhir:display/@value/string() collation "?lang=de-DE"
            return
                $a
        default return for $a in $matched
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
let $lll := util:log-app('TRACE','apps.nabu',count($sorted-hits))
    return
        switch ($format)
        case 'count' return <conditions><count>{count($sorted-hits)}</count></conditions> 
        default return 
            r-condition:prepareResultXML($sorted-hits, $start, $length, $format)
    } catch * {
        r-condition:rest-response(404, concat('Invalid filters? : ', string-join(($subject,$category,$status,$verification), '-')))
    }
};

(:~
 : GET: nabu/conditions?start=1&length=10&status=...
 : List conditions for subject
 :)
declare
    %rest:GET
    %rest:path("nabu/conditions")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam","{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("onsetStart", "{$onsetStart}")    
    %rest:query-param("onsetEnd",   "{$onsetEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "")
    %rest:query-param("verification", "{$verification}", "")
    %rest:query-param("category",  "{$category}", "")
    %rest:query-param("code",  "{$code}", "")
    %rest:query-param("_format", "{$format}", "full")
    %rest:query-param("_sort",   "{$sort}", "cat")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-condition:conditionsJSON(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $onsetStart as xs:string*
        , $onsetEnd as xs:string*
        , $subject as xs:string*
        , $status as xs:string*
        , $verification as xs:string*
        , $category as xs:string*
        , $code as xs:string*
        , $format as xs:string*
        , $sort as xs:string*
        ) as item()
{
    try{
        let $verification := if($verification='active')
            then
                ("confirmed", "refuted", "differential", "provisional", "unconfirmed")
                
                (:
                  <verification>unconfirmed</verification>
                , <verification>refuted</verification>
                , <verification>provisional</verification>
                , <verification>differential</verification>
                , <verification>confirmed</verification>
                :)
            else
                $verification
(:~ 
 :  namespace interaction with util:eval.
 :  you can exec as long as you will, but the next call an other routine fails with error
 :  namespace "config" not defined
 :)
    let $facets := 
        <facets xmlns="">
            <facet name="category"      method="equals" qname="fhir:category" match="fhir:coding[fhir:code/@value">{$category}</facet>
            <facet name="status"        method="equals" qname="fhir:clinicalStatus" match="@value">{$status}</facet>
            <facet name="verification"  method="equals" qname="fhir:verificationStatus" match="fhir:coding[fhir:code/@value">{$verification}</facet>
            <facet name="code"          method="equals" qname="fhir:code" match="fhir:coding[fhir:code/@value">{$code}</facet>
        </facets>
    let $sref := concat('nabu/patients/', $subject)
    let $hits := if ($subject = '')
        then switch($category)
            case 'finding' return $r-condition:coll/fhir:Condition[fhir:category[fhir:coding[fhir:code/@value='finding']]][fhir:code[fhir:coding[fhir:code/@value=$code]]]
            case 'diagnosis' return $r-condition:coll/fhir:Condition[fhir:code[fhir:coding[fhir:code/@value=$code]]][fhir:category[fhir:coding[fhir:code/@value='diagnosis']]][fhir:clinicalStatus[fhir:coding[fhir:code/@value=$status]]][fhir:verificationStatus[fhir.coding[fhir.code/@value=$verification]]]
            default return $r-condition:coll/fhir:Condition[fhir:category[fhir:coding/fhir:code/@value=$category]][fhir:code[fhir:coding[fhir:code/@value=$code]]][fhir:clinicalStatus[fhir:coding[fhir:code/@value=$status]]][fhir:verificationStatus[fhir.coding[fhir.code/@value=$verification]]]
        else $r-condition:coll/fhir:Condition[fhir:subject[fhir:reference/@value=$sref]][fhir:verificationStatus[fhir.coding[fhir:code/@value=$verification]]]

    let $matched := $hits

    let $sorted-hits := switch($sort)
        case 'date' return for $a in $matched
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
        case 'cat' return 
            let $unc := for $a in $matched/../fhir:Condition[not(fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']])]
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            let $hd  := for $a in $matched/../fhir:Condition[fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']]/fhir:code/@value='HD']
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            let $nd  := for $a in $matched/../fhir:Condition[fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']]/fhir:code/@value='ND']
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            let $bd  := for $a in $matched/../fhir:Condition[fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']]/fhir:code/@value='BD']
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            let $noc := for $a in $matched/../fhir:Condition[fhir:code/fhir:coding[fhir:system[@value='http://eNahar.org/nabu/extension#nabu-diagnosis-category']]/fhir:code/@value='']
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
            return
                ($hd,$nd,$bd,$noc,$unc)
        case 'subject' return for $a in $matched
            order by $a/fhir:subject/fhir:display/@value/string() ascending
            return
                $a
        default return for $a in $matched
            order by $a/fhir:recordedDate/@value/string() ascending
            return
                $a
    return
        switch ($format)
        case 'count'
                return
                    <json:value xmlns:json="http://www.json.org">
                        <conditions>
                            <count>{count($sorted-hits)}</count>
                        </conditions> 
                    </json:value>
        default return 
            r-condition:prepareResultJSON($sorted-hits, $start, $length, $format)
    } catch * {
        r-condition:rest-response(404, concat('Invalid filters? : ', string-join(($subject,$category,$status,$verification), '-')))
    }
};
(:~
 : POST: nabu/conditions/{$cid}/status/{$status}
 : Update an existing condition.
 :
 : 
 : @return <response>
 :)
declare
    %rest:POST
    %rest:path("nabu/conditions/{$cid}/status/{$status}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-condition:updateVerificationStatus(
      $cid as xs:string*
    , $status as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $lll := util:log-app('TRACE','apps.nabu',$status)
    let $cp := $r-condition:coll/Condition[fhir:id[@value = $cid]]
    return
    try {
        if (count($cp)=1 and r-condition:isValid($status))
        then
            let $vsd := $r-condition:infos/*:verificationStatus/*:code[@value=$status]/@label-de/string()
            let $up := system:as-user('vdba', 'kikl823!',
                (
                  update value $cp/fhir:verificationStatus/fhir:coding/fhir:code/@value with $status
                , update value $cp/fhir:verificationStatus/fhir:coding/fhir:display/@value with $vsd
                , update value $cp/fhir:verificationStatus/fhir:text/@value with $vsd
                , update value $cp/fhir:asserter/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $cp/fhir:asserter/fhir:display/@value with $lognam
                ))
            return
            r-condition:rest-response(200, 'condition status updated.')
        else
            r-condition:rest-response(404, 'condition status not updated.') 
    } catch * {
        r-condition:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-condition:isValid($status as xs:string) as xs:boolean
{
    $status = $r-condition:valid-verificationStatus
};

(:~
 : POST: nabu/conditions/new-patient-tag
 : 
 : 
 : @return <response>
 :)
declare
    %rest:POST
    %rest:path("nabu/conditions")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("tag",  "{$tag}")
    %rest:query-param("text",  "{$text}")
    %rest:query-param("pid", "{$pid}")
    %rest:query-param("pnam", "{$pnam}")
    %rest:produces("application/xml", "text/xml")
function r-condition:newConditionXML(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $tag as xs:string*
    , $text as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) as item()*
{
    let $cnd := condition:fillTemplate(
          'active', 'Aktiv'
        , 'confirmed', 'Bestätigt'
        , 'finding'
        , '6736007'
        , $tag
        , ''
        , $text
        , <subject xmlns="http://hl7.org/fhir">
            <reference value="{concat('nabu/patients/',$pid)}"/>
            <display value="{$pnam}"/>
          </subject>
        , format-dateTime(adjust-dateTime-to-timezone(current-dateTime()),"[Y0001]-[M01]-[D01]T[H01]:[m01]:[s01]")
        , ()
        , <recorder xmlns="http://hl7.org/fhir">
            <reference value="{concat('metis/practitioners/',$loguid)}"/>
            <display value="{$lognam}"/>
          </recorder>
        , <asserter xmlns="http://hl7.org/fhir">
            <reference value="{concat('metis/practitioners/',$loguid)}"/>
            <display value="{$lognam}"/>
          </asserter>
        , (), (), ()
        , 'auto-generated'
        )
    return
        r-condition:putConditionXML(document {$cnd},$realm,$loguid,$lognam)
};

(:~
 : PUT: nabu/conditions
 : Update an existing condition or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/conditions")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-condition:putConditionXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew := not($content/fhir:Condition/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/Condition/id/@value/string()
            let $conditions := $r-condition:coll/fhir:Condition[fhir:id[@value = $id]]
            let $move := r-condition:moveToHistory($conditions)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Condition/meta/versionId/@value/string()) + 1
    let $base := $content/Condition/fhir:*[not(
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
        <Condition xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$eid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                    <valueReference>
                        <reference value="{concat('metis/practitioners/',$loguid)}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
            </meta>
            {$base}
        </Condition>
        
(:    let $lll := util:log-app('TRACE','apps.nabu',$data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-condition:nabu-conditions, $file, $data)
            , sm:chmod(xs:anyURI($r-condition:nabu-conditions || '/' || $file), $r-condition:data-perms)
            , sm:chgrp(xs:anyURI($r-condition:nabu-conditions || '/' || $file), $r-condition:data-group)))
        return
            r-condition:rest-response(200, 'condition sucessfully stored.') 
    } catch * {
        r-condition:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

