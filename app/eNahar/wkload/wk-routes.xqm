xquery version "3.0";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-wk = "http://enahar.org/exist/restxq/nabu/events";
import module namespace math = "http://exist-db.org/xquery/math";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";
(: provides new() :)
import module namespace xqtime = "http://enahar.org/lib/xqtime";
import module namespace config = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";
import module namespace date   = "http://enahar.org/exist/apps/enahar/date"   at "../modules/date.xqm";
import module namespace cart      = "http://enahar.org/exist/apps/enahar/cart"      at "../wkcart/cart.xqm";
import module namespace wksearch  = "http://enahar.org/exist/apps/enahar/wksearch"  at "../wksearch/wksearch.xqm";
import module namespace wkload    = "http://enahar.org/exist/apps/enahar/wkload"    at "../wkload/wkload.xqm";
import module namespace wkheatmap = "http://enahar.org/exist/apps/enahar/wkheatmap" at "../wkload/wkheatmap.xqm";

import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole" 
                   at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";


declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http   = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare namespace xdb  = "http://exist-db.org/xquery/xmldb";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

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

declare %private function r-wk:rest-response($code as xs:integer, $message as xs:string)
{ 
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : POST: /enahar/setup
 : set up Encounter, save order, communicate 
 :
 :  
 : @param $order
 : 
 : @return proposal bundle
 :)
declare
    %rest:POST("{$order}")
    %rest:path("enahar/setup")
    %rest:produces("application/xml", "text/xml")
function r-wk:setup($order as node()*)
{
    <ok/>
};

(:~
 : POST: /enahar/proposals
 : List possible encounters
 : 
 : @param $order
 : 
 : @return <proposals/>
 :)
declare
    %rest:POST("{$doc}")
    %rest:path("enahar/proposals")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:query-param("mode", "{$mode}", "normal") 
    %rest:query-param("limit", "{$limit}", "no")
    %rest:produces("application/xml", "text/xml")
function r-wk:proposals(
      $doc as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string* 
    , $lognam as xs:string*
    , $mode as xs:string*
    , $limit as xs:string*
    ) as item()
{
    let $params := map {
          'realm' : $realm
        , 'loguid' : $loguid
        , 'lognam' : $lognam
        , 'mode'   : $mode
        , 'inclSpecialAmb' : true()
        , 'now1' : xs:dateTime(concat(adjust-date-to-timezone(current-date(),()),'T00:00:00'))
                    + xs:dayTimeDuration("P1D")
        }
    let $order := $doc/fhir:Order
    let $lll := util:log-app('TRACE','apps.eNahar',$order)
    let $cart := cart:analyze($order, $mode, $limit)
    let $lll := util:log-app('TRACE','apps.eNahar',$cart)
    return
        if ($cart/error)
        then 
            <proposals>
                <index>1</index>
                <count>0</count>
                { $cart/error }
                { $cart/hint }
            </proposals>
        else
            wksearch:searchSlots($order, $cart, $params)
};



(:~
 : List workload aggregated by day->schedule->actor
 : 
 : @param   $actor      practitioner ref (default '*')
 : @param   $group      string (default 'arzt')
 : @param   $schedule
 : @param   $rangeStart dateTime as string
 : @param   $rangeEnd   dateTime as String
 : @param   $status     FHIR status (default 'planned')
 : 
 : @return  workload bundle with statistics
 :)
declare
    %rest:GET
    %rest:path("enahar/workload")
    %rest:query-param("realm",    "{$realm}", "")
    %rest:query-param("loguid",   "{$loguid}", "")
    %rest:query-param("lognam",   "{$lognam}", "")
    %rest:query-param("actor",    "{$actor}", "")
    %rest:query-param("group",    "{$group}", "")
    %rest:query-param("schedule", "{$schedule}", "")
    %rest:query-param("rangeStart",  "{$rangeStart}")
    %rest:query-param("rangeEnd",  "{$rangeEnd}")
    %rest:query-param("status",   "{$status}", "planned")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-wk:workloadPerDayXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $actor as xs:string*
        , $group as xs:string*
        , $schedule as xs:string*
        , $rangeStart as xs:string*
        , $rangeEnd as xs:string*
        , $status as xs:string*
        ) as item()
{
    let $lll := util:log-app('TRACE','apps.eNahar',string-join(($actor,$group,$schedule,$rangeStart,$rangeEnd,$status),':'))
    let $tmin := xs:dateTime($rangeStart)
    let $tmax := xs:dateTime($rangeEnd)
    let $actors := if ($actor='')
            then r-practrole:users('', $group,'','ref')
            else r-practrole:userByID($actor,'ref')
    let $lll := util:log-app('TRACE','apps.eNahar',$actors)
    let $arefs := $actors//fhir:reference/@value/string()
    let $wkld := wkload:workloadPerDayXML(
                      $realm, $loguid, $lognam
                    , $arefs, $group, $schedule
                    , $tmin, $tmax 
                    , $status)
    return
        $wkld
    
};


(:~
 : List workload and free slots aggregated by day->schedule->actor
 : 
 : @param   $actor      practitioner ref (default '*')
 : @param   $group      string (default 'arzt')
 : @param   $schedule
 : @param   $rangeStart dateTime as string
 : @param   $rangeEnd   dateTime as String
 : @param   $status     FHIR status (default 'planned')
 : 
 : @return  workload bundle with statistics
 :)
declare
    %rest:GET
    %rest:path("enahar/heatmap")
    %rest:query-param("realm",    "{$realm}", "")
    %rest:query-param("loguid",   "{$loguid}", "")
    %rest:query-param("lognam",   "{$lognam}", "")
    %rest:query-param("actor",    "{$actor}", "")
    %rest:query-param("group",    "{$group}", "")
    %rest:query-param("schedule", "{$schedule}", "")
    %rest:query-param("rangeStart", "{$rangeStart}")
    %rest:query-param("rangeEnd",  "{$rangeEnd}")
    %rest:query-param("status",   "{$status}", "planned")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-wk:heatmapJSON(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $actor as xs:string*
        , $group as xs:string*
        , $schedule as xs:string*
        , $rangeStart as xs:string*
        , $rangeEnd as xs:string*
        , $status as xs:string*
        ) as item()
{
let $lll := util:log-app('TRACE', 'apps.eNahar', string-join(($actor,$group,$schedule),':'))
 
    let $start := concat(tokenize($rangeStart,'T')[1],'T00:00:00')
    let $end   := concat(tokenize($rangeEnd,'T')[1],'T23:59:59')
    let $tmin := xs:dateTime($start)
    let $tmax := xs:dateTime($end)
    let $actors := if ($actor='')
            then r-practrole:users('', $group,'','ref')
            else r-practrole:userByID($actor,'ref')
    let $aref := concat("metis/practitioners/",$actor)
    let $heatmsp  := wkheatmap:wkslotsPerDayXML($realm, $loguid, $lognam, $aref, $group, "", $tmin, $tmax, ('tentative','planned'))
    return
        $heatmap
};




