xquery version "3.0";
module namespace r-qrpdf = "http://enahar.org/exist/apps/restxq/qrpdf";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

import module namespace qr-table = "http://enahar.org/exist/apps/nabu/qr-table"        at "/db/apps/nabu/FHIR/QuestionnaireResponse/qr-table.xqm";

import module namespace r-qr     = "http://enahar.org/exist/restxq/nabu/questionnaireresponses"        at "/db/apps/nabu/FHIR/QuestionnaireResponse/questresponse-routes.xqm";

declare namespace   rest = "http://exquery.org/ns/restxq";
declare namespace   http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare namespace  fhir = "http://hl7.org/fhir";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";


declare %private function r-qrpdf:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : POST: nabu/qr2pdf
 : print QR
 : 
 : @param $content QuestionnaireResponse
 : @return  </results>
 :)
declare
    %rest:GET
    %rest:path("nabu/qr2pdf")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("qrid",   "{$qrid}")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-qrpdf:printQR(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $qrid as xs:string*
        )
{
    let $qr    := r-qr:questionnaireResponseByID($qrid, $realm, $loguid, $lognam)
    let $lll   := util:log-app('TRACE','apps.nabu',$qr)
    let $result := qr-table:prepareQRTable($qr)
    let $range  := "1"
    let $filename := 'qr-test'
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
            r-qrpdf:rest-response(404, 'Encounter List empty')
            
};
