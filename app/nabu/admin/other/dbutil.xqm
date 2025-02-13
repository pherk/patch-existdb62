xquery version "3.0";
module namespace dbutil="http://exist-db.org/xquery/dbutil";
(:~
 : Scan a collection tree recursively starting at $root. Call 
 : $func once for each collection found 
 :)
declare function dbutil:scan-collections($root as xs:anyURI, $func as function
(xs:anyURI) as item()*) {
    $func($root),
    for $child in xmldb:get-child-collections($root)
    return
        dbutil:scan-collections(xs:anyURI($root || "/" || $child), $func)
};
  
(:~
 : List all resources contained in a collection and call the 
 : supplied function once for each resource with the complete
 : path to the resource as parameter.
 :)
 declare function dbutil:scan-resources($collection as xs:anyURI, $func as 
function(xs:anyURI) as item()*) {
    for $child in xmldb:get-child-resources($collection)
    return
        $func(xs:anyURI($collection || "/" || $child))
 };

 (:~ 
 : Scan a collection tree recursively starting at $root. Call 
 : the supplied function once for each resource encountered.
 : The first parameter to $func is the collection URI, the 
 : second the resource path (including the collection part).
 :)
declare function dbutil:scan($root as xs:anyURI, $func as function(xs:anyURI, xs
:anyURI?) as item()*) {
    dbutil:scan-collections($root, function($collection as xs:anyURI) {
        $func($collection, ()),
        (:  scan-resources expects a function with one parameter, so we use a 
partial application
            to fill in the collection parameter :)
        dbutil:scan-resources($collection, $func($collection, ?))
    })
};
  
declare function local:set-collection-resource-permissions($collection as xs:string, $owner as xs:string, $group as xs:string, $permissions as xs:int) {
    let $z := xmldb:set-collection-permissions($collection, $owner, $group, $permissions)
    let $a := for $resource in xmldb:get-child-resources($collection) return (
            xmldb:set-resource-permissions($collection, $resource, $owner, $group, $permissions)
            )
    let $b := for $child-collection in xmldb:get-child-collections($collection) return (
            local:set-collection-resource-permissions(concat($collection, '/', $child-collection), $owner, $group, $permissions)
            )
    return true()
};

