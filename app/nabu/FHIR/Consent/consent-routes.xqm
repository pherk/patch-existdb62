xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-consent = "http://enahar.org/exist/restxq/nabu/consents";

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

declare variable $r-consent:nabu-consents := "/db/apps/nabuCom/data/Consents";
declare variable $r-consent:coll := collection($r-consent:nabu-consents);
declare variable $r-consent:history     := concat($config:history-data,'/Consents');
declare variable $r-consent:data-perms    := "rwxrw-r--";
declare variable $r-consent:data-group    := "spz";

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
 : @param $consent
 : @return ()
 :)
declare function r-consent:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-consent:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-consent:history, $nameHistory)
                    )
        )
};

declare %private function r-consent:prepareResult($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:priority collation "?lang=de-DE"
            return
                switch($format)
                case 'code' return
                            <Consent xmlns="http://hl7.org/fhir">
                                <selected>false</selected>
                                {$c/fhir:id}
                                {$c/fhir:description}
                            </Consent>
                default return $c
    return
        <consents xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </consents>
};


declare %private function r-consent:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/consents/{$id}
 : List consent with id.
 : 
 : @return  <Consent>...</Consent>
 :)
declare
    %rest:GET
    %rest:path("nabu/consents/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-consent:consentByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $consents := $r-consent:coll/fhir:Consent[fhir:id[@value = $id]]
    return
        if (count($consents)=1)
        then $consents
        else if (count($consents)>1)
        then r-consent:rest-response(404, concat('Consent with ID: ',$id, ' too many. Ask the Admin.'))
        else r-consent:rest-response(404, concat('Consent with ID: ',$id, ' not found. Ask the Admin.'))
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
declare function r-consent:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := collection($r-consent:nabu-consents)/fhir:Consent[fhir:id[@value=$id]]
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
 : GET: /nabu/consents/{$id}/_history
 : get consent history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  consent bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/consents/{$id}/_history")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-consent:consentHistoryByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $coll := $r-consent:coll | collection($r-consent:history)
    let $hits  := $coll/fhir:Consent[fhir:id[@value=$id]]
    return
        r-consent:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/consent/{$id}/_history/{$vid}
 : get consent history with id $id and version $vid
 : 
 : @param $id consent id
 : @param $vid version id
 : 
 : @return  consent bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/consents/{$id}/_history/{$vid}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-consent:consentVersionByID(
      $id as xs:string*
    , $vid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $coll := $r-consent:coll | collection($r-consent:history)
    let $hits := $coll/fhir:Consent[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-consent:prepareHistoryBundle($id, $hits)
};

declare %private function r-consent:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/consents/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/consents/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}</id>
                        <updated>{$e/fhir:lastModified/@value/string()}</updated>
                        <published>{$e/fhir:lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/consents/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.9.0
 : category	token	E.g. Treatment, dietary, behavioral, etc.	Consent.category	
 : identifier	token	External Ids for this consent	Consent.identifier	26 Resources
 : subject	reference	Who this consent is intended for	Consent.subject
   (Patient)	31 Resources
 : start-date	date	When consent pursuit begins	Consent.startDate	
 : status	token	proposed | accepted | planned | in-progress | on-target | ahead-of-target | behind-target | sustaining | achieved | on-hold | cancelled | entered-in-error | rejected	Consent.status	
 : subject	reference	Who this consent is intended for	Consent.subject
   (Group, Organization, Patient)	
 : target-date	date	Reach consent on or before	Consent.target.dueDate	
 :)

(:~
 : GET: nabu/consents?start=1&length=10&status=...
 : List consents for subject
 : 
 : @param   $start
 : @param   $length
 : @param   $rangeStart    dateTime
 : @param   $rangeEnd      dateTime
 : @param   $subject       ref
 : @param   $status        ('planned', 'waitlist', 'active', 'finished', 'cancelled')
 : @param   $format        ('full', 'wrapper', 'payload', 'count')
 : 
 : @return  bundle <consents/>
 : 
 : @since v0.8.41
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/consents")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("rangeStart", "{$rangeStart}", "")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "active")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-consent:consentsXML(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    , $subject as xs:string*
    , $status as xs:string*
    , $format as xs:string*
    ) as item()
{
    try{

    let $sref := "nabu/patients/" || $subject
    let $matched0 := 
        if ($subject="")
        then $r-consent:coll/fhir:Consent
        else $r-consent:coll/fhir:Consent[fhir:subject/fhir:reference[@value=$sref]]
    let $matched := if ($status="")
        then $matched0
        else $matched0[fhir:status[@value=$status]]
    return
        switch ($format)
        case 'count' return <consents><count>{count($matched)}</count></consents> 
        default return 
            r-consent:prepareResult($matched, $start, $length, $format)
    } catch * {
        r-consent:rest-response(404, concat('Invalid time filter? : ', $rangeStart, '-', $rangeEnd))
    }
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
 : PUT: nabu/consents
 : Update an existing consent or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/consents")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-consent:putConsentXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    let $content := if($content/fhir:Consent)
        then $content
        else if ($content/*:Consent)
        then document { local:addNamespaceToXML($content/*:Consent,"http://hl7.org/fhir") }
        else let $lll := util:log-app('TRACE','apps.nabu',$content)
            return
                error()
    let $isNew := not($content/fhir:Consent/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:Consent/fhir:id/@value/string()
            let $consents := $r-consent:coll/fhir:Consent[fhir:id[@value = $id]]
            let $move := r-consent:moveToHistory($consents)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Consent/fhir:meta/fhir:versionId/@value/string()) + 1
    let $base := $content/fhir:Consent/fhir:*[not(
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
        <Consent xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </Consent>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-consent:nabu-consents, $file, $data)
            , sm:chmod(xs:anyURI($r-consent:nabu-consents || '/' || $file), $r-consent:data-perms)
            , sm:chgrp(xs:anyURI($r-consent:nabu-consents || '/' || $file), $r-consent:data-group)))
        return
            (
              r-consent:rest-response(200, 'consent sucessfully stored.')
            , $data
            )
    } catch * {
        r-consent:rest-response(401, 'permission denied. Ask the admin.') 
    }
};