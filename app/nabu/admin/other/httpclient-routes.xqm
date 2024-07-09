xquery version "3.0";

(:~
: Defines all the RestXQ endpoints for patient queries
: @author Peter Herkenrath
: @version 1.0
: @see http://enahar.org
:
:)
module namespace r-http = "http://enahar.org/exist/restxq/test";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare %private function r-http:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare     
    %rest:GET
    %rest:path("test")
function r-http:test()
{
    r-http:rest-response(200, 'success')
};
