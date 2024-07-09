xquery version "3.1";
import module namespace http = "http://expath.org/ns/http-client";
import module namespace httpclient="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";

declare variable $encodings := <encodings>
  <site domain="http://www.korean-page.com/" encoding="EUC-KR"/>
  <site domain="http://www.japanese-page.com/" encoding="ISO-2022-JP"/>
  <site domain="http://another.japanese-page.com/" encoding="Shift_JIS"/>
</encodings>;

(:
 : Get the encoding for a given site based on the URL.
 : If the site is not specified in the local encodings list, assume UTF-8.
 :)
declare function local:get-encoding($url as xs:string) as xs:string {
  let $site := $encodings/site[starts-with($url,@domain)]
  return if(exists($site)) then data($site[1]/@encoding) else 'UTF-8'
};

(:
 : Fetch a page from the specified URL, always pausing 5 seconds before fetch.
 : If no title is found, try again.  Needed when some sites get too busy.
 :)
declare function local:fetch($url as xs:string, $times as xs:integer)
    as item()?
{
  let $headers := 
    <httpclient:headers>
        <httpclient:header name="Content-Type" value="application/json"/>
        <httpclient:header name="Accept" value="application/json"/>
    </httpclient:headers>
    
  let $options :=
    <options>
        <property name="http://enahar.org/html/properties/default-encoding" value="{local:get-encoding($url)}"/>
    </options>
  let $response := httpclient:get(xs:anyURI($url),false(),$headers)
  return 
    if (exists($response/*:body))
    then parse-json(util:binary-to-string($response/*:body))
    else ()
};

declare function local:get-page($url as xs:string)
    as item()?
{
  local:fetch($url, 5)
};

declare function local:get-page2($url as xs:string)
    as item()+
{
    http:send-request(
        <http:request method="GET" status-only="false" follow-redirect="false" timeout="5">
            <http:header name="Content-Type" value="application/xml"/>
            <http:header name="Accept" value="application/xml"/>
            <http:header name="Cache-Control" value="no-cache"/>
            <http:header name="Max-Forwards" value="'0'"/>
            <http:header name="Connection" value="close"/>
        </http:request>
        , $url
    )
};

local:get-page2("http://127.0.0.1:8080/exist/restxq/nabu/patients/p-21666")