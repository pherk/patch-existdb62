module namespace v="http://gspring.com.au/pekoe/validator";
 
declare variable $v:schematron-compiler := xs:anyURI("xmldb:///db/iso-schematron-xslt2/iso_svrl_for_xslt2.xsl");
 
(: Call like this: v:validate($xml, xs:anyURI("/db/path/to/schema.sch") ) :)
 
declare function v:validate($doc as node(), $schematron as xs:anyURI ) {
    let $validator := local:get-compiled-validator($schematron)
    return transform:transform(
        $doc,
        $validator,()
        )
};
 
 declare function local:get-compiled-validator($schematron-path as xs:anyURI) {
    let $s-path := xs:string($schematron-path)
    let $xsl-path := concat(substring-before($s-path,"."),".xsl")
    return  (: check that the compiled version is up-to-date :)
        if (exists(doc($xsl-path)) and 
            xmldb:last-modified(util:collection-name($xsl-path), util:document-name($xsl-path)) gt 
            xmldb:last-modified(util:collection-name($s-path), util:document-name($s-path))) 
        then doc($xsl-path) 
        else local:compile-schematron($s-path,$xsl-path)
 };
 
 declare function local:compile-schematron($schematron-path, $xsl-path) {
    let $compiled := transform:transform(
                    doc($schematron-path), 
                    $v:schematron-compiler, ())
    let $stored := xmldb:store(util:collection-name($schematron-path), $xsl-path, $compiled)
    return doc($stored)
 };
