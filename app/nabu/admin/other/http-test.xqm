query version "3.1";

import module namespace http="http://expath.org/ns/http-client";

declare function local:get-zotero-data($url){
   http:send-request(
        <http:request 
            http-version="1.1"
            href="{xs:anyURI($url)}" method="get">
             <http:header name="Connection" value="close"/>
        </http:request>)
};

declare function local:process($url){
    let $items := local:get-zotero-data($url)
    let $links := string($items[1]/descendant::*:header[@name='link']/@value)
    let $last :=
            for $last in tokenize($links,'&lt;')[contains(., 'rel="last"')]
            return replace(substring-before($last,'rel="last"'),'&lt;|&gt;','')
    let $next :=
            for $next in tokenize($links,'&lt;')[contains(., 'rel="next"')]
            return replace(substring-before($next,'rel="next"'),'&lt;|&gt;','')
    return
        <result>
            <page url="{$url}"/>
            { if($next) then local:process($next) else() }
        </result>
};

<div>{
    let $url := 'https://api.zotero.org/groups/538215/items?format=json&amp;limit=50'
    return 
        local:process($url)
    }
</div>