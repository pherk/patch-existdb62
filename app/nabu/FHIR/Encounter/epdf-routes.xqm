xquery version "3.1";

(:
 : Defines all the RestXQ endpoints for Encounter PDF
 :)
module namespace r-epdf = "http://enahar.org/exist/restxq/nabu/encounter-pdf";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

import module namespace config      = "http://enahar.org/exist/apps/nabu/config"            at "../../modules/config.xqm";
import module namespace r-encounter = "http://enahar.org/exist/restxq/nabu/encounters"      at "../../FHIR/Encounter/encounter-routes.xqm";
import module namespace enclist     = "http://enahar.org/exist/apps/nabu/encounter-list"    at "../../FHIR/Encounter/encounter-list.xqm";
import module namespace encutil     = "http://enahar.org/exist/apps/nabu/encounter-util"    at "../../FHIR/Encounter/encounter-util.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare %private function r-epdf:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};


(:~
 : GET: /nabu/encs2pdf
 : Search encounters using a given field and a (lucene) query string.
 : 
 : @return encs as pdf
 :)
declare 
    %rest:GET
    %rest:path("/nabu/encs2pdf")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("uid",      "{$uid}", "")
    %rest:query-param("group",    "{$group}", "")  
    %rest:query-param("sched",    "{$sched}",  "")
    %rest:query-param("patient",  "{$patient}", "")
    %rest:query-param("rangeStart", "{$rangeStart}", "")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "")
    %rest:query-param("status",   "{$status}",  "planned")
    %rest:query-param("_sort",    "{$sort}", "archive")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-epdf:encs2PDF(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $uid as xs:string*
    , $group as xs:string*
    , $sched as xs:string*
    , $patient as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    , $status as xs:string*
    , $sort as xs:string*
    )
{
    (:
    let $facets := 
        <facets xmlns="">
            <facet name="name"      method="matches" path="fhir:name[fhir:use/@value='official']fhir:family/@value">{$name}</facet>
            <facet name="city"      method="matches" path="fhir:address/fhir:city/@value">{$city}</facet>
            <facet name="org"       method="equals"  path="fhir:organization/fhir:reference/@value">{$org}</facet>
            <facet name="role"      method="equals"  path="fhir:role/fhir:coding/fhir:code/@value">{$role}</facet>
            <facet name="specialty" method="equals"  path="fhir:specialty/fhir:coding/fhir:code/@value">{$specialty}</facet>
            <facet name="tag"       method="matches" path="fhir:meta/fhir:tag/fhir:text/@value">{$tag}</facet>
            <facet name="active"    method="equals"  path="fhir:active/@value">{$active}</facet>
        </facets>
    :)
    let $colls := encutil:collections($status,$rangeStart,$rangeEnd,$encutil:base)
    let $tmin := if (contains($rangeStart,'T'))
            then xs:dateTime($rangeStart)
            else dateTime(xs:date($rangeStart), xs:time('00:00:00'))
    let $tmax := if (contains($rangeEnd,'T'))
            then xs:dateTime($rangeEnd)
            else dateTime(xs:date($rangeEnd), xs:time('23:59:59'))
    let $uref := concat('metis/practitioners/', $uid)
    let $lll := util:log-app('TRACE','apps.nabu',$colls)
    let $matched0 := if ($uid!='')
            then collection($colls)/fhir:Encounter[fhir:participant/fhir:individual[fhir:reference/@value=$uref]][fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end/@value<$tmax]
            else if ($group!='')
                then collection($colls)/fhir:Encounter[fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]][matches(fhir:participant/fhir:type/fhir:coding/fhir:code/@value,$group)]
                else collection($colls)/fhir:Encounter[fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]]
    let $matched1 := if ($sched!='')
            then $matched0/../fhir:Encounter[fhir:type/fhir:coding[fhir:code/@value=$sched]]
            else $matched0
    let $matched : = if ($status!='')
            then $matched1/../fhir:Encounter[fhir:status[@value=$status]]
            else $matched1
    let $lll := util:log-app('TRACE','apps.nabu',count($matched))
    let $range := if (r-epdf:sameDay($tmin,$tmax))
        then
            format-dateTime($tmin,'[D01].[M01].[Y01]')
        else
            concat(format-dateTime($tmin,'[D01].[M01]'),'-', format-dateTime($tmax,'[D01].[M01].[Y01]'))
    let $result := 
        switch ($sort)
        case 'perDay'  return enclist:preparePerDayList($matched, $tmin, $tmax)
        case 'archive' return enclist:prepareArchiveList($matched, $tmin, $tmax, $realm, $loguid, $lognam)
        default return ()
    let $filename :=
        switch ($sort)
        case 'perDay'  return 'tagesliste-'
        case 'archive' return 'archiv-'
        default return 'error'
    return
        if ($result)
        then 
            let $fo  := tei2fo:report($result)
            let $pdf := xslfo:render($fo, "application/pdf", ())
            let $file := concat($filename,$range,'.pdf')
            return
            (   <rest:response>
                    <http:response status="200">
                        <http:header name="Content-Type" value="application/pdf"/>
                        <http:header name="Content-Disposition" value="attachment;filename={$file}"/>
                    </http:response>
                 </rest:response>
            ,   $pdf
            )
        else
            r-epdf:rest-response(404, 'Encounter List empty')
            
};

declare %private function r-epdf:sameDay($tmin,$tmax) as xs:boolean
{
    xs:date($tmin) = xs:date($tmax)
};

 