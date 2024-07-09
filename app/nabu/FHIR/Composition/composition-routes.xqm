xquery version "3.0";

module namespace r-composition = "http://enahar.org/exist/restxq/nabu/compositions";

import module namespace config = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace ju = "http://joewiz.org/ns/xquery/json-util" at "../../modules/json-util.xqm";
import module namespace parse = "http://enahar.org/exist/apps/nabu/parse" at "../../FHIR/meta/parse-fhir-resources.xqm";

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


declare variable $r-composition:base       := '/db/apps/nabuComposition/data';
declare variable $r-composition:coll       := collection($r-composition:base);
declare variable $r-composition:history    := concat($config:history-data,'/Compositions');
declare variable $r-composition:data-perms := "rwxrw-r--";
declare variable $r-composition:data-group := "spz";

(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare function r-composition:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-composition:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-composition:history, $nameHistory)
                    )
        )
};

declare %private function r-composition:prepareResult($hits, $start, $length, $format)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $h in $hits
            order by $h/date/@value/string() descending collation "?lang=de-DE"
            return
                $h
    return
        <compositions xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            {   let $data := subsequence($sorted-hits, $start, $len1)
                return
                    switch ($format)
                    case 'metadata' return
                            for $d in $data
                            return
                                <doc>
                                    {$d/*:id}
                                    <label value="{
                                        if ($d/fhir:date) 
                                        then concat(tokenize($d/fhir:date/@value,'T')[1],' - ',$d/fhir:section/fhir:code/fhir:text/@value)
                                        else $d/fhir:section/fhir:code/fhir:text/@value/string()
                                    }"/>
                                </doc>
                    default return $data 
            }
        </compositions>
};


declare %private function r-composition:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-composition:collections(
      $status as xs:string*
    , $tmin as xs:string
    , $tmax as xs:string
    , $base as xs:string
    ) as xs:string*
{
    if ($status="preliminary")
    then
        ("preliminary")
    else
        let $openrange := $tmin='' and $tmax=''
        let $years := 
            if ($openrange)
            then $base
            else
                let $ymin := if ($tmin!='')
                    then let $y := xs:integer(substring($tmin,1,4))
                        return max(($y,1994))
                    else 2004
                let $ymax := if ($tmax!='')
                    then let $y := xs:integer(substring($tmax,1,4))
                        return min(($y,2026))
                    else 2026
                let $inc := 0
                for $y in ($ymin to ($ymax+$inc))
                return
                    concat($base,'/',$y)
        let $lll := util:log-app('TRACE','apps.nabu',string-join(($status,$tmin,$tmax,$openrange,$years),':'))
        return
            ($years,'invaliddate','nodate','preliminary')
};

declare function r-composition:targetColl(
      $status as xs:string
    , $start as xs:string
    , $base as xs:string
    ) as xs:string
{
    if ($start='')
    then
        concat($base, '/nodate')
    else
        try {
            let $year := xs:integer(substring($start,1,4))
            return
                if ($year>1993 and $year<2027)
                then
                    concat($base,'/',$year)
                else 
                    concat($base,'/invaliddate')
        } catch * {
            concat($base,'/invaliddate')           
        }
};
(:~
 : GET: nabu/compositions/{$id}
 : List composition with id.
 : 
 : @return  <Composition>...</Composition>
 :)
declare
    %rest:GET
    %rest:path("nabu/compositions/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-composition:compositionByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $coms := $r-composition:coll/Composition[fhir:id[@value = $id]]
    return
        if (count($coms)=1)
        then $coms
        else if (count($coms)>1)
        then r-composition:rest-response(404, concat('Composition with ID: ',$id, ' too many. Ask the Admin.'))
        else r-composition:rest-response(404, concat('Composition with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: nabu/compositions/{$id}/reimport
 : GET: nabu/compositions/{$id}/new-date?date=
 : both API function reside in letter-import module in nabudocs
 :)

(:~
 : update subject
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $lognam
 : @param $pid
 : @param $pnam
 : 
 : @return 
 :)
declare function r-composition:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := $r-composition:coll/fhir:Composition[fhir:id[@value=$id]]
    let $sn  := normalize-space(tokenize($pnam,',')[1])
    let $fn  := normalize-space(tokenize($pnam,',')[2])
    let $iso := tokenize($pnam,'\*')[2]
    let $gd  := format-date($iso,"[D01].[M01].[Y0001]")
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:subject/fhir:reference/@value with concat('nabu/patients',$pid)
                , update value $res/fhir:subject/fhir:display/@value with $pnam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                , update value $res/fhir:title/@value with concat($pnam, ' - ', $res/fhir:date/@value)
                ,   if (count($res//tei:opener/tei:subject/tei:persName)=1)
                    then
                        update replace $res//tei:opener/tei:subject/tei:persName with
                            <persName xmlns="http://www.tei-c.org/ns/1.0">
                                <surname>{$sn}</surname>
                                <forename>{$fn}</forename>
                                <birth when="{$iso}">{$gd}</birth>
                            </persName>
                    else ()
                ))
        else ()
};

(:~
 : GET: nabu/compositions/{$id}/payload
 : List composition with id.
 : 
 : @return  <Composition>...</Composition>
 :)
declare
    %rest:GET
    %rest:path("nabu/compositions/{$id}/payload")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("_format", "{$format}", "xml")
    %rest:produces("application/xml", "text/xml")
function r-composition:compositionPayloadByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $format as xs:string*
    ) as item()+
{
    let $com := $r-composition:coll/fhir:Composition[fhir:id[@value=$id]]
    return
        if (count($com)=1)
        then let $letter := $com/section/text/tei:div
            return
                $letter
        else if (count($com)>1)
        then r-composition:rest-response(404, concat('Composition with ID: ',$id, ' too many. Ask the Admin.'))
        else r-composition:rest-response(404, concat('Composition with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: /nabu/compositions/{$id}/_history
 : get composition history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  composition bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/compositions/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-composition:compositionHistoryByID($id as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-composition:coll | collection($r-composition:history)
    let $hits  := $coll/fhir:Composition[fhir:id[@value=$id]] 
    return
        r-composition:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/composition/{$id}/_history/{$vid}
 : get composition history with id $id and version $vid
 : 
 : @param $id composition id
 : @param $vid version id
 : 
 : @return  composition bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/compositions/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-composition:compositionVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-composition:coll | collection($r-composition:history)
    let $hits  := $coll/fhir:Composition[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-composition:prepareHistoryBundle($id, $hits)
};

declare %private function r-composition:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/compositions/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/compositions/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</updated>
                        <published>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/compositions/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.6.0
 :
 : attester	reference	Who attested the composition	Composition.attester.party
 :                          (Practitioner, Organization, Patient)
 : author	reference	Who and/or what authored the composition	Composition.author
 :                          (Practitioner, Device, Patient, RelatedPerson)
 : category	token	    Categorization of Composition	Composition.category
 : confidentiality	token	As defined by affinity domain	Composition.confidentiality
 : context	token	    Code(s) that apply to the event being documented	Composition.event.code
 : date	    date    	Composition editing time	Composition.date
 : encounter	reference	Context of the Composition	Composition.encounter
 : entry	reference	A reference to data that supports this section	Composition.section.entry
 : identifier	token	Logical identifier of composition (version-independent)	Composition.identifier
 : 
 : period	date	    The period covered by the documentation	Composition.event.period
 : section	token	    Classification of section (recommended)	Composition.section.code
 : status	token	    preliminary | final | amended | entered-in-error	Composition.status
 : subject	reference	Who and/or what the composition is about	Composition.subject
 : title	string	    Human Readable name/title	Composition.title
 : type	    token	    Kind of composition (LOINC if possible)	Composition.type
 :)
(:~
 : GET: nabu/compositions?start=1&length=10&status=...
 : List compositions for subject
 : 
 : @param   $start
 : @param   $length
 : @param   $sender        ref
 : @param   $rangeStart    dateTime
 : @param   $rangeEnd      dateTime
 : @param   $subject       ref
 : @param   $status
 : @param   $format        ('full', 'wrapper', 'payload', 'count')
 : 
 : @return  bundle <compositions/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/compositions")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("loguid","{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("author",  "{$author}", "")
    %rest:query-param("dateStart", "{$dateStart}")    
    %rest:query-param("dateEnd",  "{$dateEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "in-progress")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-composition:compositionsXML(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $start as xs:string*
        ,   $length as xs:string*
        ,   $author as xs:string*
        ,   $dateStart as xs:string*
        ,   $dateEnd as xs:string*
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
    let $aref := "metis/practitioners/" || $author
    let $sref := "nabu/patients/" || $subject
    let $colls := r-composition:collections($status,"","",$r-composition:base)
    let $coll := collection($colls)
    let $matched := 
        if ($author="" and $subject="")
        then $coll/fhir:Composition[fhir:status[@value=$status]]
        else if ($subject="")
        then let $c0 := $coll/fhir:Composition[fhir:author[fhir:reference/@value=$aref]]
            return
                $c0/../fhir:Composition[fhir:status[@value=$status]]
        else if ($author="")
        then let $c0 := $coll/fhir:Composition[fhir:subject[fhir:reference/@value=$sref]]
            return $c0/../fhir:Composition[fhir:status[@value=$status]]
        else $coll/fhir:Composition[fhir:subject[fhir:reference/@value=$sref]][fhir:author[fhir:reference/@value=$aref]][fhir:status[@value=$status]]

    return
        switch ($format)
        case 'count' return <compositions><count>{count($matched)}</count></compositions>
    (:
        case 'pdf' return r-composition:compos2PDF($matched)
    :)
        default return 
            r-composition:prepareResult($matched, $start, $length, $format)
    } catch * {
        r-composition:rest-response(404, concat('Invalid filter? : ', $dateStart, '-', $dateEnd))
    }
};

declare
    %rest:GET
    %rest:path("nabu/compositions")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("loguid","{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("author",  "{$author}", "")
    %rest:query-param("dateStart", "{$dateStart}")    
    %rest:query-param("dateEnd",  "{$dateEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "in-progress")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/json")
function r-composition:compositionsJSON(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $start as xs:string*
        ,   $length as xs:string*
        ,   $author as xs:string*
        ,   $dateStart as xs:string*
        ,   $dateEnd as xs:string*
        ,   $subject as xs:string*
        ,   $status as xs:string*
        ,   $format as xs:string*
        ) as item()
{
    try{
    let $aref := "metis/practitioners/" || $author
    let $sref := "nabu/patients/" || $subject
    let $colls := r-composition:collections($status,"","",$r-composition:base)
    let $coll := collection($colls)
    let $matched := 
        if ($author="" and $subject="")
        then $coll/fhir:Composition[fhir:status[@value=$status]]
        else if ($subject="")
        then let $c0 := $coll/fhir:Composition[fhir:author[fhir:reference/@value=$aref]]
            return
                $c0/../fhir:Composition[fhir:status[@value=$status]]
        else if ($author="")
        then let $c0 := $coll/fhir:Composition[fhir:subject[fhir:reference/@value=$sref]]
            return $c0/../fhir:Composition[fhir:status[@value=$status]]
        else $coll/fhir:Composition[fhir:subject[fhir:reference/@value=$sref]][fhir:author[fhir:reference/@value=$aref]][fhir:status[@value=$status]]

    return
        switch ($format)
        case 'count' return <compositions><count>{count($matched)}</count></compositions>
    (:
        case 'pdf' return r-composition:compos2PDF($matched)
    :)
        default return 
            r-composition:prepareResult($matched, $start, $length, $format)
    } catch * {
        r-composition:rest-response(404, concat('Invalid filter? : ', $dateStart, '-', $dateEnd))
    }
};

declare %private function r-composition:doPUT(
      $content as item()
    , $realm as xs:string
    , $loguid as xs:string
    , $lognam as xs:string
    ) as item()+
{
    let $lll := util:log-app('TRACE','apps.nabu',$content)
    let $pid := $content/id/@value/string()
    let $id  := if ($pid and string-length($pid)>0)
        then
            (: lookup resource, and move it to history :)
            let $uc := $r-composition:coll/fhir:Composition[fhir:id[@value = $pid]]
            return
                if (count($uc)>0)
                then let $move := r-composition:moveToHistory($uc)
                    return $pid
                else if (count($uc)=0)
                then $pid
                else util:uuid()
        else util:uuid()

    let $version := if ($pid=$id) (: is new? :)
        then let $vid := $content/meta/versionId/@value
            return if ($vid)
                then xs:integer($vid) + 1
                else "0"
        else "0"
    let $base := $content/fhir:*[not(
                                    self::id
                                    or self::meta
                                )]
    let $meta := $content/meta/fhir:*[not(
                                        self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $data := 
        <Composition xmlns="http://hl7.org/fhir">
            <id value="{$id}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                <extension url="http://eNahar.org/nabu/extension/lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
            </meta>
            {$base}
        </Composition>
        
    let $lll := util:log-app('TRACE','apps.nabu',$data)
    let $target := r-composition:targetColl($data/fhir:status/@value,$data/fhir:date/@value,$r-composition:base)
    let $file := $id || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($target, $file, $data)
            , sm:chmod(xs:anyURI($target || '/' || $file), $r-composition:data-perms)
            , sm:chgrp(xs:anyURI($target || '/' || $file), $r-composition:data-group)))
        return
            $data
    } catch * {
        r-composition:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-composition:doPOST(
      $content as item()
    , $realm as xs:string
    , $loguid as xs:string
    , $lognam as xs:string
    ) as item()+
{
    let $pid := $content/id/@value/string()
    let $id  := if ($pid and string-length($pid)>0)
        then
            (: lookup resource, and move it to history :)
            let $uc := $r-composition:coll/fhir:Composition[fhir:id[@value = $pid]]
            return
                if (count($uc)>0)
                then let $move := r-composition:moveToHistory($userconfigs)
                    return $pid
                else if (count($uc)=0)
                then $pid
                else util:uuid()
        else util:uuid()

    let $version := if ($pid=$id) (: is new? :)
        then let $vid := $content/meta/versionId/@value
            return if ($vid)
                then xs:integer($vid) + 1
                else "0"
        else "0"
    let $base := $content/fhir:*[not(
                                    self::id
                                    or self::meta
                                )]
    let $meta := $content/meta/fhir:*[not(
                                        self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $data := 
        <Composition xmlns="http://hl7.org/fhir">
            <id value="{$id}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                <extension url="http://eNahar.org/nabu/extension/lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
            </meta>
            {$base}
        </Composition>
        
    let $lll := util:log-app('TRACE','apps.nabu',$data)
    let $target := r-composition:targetColl($data/fhir:status/@value,$data/fhir:date/@value,$r-composition:base)
    let $file := $id || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($target, $file, $data)
            , sm:chmod(xs:anyURI($target || '/' || $file), $r-composition:data-perms)
            , sm:chgrp(xs:anyURI($target || '/' || $file), $r-composition:data-group)))
        return
            (
              r-composition:rest-response(200, 'composition sucessfully stored.')
            , $data
            )
    } catch * {
        r-composition:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

(:~
 : PUT: nabu/UserConfig
 : Update an existing userconfig or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/UserConfig")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:consumes("application/json")
function r-composition:putCompositionJSON(
      $content as xs:base64Binary*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    let $json := util:binary-to-string($content)
    let $realm := ($realm,"kikl-spz")[1]
    let $loguid := ($loguid,"u-admin")[1]
    let $lognam := ($lognam,"putbot")[1]
    let $pmap := ju:json-to-xml(fn:parse-json($json))
    let $r := parse:resource-to-FHIR($pmap, "4.3")
let $lll := util:log-app('TRACE','apps.nabu',$r)
    return
        if ($r)
        then
            let $xml := r-composition:doPUT($r, $realm, $loguid, $lognam)
            return
                (
                 r-composition:rest-response(200, 'composition sucessfully stored.')
                , '{"response": "ok"}'
                )
        else
            r-composition:rest-response(422, 'no content? Ask the admin.') 
};

(:~
 : PUT: nabu/compositions
 : Update an existing composition or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/compositions")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-composition:putCompositionXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew := not($content/fhir:Composition/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:Composition/fhir:id/@value/string()
            let $comms := $r-composition:coll/fhir:Composition[fhir:id[@value = $id]]
            let $move := r-composition:moveToHistory($comms)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Composition/fhir:meta/fhir:versionId/@value/string()) + 1
    let $base := $content/fhir:Composition/fhir:*[not(
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
        <Composition xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </Composition>
        
    let $target := r-composition:targetColl($data/fhir:status/@value,$data/fhir:date/@value,$r-composition:base)
    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($target, $file, $data)
            , sm:chmod(xs:anyURI($target || '/' || $file), $r-composition:data-perms)
            , sm:chgrp(xs:anyURI($target || '/' || $file), $r-composition:data-group)))
        return
            r-composition:rest-response(200, 'composition sucessfully stored.') 
    } catch * {
        r-composition:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

(:~
 : compos2PDF
 : convert a sequence of compositions in a singel PDF file
 : 
 : @param $hits  documents
 : 
 : @return docs as pdf
 :)
(:~
 : GET: /nabu/compositions2pdf
 : Search leaves using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $end      (default: '*')
 : @param $name     family-name
 : @param $type
 : @return leaves as pdf
 :)
declare 
    %rest:GET
    %rest:path("/nabu/compositions2pdf")
    %rest:query-param("realm",   "{$realm}")
    %rest:query-param("loguid",  "{$loguid}")
    %rest:query-param("lognam",  "{$lognam}")
    %rest:query-param("rangeStart", "{$rangeStart}", "")    
    %rest:query-param("rangeEnd", "{$rangeEnd}",   "")
    %rest:query-param("id",       "{$id}",   "")
    %rest:query-param("subject",  "{$subject}", "")
    %rest:query-param("status",   "{$status}", "final")
    %rest:produces("application/xml", "text/xml")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-composition:compos2PDF(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $rangeStart as xs:string*, $rangeEnd as xs:string*
        , $id as xs:string*
        , $subject as xs:string*
        , $status as xs:string*
        )
{
    let $nl := "&#10;"
    let $tmin := if ($rangeStart)
        then xs:dateTime($rangeStart)
        else current-dateTime()
    let $tmax := if ($rangeEnd)
        then xs:dateTime($rangeEnd)
        else current-dateTime() + xs:dayTimeDuration('P1D') 
    let $sref := "nabu/patients/" || $subject
    let $matched := if ($id!='')
        then $r-composition:coll/Composition[fhir:id[@value=$id]]
        else $r-composition:coll/Composition[fhir:subject[starts-with(fhir:reference/@value,$sref)]][date/@value>$tmin][date/@value<$tmax][status/@value=$status]

    let $sorted-hits := for $e in $matched
            order by $e/sent/@value collation "?lang=de-DE"
            return
                $e
                
    let $lll := util:log-app('TRACE','apps.nabu',$sorted-hits)
    
    let $fo  := tei2fo:letter($sorted-hits/fhir:section/fhir:text/tei:div, false())

    let $lll := util:log-app('TRACE','apps.nabu',$fo)

    return
        if (count($fo/fo:page-sequence) > 0)
        then
            let $pdf := xslfo:render($fo, "application/pdf", ())
            return
            (   <rest:response>
                    <http:response status="200">
                        <http:header name="Content-Type" value="application/pdf"/>
                        <http:header
                            name="Content-Disposition" 
                            value="{concat('attachment;filename=br', adjust-dateTime-to-timezone(current-dateTime(),()),'.pdf')}"/>
                    </http:response>
                </rest:response>
            , $pdf)
        else
            r-composition:rest-response(404, 'call empty') 
};
