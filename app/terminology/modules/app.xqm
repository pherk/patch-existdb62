xquery version "3.0";

module namespace app="http://enahar.org/exist/apps/nabudocs";

import module namespace templates="http://exist-db.org/xquery/templates";

import module namespace r-user = "http://enahar.org/exist/restxq/metis/users"  at "/db/apps/metis/FHIR/user/user-routes.xqm";
import module namespace merge  = "http://enahar.org/exist/apps/nabudocs/merge" at "/db/apps/nabudocs/modules/merge.xqm";
import module namespace import = "http://enahar.org/exist/apps/nabudocs/import" at "/db/apps/nabudocs/modules/import.xqm";
import module namespace tree   = "http://enahar.org/exist/apps/nabudocs/tree" at "/db/apps/nabudocs/modules/tree.xqm";


declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function app:merge-patient($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic)
{
    let $server := request:get-header('host')
    let $today  := adjust-date-to-timezone(current-date(),())
    let $logu   := r-user:userByAlias(xdb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $lognam := concat($logu/fhir:name/fhir:family/@value, ', ', $logu/fhir:name/fhir:given/@value)
    let $realm := "metis/organizations/kikl-spz"
    return
        merge:patient($loguid,$lognam,$realm)
};

declare function app:main-errors($node as node(), $model as map(*), $path)
{
    let $server := request:get-header('host')
    let $today  := adjust-date-to-timezone(current-date(),())
    let $logu   := r-user:userByAlias(xdb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $lognam := concat($logu/fhir:name/fhir:family/@value, ', ', $logu/fhir:name/fhir:given/@value)
    let $realm := "metis/organizations/kikl-spz"
    return
        import:errors($loguid,$lognam,$realm,$path)
};

declare function app:main-menue($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic)
{
    let $server := request:get-header('host')
    let $today  := adjust-date-to-timezone(current-date(),())
    let $logu   := r-user:userByAlias(xdb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $lognam := concat($logu/fhir:name/fhir:family/@value, ', ', $logu/fhir:name/fhir:given/@value)
    let $realm := "metis/organizations/kikl-spz"
    return
        tree:menue($loguid,$lognam,$realm)
};



declare function app:dashboard($node as node(), $model as map(*), $action, $cal) {
    let $user   := r-user:userByAlias($logu)
    let $loguid := $user/fhir:id/@value/string()
return
<div><br/>
    <p>{$logu}; it is {current-dateTime()}</p>
</div>
};
