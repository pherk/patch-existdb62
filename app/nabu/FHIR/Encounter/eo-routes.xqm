xquery version "3.1";

(: 
 : Defines all the RestXQ endpoints for Order-Encounter interaction
 :)
module namespace r-eo = "http://enahar.org/exist/restxq/nabu/encounter-order";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
import module namespace xqtime = "http://enahar.org/lib/xqtime";
import module namespace config = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";

import module namespace commsub  = "http://enahar.org/exist/apps/nabu/comm-submit"     at "../../FHIR/Communication/comm-submit.xqm";
import module namespace r-encounter = "http://enahar.org/exist/restxq/nabu/encounters"  at "../../FHIR/Encounter/encounter-routes.xqm";
import module namespace r-order = "http://enahar.org/exist/restxq/nabu/orders"          at "../../FHIR/Order/order-routes.xqm";

import module namespace encconv = "http://enahar.org/exist/apps/nabu/encounter-conv"    at "../../FHIR/Encounter/encounter-conv.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare %private function r-eo:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : GET: nabu/encounters/{$uid}/letter
 : create encounter letter for subject
 : 
 : @return <response>
 :)
declare
    %rest:GET
    %rest:path("nabu/encounters/{$subject}/letter")
    %rest:query-param("realm",  "{$realm}","")
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:query-param("status", "{$status}", 'in-progress')
    %rest:produces("application/xml", "text/xml")
function r-eo:appletter(
      $subject as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $status as xs:string*
    ) as item()
{

        let $planned := r-encounter:encountersBySubject($subject, 'kikl-spz', $loguid, $lognam, "1", "*", "", "", 'planned')
        (: submit communication to family if any encounters :)
        return
            if (count($planned/fhir:Encounter) > 0)
            then
                let $action := $planned/fhir:Encounter[1]/fhir:appointment/fhir:reference/@value/string()
                let $comm := commsub:submitInfoLetter($realm, $loguid, $lognam, $action, $subject, $planned, (), $status)
                return
                    r-eo:rest-response(200, 'encounter letter sucessfully stored.')
            else
                    r-eo:rest-response(404, 'no encounters, no letter.')
                    (:
    } catch * {
        r-eo:rest-response(401, 'permission denied. Ask the admin.') 
    }  :)
};

 
(:~
 : PUT: nabu/order2encs
 : Make encounters, make communication resource, store referring order. 
 : The order XML is read from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:POST("{$content}")
    %rest:path("nabu/order2encs")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}", '')
    %rest:produces("application/xml", "text/xml")
function r-eo:submitOrder(
      $content as node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{

        let $order  := $content/fhir:Order
    (:
        let $lll := util:log-app('DEBUG', 'nabu', $order)
    :)
        let $subject:= substring-after($order/fhir:subject/fhir:reference/@value, 'nabu/patients/')
        let $planned := r-encounter:encountersBySubject($subject, 'kikl-spz', $loguid, $lognam, "1", "*", "", "", 'planned')
        (: submit single encounters :)
        let $new := r-eo:newEncounters($realm, $loguid, $lognam, $order)
        (: submit communication to family :)
        let $comm := if ($new)  (: only make letter if new encounter was made :)
            then commsub:submitInfoLetter($realm, $loguid, $lognam, $order/fhir:id/@value,$subject, $planned, $new, 'in-progress')
            else ()
        (: submit order :)
        let $closed := 
            let $base := $order/fhir:*[not(self::detail)][not(self::status)]
            let $details := $order/fhir:detail
            return
                <Order xmlns="http://hl7.org/fhir" xml:id="{$order/@xml:id/string()}">
                    { $base }
                    {
                        for $d in $details
                        let $db := $d/fhir:*[not(self::status)]
                        let $acq  := switch($d/fhir:status/@value)
                            case 'tentative' return 'completed'
                            case 'accepted'  return 'completed'
                            default return $d/fhir:status/@value/string()
                        return
                            <detail xmlns="http://hl7.org/fhir" id="{$d/@id/string()}">
                                { $db }
                                <status value="{$acq}"/>
                            </detail>
                    }
                    {
                        if ($order/fhir:status/@value=('tentative','accepted'))
                        then <status xmlns="http://hl7.org/fhir" value="completed"/>
                        else $order/fhir:status
                    }
                </Order>
        let $ret := r-order:putOrderXML(document {$closed}, $realm, $loguid, $lognam)
        return
            r-eo:rest-response(200, concat(count($new), ' encounter(s) sucessfully stored.'))
            (:
    } catch * {
        r-eo:rest-response(401, 'permission denied. Ask the admin.')
    }  
    :)
};

declare %private function r-eo:newEncounters(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $order as item()
    ) as element(fhir:Encounter)*
{
    for $d in $order/fhir:detail
    return
        switch ($d/fhir:status/@value)
        case 'active' return ()
        case 'tentative' return r-eo:submitOrderDetail($realm, $loguid, $lognam, $order, $d, "tentative")
        case 'accepted'  return r-eo:submitOrderDetail($realm, $loguid, $lognam, $order, $d, "planned")
        case 'cancelled' return ()
        case 'completed' return ()
        default return error(concat("illegal status code in order detail",$d/fhir:status/@value))
};

(:~
 : submitOrderDetail
 : submit encounter to actor
 :
 : @param $order
 : @param $detail
 :)
declare %private function r-eo:submitOrderDetail(
        $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $order as item()
        , $detail as item()
        , $status as xs:string
        ) as element(fhir:Encounter)?
{
    let $date := substring-before($detail/fhir:proposal/fhir:start/@value,'T')
    let $sdds  := r-eo:sameDayDetails($order,$date)
    let $combi :=  if (count($sdds)>1)
        then string-join($sdds/fhir:individual/fhir:display/@value,'<>')
        else ""
    let $enc := encconv:o2e($order, $detail, $status, $combi)
    (:
    let $lll := util:log-app('TRACE','apps.nabu',$enc)
    :)
    let $ret := r-encounter:putEncounterXML(document {$enc}, $realm, $loguid, $lognam)
    return
        switch ($status)
        case 'planned' return $enc
        default return ()
};

(:~
 : sameDayDetails
 : group of Order details which produces Encounters on same day (Kombi)
 :
 : @param $order
 : @param $date
 :)
declare %private function r-eo:sameDayDetails(
      $order as item()
    , $date as xs:string
)
{
  let $ds := $order/fhir:detail[fhir:proposal/fhir:start[substring-before(@value,'T')=$date]][fhir:status[@value=('accepted','tentative')]]
  return
      $ds
};