xquery version "3.0";
(:~
 :   
 :   
 :  @author  : Peter Herkenrath
 :  @version : 0.7.0
 :  @date 2016-12-02 
 :)
module namespace r-claml = "http://eNahar.org/exist/restxq/terminology/claml";

import module namespace config  = "http://enahar.org/exist/apps/terminology/config" at "../modules/config.xqm";
import module namespace lucene  = "http://enahar.org/exist/apps/terminology/lucene" at "/db/apps/terminology/modules/lucene.xqm";
import module namespace claml   = "http://enahar.org/exist/apps/terminology/claml"  at "/db/apps/terminology/claml/claml.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare variable $r-claml:clamlPath       := "/db/apps/terminologyData/icd10-de-data/de-DE";
declare variable $r-claml:clamlCollection := collection($r-claml:clamlPath);
(: 
https://www.orpha.net/consor/cgi-bin/Disease_Search.php?lng=EN&data_id=17601
:)
declare %private function r-claml:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <results xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { for $r in subsequence($hits, $start, $len1)
              order by $r/@conceptId
              return
                  $r
            }
        </results>
};



declare %private function r-claml:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare 
    %rest:GET
    %rest:path("terminology/{$termdb}/classes/{$code}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("lang",   "{$language}", "de-DE")  
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-claml:classXML(
      $termdb as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $language as xs:string*
    , $code as xs:string*
    ) as item()*
{
    let $classID  := 
                switch ($termdb)
                case 'icd10'    return "1.2.276.0.76.5.409"
                case 'hpo'      return "2.16.840.1.113883.6.339"
                case 'orphanet' return "2.16.840.1.113883.2.4.3.46.10.4.1"
                case 'icf-nl'   return "2.16.840.1.113883.6.254"
                default return ()

    let $result := claml:class((),$classID,$code,$language)
return
    if ($result)
    then
        $result
    else
        r-claml:rest-response(404,'code not found')
};

declare 
    %rest:GET
    %rest:path("terminology/{$termdb}/subclasses/{$code}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("lang",   "{$language}", "de-DE")  
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-claml:subClassesXML(
      $termdb as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $language as xs:string*
    , $code as xs:string*
    ) as item()*
{
    let $classID  := 
                switch ($termdb)
                case 'icd10'    return "1.2.276.0.76.5.409"
                case 'hpo'      return "2.16.840.1.113883.6.339"
                case 'orphanet' return "2.16.840.1.113883.2.4.3.46.10.4.1"
                case 'icf-nl'   return "2.16.840.1.113883.6.254"
                default return ()

    let $result := claml:subClasses((),$classID,$code,$language)
return
    if ($result)
    then
        $result
    else
        r-claml:rest-response(404,'code not found')
};


declare 
    %rest:GET
    %rest:path("terminology/{$termdb}/superclasses/{$code}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("lang",   "{$language}", "de-DE")  
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-claml:superClassesXML(
      $termdb as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $language as xs:string*
    , $code as xs:string*
    ) as item()*
{
    let $classID  := 
                switch ($termdb)
                case 'icd10'    return "1.2.276.0.76.5.409"
                case 'hpo'      return "2.16.840.1.113883.6.339"
                case 'orphanet' return "2.16.840.1.113883.2.4.3.46.10.4.1"
                case 'icf-nl'   return "2.16.840.1.113883.6.254"
                default return ()

    let $result := claml:superClasses($code, 'HPO')
return
    if ($result)
    then
        $result
    else
        r-claml:rest-response(404,'code not found')
};

(:~
:   Returns description elements for a ClaML based terminology
:
:   @param $classificationId required. OID for the terminology
:   @param $language optional. language for the terminology. format ll-CC, example en-US. If omitted then the first available language is picked
:   @param $searchString required. white delimited sequence of terms to look for
:   @param $maxResults optional. maximum number of results to return, defaults to $tsearch:maxResults
:   @param $statusCodes optional. Status codes in the terminology to match. Normally 'active' and/or 'deprecated'. Returns all matches if empty
:   @param $searchScope optional. Search scope for matching. 'code' and/or 'description'. Matches 'description' if empty
:   @return resultset with max $maxResults results
:   @author Peter Herkenrath
:   @since 2016-12-02
:)
declare 
    %rest:GET
    %rest:path("terminology/{$termdb}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}",   "1")      
    %rest:query-param("length", "{$length}",  "*")
    %rest:query-param("cid",    "{$classificationId}", "")
    %rest:query-param("lang",   "{$language}", "de-DE")  
    %rest:query-param("search", "{$searchString}",  "")
    %rest:query-param("status", "{$statusCodes}", "")
    %rest:query-param("type",   "{$searchType}", "wildcard")
    %rest:query-param("scope",  "{$searchScope}", "")      
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-claml:searchConceptXML(
      $termdb as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    , $classificationId as xs:string*
    , $language as xs:string*
    , $searchString as xs:string*
    , $maxResults as xs:string*
    , $statusCodes as xs:string*
    , $searchType as xs:string*
    , $searchScope as xs:string*
    ) as element(result)
{
    let $clamlPath          := 
                switch ($termdb)
                case 'icd10'    return "/db/apps/terminologyData/icd10-de-data/de-DE"
                case 'hpo'      return "/db/apps/terminologyData/hpo-data/en-US"
                case 'orphanet' return "/db/apps/terminologyData/orpha-data/en-US"
                case 'icf-nl'   return "/db/apps/terminologyData/icf-nl-data/nl-NL"
                default return ()

    let $clamlCollection    := if ($clamlPath) then collection($clamlPath) else ()
    
    let $validSearchCode    := 
        if ($searchScope='code') then true() else(false())
    let $validSearchDesc    := 
        if (matches($searchString,'^[a-z|0-9]') and string-length($searchString)>2 and string-length($searchString)<40) then
            true()
        else if (matches($searchString,'^[A-Z]') and string-length($searchString)>1 and string-length($searchString)<40) then
            true()
        else(false())
    let $searchTerms        := tokenize($searchString,'[\s-]')
    
    (:let $searchTerms := tokenize('ast','\s'):)
    let $maxResults         := xs:integer('50')
    let $luceneOptions      := lucene:getSimpleLuceneOptions()
    let $luceneQuery        := lucene:getSimpleLuceneQuery($searchTerms, $searchType)
    let $lll := util:log-app('TRACE','apps.nabu',$searchTerms)

    let $result :=
        if ($validSearchCode and $validSearchDesc and $searchScope='code' and $searchScope='description') then 
            $clamlCollection//description[@conceptId=$searchTerms] |
            $clamlCollection//description[ft:query(.,$luceneQuery,$luceneOptions)]
        else if ($searchScope='code' and $searchType='regex') then
            $clamlCollection//description[matches(./@conceptId,$searchTerms)]
        else if ($validSearchCode and $searchScope='code') then (
            $clamlCollection//description[@conceptId=$searchTerms]
        ) else if ($validSearchDesc) then (
            $clamlCollection//description[ft:query(.,$luceneQuery,$luceneOptions)]
        ) else (
        )
    
    let $result := if ($statusCodes) then ( $result[not(@statusCode)] | $result[@statusCode=$statusCodes] ) else ($result)
    
    let $count := count($result)
    let $maxResults := $lucene:maxResults
return
    r-claml:prepareResult($result,$start,$length)
};

(:~
:   Returns description elements for a ClaML based terminology
:
:   @param $classificationId required. OID for the terminology
:   @param $language optional. language for the terminology. format ll-CC, example en-US. If omitted then the first available language is picked
:   @param $searchString required. white delimited sequence of terms to look for
:   @param $maxResults optional. maximum number of results to return, defaults to $tsearch:maxResults
:   @param $statusCodes optional. Status codes in the terminology to match. Normally 'active' and/or 'deprecated'. Returns all matches if empty
:   @param $searchScope optional. Search scope for matching. 'code' and/or 'description'. Matches 'description' if empty
:   @return resultset with max $maxResults results
:
:   @author Peter Herkenrath
:   @since 2016-12-02
:)
declare 
    %rest:GET
    %rest:path("terminology/{$termdb}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}",   "1")      
    %rest:query-param("length", "{$length}",  "*")
    %rest:query-param("cid",    "{$classificationId}", "")
    %rest:query-param("lang",   "{$language}", "de-DE")  
    %rest:query-param("search", "{$searchString}",  "")
    %rest:query-param("status", "{$statusCodes}", "")
    %rest:query-param("type", "{$searchType}", "wildcard")
    %rest:query-param("scope",  "{$searchScope}", "")      
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-claml:searchConceptJSON(
      $termdb as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    , $classificationId as xs:string*
    , $language as xs:string*
    , $searchString as xs:string*
    , $maxResults as xs:string*
    , $statusCodes as xs:string*
    , $searchType as xs:string*
    , $searchScope as xs:string*
    ) as element(result)
{
    let $clamlPath          := 
                switch ($termdb)
                case 'icd10'    return "/db/apps/terminologyData/icd10-de-data/de-DE"
                case 'hpo'      return "/db/apps/terminologyData/hpo-data/en-US"
                case 'orphanet' return "/db/apps/terminologyData/orpha-data/en-US"
                case 'icf-nl'   return "/db/apps/terminologyData/icf-nl-data/nl-NL"
                default return ()

    let $clamlCollection    := if ($clamlPath) then collection($clamlPath) else ()
    
    let $validSearchCode    := 
        if ($searchScope='code') then true() else(false())
    let $validSearchDesc    := 
        if (matches($searchString,'^[a-z|0-9]') and string-length($searchString)>2 and string-length($searchString)<40) then
            true()
        else if (matches($searchString,'^[A-Z]') and string-length($searchString)>1 and string-length($searchString)<40) then
            true()
        else(false())
    let $searchTerms        := tokenize($searchString,'[\s-]')
    let $lll := util:log-app('TRACE','apps.nabu',$searchTerms)
   
    (:let $searchTerms := tokenize('ast','\s'):)
    let $maxResults         := xs:integer('50')
    let $luceneOptions      := lucene:getSimpleLuceneOptions()
    let $luceneQuery        := lucene:getSimpleLuceneQuery($searchTerms, $searchType)

    let $result             :=
        if ($validSearchCode and $validSearchDesc and $searchScope='code' and $searchScope='description') then 
            $clamlCollection//description[@conceptId=$searchTerms] |
            $clamlCollection//description[ft:query(.,$luceneQuery,$luceneOptions)]
        else if ($searchScope='code' and $searchType='regex') then
            $clamlCollection//description[matches(./@conceptId,$searchTerms)]
        else if ($validSearchCode and $searchScope='code') then
            $clamlCollection//description[@conceptId=$searchTerms]
        else if ($validSearchDesc) then (
            $clamlCollection//description[ft:query(.,$luceneQuery,$luceneOptions)]
        ) else (
        )
    
    let $results := if ($statusCodes) then ( $result[not(@statusCode)] | $result[@statusCode=$statusCodes] ) else ($result)
    
    let $count := count($results)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
return
        <json:array xmlns:json="http://www.json.org">
        {   
            for $r in subsequence($results, $start , $len1)
            order by $r/@conceptId/string()
            return
                <json:value xmlns:json="http://www.json.org" json:array="true">
                    <id>{$r/@conceptId/string()}</id>
                    <text>{concat($r/@conceptId,' : ', $r)}</text>
                    <textonly>{$r/string()}</textonly>
                </json:value>
        }
        </json:array>
};

