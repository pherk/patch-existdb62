xquery version "3.0";
 
declare namespace fn="http://www.w3.org/2005/xpath-functions";
 
(: Search within $nodes for matches to a regular expression $pattern and apply a $highlight function :)
declare function local:highlight-matches($nodes as node()*, $pattern as xs:string, $highlight as function(xs:string) as item()* ) { 
    for $node in $nodes
    return
        typeswitch ( $node )
            case element() return
                element { name($node) } { $node/@*, local:highlight-matches($node/node(), $pattern, $highlight) }
            case text() return
                let $normalized := replace($node, '\s+', ' ')
                for $segment in analyze-string($normalized, $pattern)/node()
                return
                    if ($segment instance of element(fn:match)) then 
                        $highlight($segment/string())
                    else 
                        $segment/string()
            case document-node() return
                document { local:highlight-matches($node/node(), $pattern, $highlight) }
            default return
                $node
};

let $node := 
    <article>
        <h1>Introduction</h1>
        <p>Higher-order functions are probably the most notable addition to the XQuery language in
            version 3.0 of the <a href="http://www.w3.org/TR/xquery-30/">specification</a>. While it may
            take some time to understand their full impact, higher-order functions certainly open a wide
            range of new possibilities, and are a key feature in all functional languages.</p>
        <p>As of April 2012, eXist-db completely supports higher-order functions, including features
            like inline functions, closures and partial function application. This article will quickly
            walk through each feature before we put them all together in a practical example.</p>
        <section>
            <h1>Function References</h1>
            <p>A higher-order function is a function which takes another function as parameter or
                returns a function. So the first thing you'll need in order to pass a function around is
                a way to obtain a reference to a function.</p>
            <p>In older versions of eXist-db we had an extension function for this, called
                util:function, which expected a name as first argument, and the <em>arity</em> of the
                function as second. The <em>arity</em> corresponds to the
                    <sub>n<b>u</b>m<em>b</em>er</sub> of parameters the target function takes. Name and
                arity are required to uniquely identify a function within a module.</p>
            <p>XQuery 3.0 now provides a <a href="http://www.w3.org/TR/xquery-30/#id-named-function-ref"
                    >literal syntax</a> for referencing a function statically. It also consists of the
                name and the arity of the function to look up, separated by a hash sign:</p>
            <div class="code" data-language="xquery">let $f := my:func#2</div>
        </section>
    </article>
    
let $pattern := '[Ff]un[a-z]+'
let $highlight := function($string as xs:string) { <span class="highlight">{$string}</span> }
return 
    local:highlight-matches($node, $pattern, $highlight)