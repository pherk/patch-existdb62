xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-eoc = "http://enahar.org/exist/restxq/nabu/eocs";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace nutil  = "http://enahar.org/exist/apps/nabu/utils"    at "../../modules/utils.xqm";
import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";
import module namespace eoct = "http://enahar.org/exist/apps/nabu/eoc-template" at "/db/apps/nabu/FHIR/EpisodeOfCare/eoc-template.xqm";

declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-eoc:nabu-eocs := "/db/apps/nabuCom/data/EpisodeOfCares";
declare variable $r-eoc:coll := collection($r-eoc:nabu-eocs);
declare variable $r-eoc:history     := concat($config:history-data,'/EpisodeOfCares');
declare variable $r-eoc:data-perms    := "rwxrw-r--";
declare variable $r-eoc:data-group    := "spz";

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
 : @param $eoc
 : @return ()
 :)
declare function r-eoc:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-eoc:history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-eoc:history, $nameHistory)
                    )
        )
};

declare %private function r-eoc:prepareResult(
          $hits as item()*
        , $start as xs:string
        , $length as xs:string
        , $format as xs:string)
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
                switch($format)
                case 'code' return
                            <EpisodeOfCare xmlns="http://hl7.org/fhir">
                                <selected>false</selected>
                                {$c/fhir:id}
                                {$c/fhir:description}
                            </EpisodeOfCare>
                default return $c
    return
        <eocs xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($sorted-hits, $start, $len1) }
        </eocs>
};


declare %private function r-eoc:rest-response($code as xs:integer, $message as xs:string)
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
 : GET: nabu/eocs/{$id}
 : List eoc with id.
 : 
 : @return  <EpisodeOfCare>...</EpisodeOfCare>
 :)
declare
    %rest:GET
    %rest:path("nabu/eocs/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-eoc:eocByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $eocs := $r-eoc:coll/fhir:EpisodeOfCare[fhir:id[@value = $id]]
    return
        if (count($eocs)=1)
        then $eocs
        else if (count($eocs)>1)
        then r-eoc:rest-response(404, concat('EpisodeOfCare with ID: ',$id, ' too many. Ask the Admin.'))
        else r-eoc:rest-response(404, concat('EpisodeOfCare with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : update patient
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $pid
 : @param $pnam
 : 
 : @return 
 :)
declare function r-eoc:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $res := collection($r-eoc:nabu-eocs)/fhir:EpisodeOfCare[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:patient/fhir:reference/@value with concat('nabu/patients/',$pid)
                , update value $res/fhir:patient/fhir:display/@value with $pnam
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
        else ()
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
    %rest:path("nabu/eocs/{$id}/status/{$status}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-eoc:updateStatus(
      $content as document-node()*
    , $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $status as xs:string*
    ) 
{
    let $res := collection($r-eoc:nabu-eocs)/fhir:EpisodeOfCare[fhir:id[@value=$id]]
    return
        if (count($res)=1 and r-eoc:isValidStatus($status))
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

declare %private function r-eoc:isValidStatus($s)
{
  $s = (
      	'planned'
      , 'waitlist'
      , 'active'
      , 'onhold'
      , 'finished'
      , 'cancelled'
      , 'entered-in-error'
      )  
};

(:~
 : update careManager and team
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $lognam
 : @param $cmref
 : @param $cmdsp
 : @param $teamref
 : @param $teamdsp
 : 
 : @return 
 :)
declare function r-eoc:updateCMandTeam(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $id as xs:string*
    , $cmref as xs:string*
    , $cmdsp as xs:string*
    , $teamref as xs:string*
    , $teamdsp as xs:string*
    ) 
{
    let $lll := util:log-app('TRACE','apps.nabu',$id)
    let $res := collection($r-eoc:nabu-eocs)/fhir:EpisodeOfCare[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                    if ($cmref)
                    then
                        (
                          update value $res/fhir:careManager/fhir:reference/@value with $cmref
                        , update value $res/fhir:careManager/fhir:display/@value with $cmdsp
                        )
                    else ()
                ,   if ($teamref)
                    then
                        (
                          update value $res/fhir:team/fhir:reference/@value with $teamref
                        , update value $res/fhir:team/fhir:display/@value with $teamdsp
                        )
                    else ()
                , update value $res/fhir:status/@value with 'active'
                , update value $res/fhir:meta/fhir:extension/*/fhir:lastModifiedBy/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension/*/fhir:lastModifiedBy/fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
        else ()
};

(:~
 : update careManager if empty
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $lognam
 : @param $cmref
 : @param $cmdsp
 : 
 : @return 
 :)
declare function r-eoc:updateCM(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $id as xs:string*
    , $cmref as xs:string*
    , $cmdsp as xs:string*
    ) 
{
    let $lll := util:log-app('TRACE','apps.nabu',$id)
    let $res := collection($r-eoc:nabu-eocs)/fhir:EpisodeOfCare[fhir:id[@value=$id]]
    return
        if (count($res)=1 and $res/fhir:careManager/fhir:reference/@value='')
        then
            if ($cmref)
            then
                system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:status/@value with 'active'
                , update value $res/fhir:careManager/fhir:reference/@value with $cmref
                , update value $res/fhir:careManager/fhir:display/@value with $cmdsp
                , update value $res/fhir:meta/fhir:extension/*/fhir:lastModifiedBy/fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension/*/fhir:lastModifiedBy/fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
            else ()
        else ()
};


(:~
 : GET: /nabu/eocs/{$id}/_history
 : get eoc history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  eoc bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/eocs/{$id}/_history")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-eoc:eocHistoryByID(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $coll := $r-eoc:coll | collection($r-eoc:history)
    let $hits  := $coll/fhir:EpisodeOfCare[fhir:id[@value=$id]]
    return
        r-eoc:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/eoc/{$id}/_history/{$vid}
 : get eoc history with id $id and version $vid
 : 
 : @param $id eoc id
 : @param $vid version id
 : 
 : @return  eoc bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/eocs/{$id}/_history/{$vid}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-eoc:eocVersionByID(
      $id as xs:string*
    , $vid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $coll := $r-eoc:coll | collection($r-eoc:history)
    let $hits := $coll/fhir:EpisodeOfCare[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-eoc:prepareHistoryBundle($id, $hits)
};

declare %private function r-eoc:prepareHistoryBundle($id, $entries)
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
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/eocs/{$id}/_history"/>
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
                        <id>{$serverip}/exist/restxq/nabu/eocs/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}</id>
                        <updated>{$e/fhir:lastModified/@value/string()}</updated>
                        <published>{$e/fhir:lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/eocs/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search Parameters FHIR 1.9.0
 : category	token	E.g. Treatment, dietary, behavioral, etc.	EpisodeOfCare.category	
 : identifier	token	External Ids for this eoc	EpisodeOfCare.identifier	26 Resources
 : patient	reference	Who this eoc is intended for	EpisodeOfCare.patient
   (Patient)	31 Resources
 : start-date	date	When eoc pursuit begins	EpisodeOfCare.startDate	
 : status	token	proposed | accepted | planned | in-progress | on-target | ahead-of-target | behind-target | sustaining | achieved | on-hold | cancelled | entered-in-error | rejected	EpisodeOfCare.status	

 : target-date	date	Reach eoc on or before	EpisodeOfCare.target.dueDate	
 :)

(:~
 : GET: nabu/eocs?start=1&length=10&status=...
 : List eocs for patient
 : 
 : @param   $start
 : @param   $length
 : @param   $rangeStart    dateTime
 : @param   $rangeEnd      dateTime
 : @param   $patient       ref
 : @param   $status        ('planned', 'waitlist', 'active', 'finished', 'cancelled')
 : @param   $format        ('full', 'wrapper', 'payload', 'count')
 : 
 : @return  bundle <eocs/>
 : 
 : @since v0.8.41
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/eocs")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("rangeStart", "{$rangeStart}", "")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}",   "")
    %rest:query-param("patient", "{$patient}", "")
    %rest:query-param("status",  "{$status}", "")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-eoc:eocsXML(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    , $patient as xs:string*
    , $status as xs:string*
    , $format as xs:string*
    ) as item()
{
    let $coll := collection($r-eoc:nabu-eocs)
    let $sref := "nabu/patients/" || $patient
    let $matched0 := 
        if ($patient="")
        then ()
        else $coll/fhir:EpisodeOfCare[fhir:patient[fhir:reference/@value=$sref]]
    let $matched := if ($status="")
        then $matched0
        else $matched0/../fhir:EpisodeOfCare[fhir:status[@value=$status]]
    
 let $lll := util:log-app('TRACE','apps.nabu',$patient)
 let $lll := util:log-app('TRACE','apps.nabu',$matched)
    
    return
        switch ($format)
        case 'count' return <eocs><count>{count($matched)}</count></eocs> 
        default return 
            r-eoc:prepareResult($matched, "1", "*", $format)
};

(:~
 : POST: nabu/conditions/new-patient-tag
 : 
 : 
 : @return <response>
 :)
declare
    %rest:POST
    %rest:path("nabu/eocs")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("pid", "{$pid}")
    %rest:query-param("pnam", "{$pnam}")
    %rest:produces("application/xml", "text/xml")
function r-eoc:postEpisodeOfCareXML(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) as item()+
{
    let $eocprops := 
            (
              <patient xmlns="http://hl7.org/fhir">
                <reference value="{concat('nabu/patients/',$pid)}"/>
                <display value="{$pnam}"/>
              </patient>
            , <managingOrganization xmlns="http://hl7.org/fhir">
                <reference value="metis/organizations/kikl-spzn"/>
                <display value="nSPZ Kinderklinik UKK"/>
              </managingOrganization>
            , <period xmlns="http://hl7.org/fhir">
                <start value="{format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),()),"[Y0001]-[M01]-[D01]T[H01]:[m01]:[s01]")}"/>
                <end value=""/>
              </period>
            )
    let $childprops := () (: statusHistory, team, diagnosis :)
    let $cnd := eoct:fillEpisodeOfCare($eocprops, $childprops)
    return
        r-eoc:putEpisodeOfCareXML(document {$cnd}, $realm, $loguid,$lognam)
};



(:~
 : PUT: nabu/eocs
 : Update an existing eoc or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/eocs")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-eoc:putEpisodeOfCareXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    let $content := if($content/fhir:EpisodeOfCare)
        then $content
        else if ($content/*:EpisodeOfCare)
        then document { nutil:addNamespaceToXML($content/*:EpisodeOfCare,"http://hl7.org/fhir") }
        else let $lll := util:log-app('TRACE','apps.nabu',$content)
            return
                error()
    let $isNew := not($content/fhir:EpisodeOfCare/@xml:id)
    let $eid   := if ($isNew)
        then concat("c-", util:uuid())
        else 
            let $id := $content/fhir:EpisodeOfCare/fhir:id/@value/string()
            let $eocs := $r-eoc:coll/fhir:EpisodeOfCare[fhir:id[@value = $id]]
            let $move := r-eoc:moveToHistory($eocs)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:EpisodeOfCare/fhir:meta/fhir:versionId/@value/string()) + 1
    let $base := $content/fhir:EpisodeOfCare/fhir:*[not(
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
        <EpisodeOfCare xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
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
        </EpisodeOfCare>
        
(:    let $lll := util:log-system-out($data) :)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-eoc:nabu-eocs, $file, $data)
            , sm:chmod(xs:anyURI($r-eoc:nabu-eocs || '/' || $file), $r-eoc:data-perms)
            , sm:chgrp(xs:anyURI($r-eoc:nabu-eocs || '/' || $file), $r-eoc:data-group)))
        return
            (
              r-eoc:rest-response(200, 'eoc sucessfully stored.')
            , $data
            )
    } catch * {
        r-eoc:rest-response(401, 'permission denied. Ask the admin.') 
    }
};