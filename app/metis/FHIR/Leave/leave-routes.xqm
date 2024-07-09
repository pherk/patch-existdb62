xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-leave = "http://enahar.org/exist/restxq/metis/leaves";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole" 
                                    at "../../FHIR/PractitionerRole/practitionerrole-routes.xqm";


declare namespace rest   ="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output ="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare namespace fo     ="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  ="http://exist-db.org/xquery/xslfo";
 
declare variable $r-leave:data-perms := "rwxrwxr-x";
declare variable $r-leave:perms      := "rwxr-xr-x";
declare variable $r-leave:coll       := collection($config:metis-leaves);
declare variable $r-leave:leaveHistory := '/db/apps/metisData/data/History/Leaves';

declare %private function r-leave:clipDate($date as xs:dateTime, $epoch as xs:dateTime) as xs:dateTime
{
    if ($date>$epoch)
    then $date
    else $epoch
};

 
(:~ moveToHistory
 : Move to history
 : 
 : @param $objects
 : @return ()
 : @version 0.6.12
 :)
declare %private function r-leave:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $r-leave:leaveHistory)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $r-leave:leaveHistory, $nameHistory)
                    )
        )
};

declare %private function r-leave:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-leave:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <leaves>
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </leaves>
};



(:~
 : GET: /leaves/{uuid}
 : get leave by id
 : 
 : @param $id  uuid
 :)
declare
    %rest:GET
    %rest:path("metis/leaves/{$uuid}")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-leave:leaveByID(
          $uuid as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()*
{
    let $leaves := $r-leave:coll/leave[id[@value=$uuid]]
    return
        if (count($leaves)=1)
        then $leaves
        else if (count($leaves)>1)
        then r-leave:rest-response(404, 'leaves: too many leaves found.')
        else r-leave:rest-response(404, 'leaves: uuid not valid.')
};

(:~
 : GET: /metis/leaves
 : get leaves by actor
 : 
 : @param $actor   user id
 : @param $begin   start of period
 : @param $end     end of Period
 : @param $status
 : @param $tag  
 : 
 : @return bundle of <leave/>
 :)
declare
    %rest:GET
    %rest:path("metis/leaves")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("start",  "{$start}",   "1")      
    %rest:query-param("length", "{$length}",  "*")
    %rest:query-param("actor",  "{$actor}",    "")
    %rest:query-param("group",  "{$group}",    "")
    %rest:query-param("rangeStart",  "{$rangeStart}", "")
    %rest:query-param("rangeEnd",    "{$rangeEnd}",   "")
    %rest:query-param("status", "{$status}", "")
    %rest:query-param("tag",    "{$tag}",      "")
    %rest:produces("application/xml", "text/xml")
function r-leave:leavesXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*, $length as xs:string*
        , $actor as xs:string*, $group as xs:string*
        , $rangeStart as xs:string*, $rangeEnd as xs:string*
        , $status as xs:string*
        , $tag   as xs:string*
        ) as item()
{
    let $today := adjust-dateTime-to-timezone(current-dateTime(),())
    let $tmin0 := if (contains($rangeStart,'T'))
            then xs:dateTime($rangeStart)
            else dateTime(xs:date($rangeStart), xs:time('00:00:00'))
    let $tmin := $tmin0 (:r-leave:clipDate($tmin0,$today) :)
    let $tmax := if (contains($rangeEnd,'T'))
            then xs:dateTime($rangeEnd)
            else dateTime(xs:date($rangeEnd), xs:time('23:59:59'))
    let $matched := if ($actor="")
        then $r-leave:coll/leave[period[start/@value[xs:dateTime(.) lt $tmax]][end/@value[xs:dateTime(.) gt $tmin]]][status[coding/code/@value=$status]]
        else let $aref := concat('metis/practitioners/', $actor)
            return 
                $r-leave:coll/leave[actor/reference[@value=$aref]][period[start/@value[xs:dateTime(.) lt $tmax]][end/@value[xs:dateTime(.) gt $tmin]]][status[coding/code/@value=$status]]

    let $sorted-hits :=
        for $c in $matched
        order by $c/period/start/@value/string()
        return
            $c
    return
        r-leave:prepareResult($sorted-hits, $start, $length)
};

(:~
 : GET: /metis/leaves
 : get leaves by actor
 : 
 : @param $actor   user id
 : @param $begin   start of period
 : @param $end     end of Period
 : @param $status
 : @param $tag  
 : 
 : @return bundle of <leave/>
 :)
declare
    %rest:GET
    %rest:path("metis/leaves")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}", "") 
    %rest:query-param("start",  "{$start}",   "1")      
    %rest:query-param("length", "{$length}",  "*")
    %rest:query-param("actor",  "{$actor}",    "")
    %rest:query-param("group",  "{$group}",    "")
    %rest:query-param("rangeStart",  "{$rangeStart}", "")
    %rest:query-param("rangeEnd",    "{$rangeEnd}",   "")
    %rest:query-param("status", "{$status}", "")
    %rest:query-param("tag",    "{$tag}",      "")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-leave:leavesJSON(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*, $length as xs:string*
        , $actor as xs:string*, $group as xs:string*
        , $rangeStart as xs:string*, $rangeEnd as xs:string*
        , $status as xs:string*, $tag   as xs:string*
        ) as item()
{
    let $today := adjust-dateTime-to-timezone(current-dateTime(),())
    let $tmin0 := if (contains($rangeStart,'T'))
            then xs:dateTime($rangeStart)
            else dateTime(xs:date($rangeStart), xs:time('00:00:00'))
    let $tmin := $tmin0 (: r-leave:clipDate($tmin0,$today) :)
    let $tmax := if (contains($rangeEnd,'T'))
            then xs:dateTime($rangeEnd)
            else dateTime(xs:date($rangeEnd), xs:time('23:59:59'))
    (: group of actors :)
    let $arefs   := if ($group='' and $actor!='')
        then concat('metis/practitioners/',$actor)
        else if ($group='')
        then ""
        else r-practrole:users('',$group,'','ref')//fhir:reference/@value/string()

    let $matched := if ($arefs="")
        then ()
        else let $ls :=  $r-leave:coll/leave[actor[reference[@value=$arefs]]][status[coding/code/@value=$status]]
            return
                $ls[period[start/@value[xs:dateTime(.) lt $tmax]][end/@value[xs:dateTime(.) gt $tmin]]]
    return
            <json:value xmlns:json="http://www.json.org">
            {
                for $l in $matched
                order by $l/actor/display/@value/string()
                return
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                        <id>{$l/id/@value/string()}</id>
                        <title>{$l/actor/display/@value/string()}</title>
                        { if ($l/allDay/@value='true')
                            then (: fullcalendar v2.27 expects end as exclusive end, e.g. the first moment after event!!! :)
                            (
                                <start>{concat(tokenize($l/period/start/@value,'T')[1],'T00:00:00')}</start>
                            ,   <end>{concat(xs:date(tokenize($l/period/end/@value,'T')[1])+xs:dayTimeDuration('P1D'),'T00:00:00')}</end>
                            ,   <allDay json:literal='true'>true</allDay>
                            )
                            else
                            (
                                <start>{$l/period/start/@value/string()}</start>
                            ,   <end>{$l/period/end/@value/string()}</end>
                            ,   <allDay json:literal='true'>false</allDay>
                            )
                        }
                        <editable json:literal='true'>false</editable>
                        <backgroundColor>{
                            switch($l/status/coding/code/@value)
                            case 'confirmed' return 'green'
                            default return 'grey'
                        }</backgroundColor>
                    </json:value>
            }
            </json:value>
};

(:~
 : GET: /metis/leaves2csv
 : Search leaves using a given field and a (lucene) query string.
 : 
 : @param $start    (default: '1')
 : @param $end      (default: '*')
 : @param $name     family-name
 : @param $type
 : @return leaves as csv
 :)
declare 
    %rest:GET
    %rest:path("/metis/leaves2csv")
    %rest:query-param("begin", "{$begin}", "")
    %rest:query-param("end",   "{$end}", "")
    %rest:query-param("actor", "{$actor}", "")
    %rest:query-param("type",  "{$type}",  "")
    %rest:produces("text/csv")
    %output:method("text")
function r-leave:leaves2CSV(
          $begin as xs:string*, $end as xs:string*
        , $actor as xs:string*, $type as xs:string*
        )
{
    let $nl := "&#10;"
    let $matched := if ($actor="")
        then $r-leave:coll/leave
        else let $aref := concat('metis/practitioners/', $actor)
            return 
                $r-leave:coll/leave[actor/reference/@value=$aref][matches(cause/coding/code/@value,$type)]

    let $sorted-hits := for $c in $matched
        order by $c/period/start/@value/string()
        return
            $c
    let $csv :=
        string-join(
        (
            "Name, GebDat, Type, Von, Bis"
        ,   string-join(($sorted-hits[1]/actor/display/@value/string(), "*", "", "", ""), ", ")
        ,   for $l in $sorted-hits
            return
            string-join(
                    (
                      ""
                    , ""
                    , $l/cause/coding/display/@value
                    , $l/period/start/@value
                    , $l/period/end/@value
                    )
                    , ', ')
        )
        , $nl)  
    return
    (   <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="text/csv"/>
                <http:header name="Content-Disposition" value="attachment;filename=leaves.csv"/>
            </http:response>
         </rest:response>
    , $csv)
};

(:~
 : GET: /metis/leaves2pdf
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
    %rest:path("/metis/leaves2pdf")
    %rest:query-param("begin", "{$begin}", "")
    %rest:query-param("end",   "{$end}", "")
    %rest:query-param("actor", "{$actor}", "")
    %rest:query-param("type",  "{$type}",  "")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-leave:leaves2PDF(
          $begin as xs:string*, $end as xs:string*
        , $actor as xs:string*, $type as xs:string*
        )
{
    let $nl := "&#10;"
    let $matched := if ($actor="")
        then $r-leave:coll/leave
        else let $aref := concat('metis/practitioners/', $actor)
            return 
                $r-leave:coll/leave[actor/reference/@value=$aref][matches(cause/coding/code/@value,$type)]

    let $sorted-hits := for $c in $matched
        order by $c/period/start/@value/string()
        return
            $c
    let $fo := tei2fo:letter($teic:test-letter, true())
    let $pdf := xslfo:render($fo, "application/pdf", ())
 
    return
    (   <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="application/pdf"/>
                <http:header name="Content-Disposition" value="attachment;filename=leaves.pdf"/>
            </http:response>
         </rest:response>
    , $pdf)
};

(:~
 : GET: /metis/leaves
 : get leaves by actor
 : 
 : @param $actor   user id
 : @param $begin   start of period
 : @param $end     end of Period
 : @param $status
 : @param $tag  
 : 
 : @return bundle of <leave/>
 :)
declare
    %rest:GET
    %rest:path("metis/leavesd3")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}", "") 
    %rest:query-param("start",  "{$start}",   "1")      
    %rest:query-param("length", "{$length}",  "*")
    %rest:query-param("actor",  "{$actor}",    "")
    %rest:query-param("group",  "{$group}",    "")
    %rest:query-param("rangeStart",  "{$rangeStart}", "2018-01-01")
    %rest:query-param("rangeEnd",    "{$rangeEnd}",   "2018-12-31")
    %rest:query-param("status", "{$status}", "")
    %rest:query-param("tag",    "{$tag}",      "")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-leave:leavesD3(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*, $length as xs:string*
        , $actor as xs:string*, $group as xs:string*
        , $rangeStart as xs:string*, $rangeEnd as xs:string*
        , $status as xs:string*, $tag   as xs:string*
        ) as item()
{
    let $tmin := if (contains($rangeStart,'T'))
            then xs:dateTime($rangeStart)
            else dateTime(xs:date($rangeStart), xs:time('00:00:00'))
    let $tmax := if (contains($rangeEnd,'T'))
            then xs:dateTime($rangeEnd)
            else dateTime(xs:date($rangeEnd), xs:time('23:59:59'))
    let $actors := if ($actor='')
        then r-practrole:users('', $group,'','ref')
        else r-practrole:userByID($actor,'ref')
    let $matched := collection($config:metis-leaves)/leave[actor/reference[@value = $actors//*:reference/@value]][status[coding/code/@value=$status]][period/start[@value < $tmax]][period/end[@value > $tmin]] 
    let $now := current-dateTime()
    return
    <json:value xmlns:json="http://www.json.org">
        <items>
        {
         (: TODO line 424 too much computing, ranks can be precomputed :)
         for $item at $i in $matched
            let $rank := index-of($actors//*:reference/@value/string(), $item/actor/reference/@value/string()) - 1
            let $start := if ($item/allDay/@value='true')
                then concat(tokenize($item/period/start/@value,'T')[1],'T00:00:00')
                else $item/period/start/@value/string()
            let $end := if ($item/allDay/@value='true')
                then concat(tokenize($item/period/end/@value,'T')[1],'T23:59:59')
                else $item/period/end/@value/string()
            let $class := if (xs:dateTime($start) > $now)
                then 
                    switch($item/status//code/@value)
                    case 'confirmed' return 'confirmed'
                    default return 'tentative'
                else 'past'
            order by $item/period/start/@value/string()
            return
            <json:value  json:array="true">
                <id>{$i}</id>
                <desc>{$item/summary/@value/string()}</desc>
                <start>{$start}</start>
                <end>{$end}</end>
                <lane>{$rank}</lane>
                <class>{$class}</class>
            </json:value>
        }
        </items>
        {
            for $a at $i in $actors/*:user
            return
                <lanes  json:array="true">
                    <id>{xs:integer($i) - 1}</id>
                    <label>{$a//*:display/@value/string()}</label>
                </lanes>
        }
    </json:value>
};


(:~
 : PUT: /metis/leaves
 : Update an existing leave or store a new one. 
 : 
 : @param $content
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("metis/leaves")
    %rest:query-param("realm", "{$realm}") 
    %rest:query-param("loguid", "{$loguid}") 
    %rest:query-param("lognam", "{$lognam}", "") 
    %rest:produces("application/xml", "text/xml")
function r-leave:putLeaveXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $isNew   := not($content/leave/@xml:id)
    let $cid   := if ($isNew)
        then concat("l-", util:uuid())
    (:
        then concat("l-", $content/leave/actor/reference/@value, '-', 
                        $content/leave/cause/coding/code/@value,
                        tokenize($content/leave/period/start/@value,'T')[1])
    :)
        else
            let $id := $content/leave/id/@value/string()
            let $order := $r-leave:coll/leave[id[@value = $id]]
            let $move := r-leave:moveToHistory($order)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/leave/meta/versionID/@value/string()) + 1
    let $elems := $content/leave/*[not(
                    self::meta
                or  self::id
                or  self::lastModified
                or  self::lastModifiedBy
                or  self::period
                )]
    let $meta := $content//meta/*[not(self::versionID)]
    let $period := $content//period
    let $uuid := if ($isNew)
        then $cid
        else "l-" || util:uuid()
    let $data :=
        <leave xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                {$meta}
                <versionID value="{$version}"/>
            </meta>
            <lastModifiedBy>
                <reference value="{concat('metis/practitioners/',$loguid)}"/>
                <display value="{$lognam}"/>
            </lastModifiedBy>    
            <lastModified value="{current-dateTime()}"/>
            { $elems }
            { $period }
        </leave>
        
(:
    let $lll := util:log-system-out($data)
:)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:metis-leaves, $file, $data)
            , sm:chmod(xs:anyURI($config:metis-leaves || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:metis-leaves || '/' || $file), $config:data-group)))
        return
            r-leave:rest-response(200, 'leave sucessfully stored.') 
    } catch * {
        r-leave:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

