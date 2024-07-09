xquery version "3.0";

import module namespace r-comm   = "http://enahar.org/exist/restxq/nabu/compositions"        at "../../FHIR/Composition/composition-routes.xqm";
import module namespace compmigr = "http://enahar.org/exist/apps/nabu/composition-migration" at "../../FHIR/Composition/composition-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";


let $cc := collection('/db/apps/nabuComposition/data/nodate')
let $cs := $cc/fhir:Composition
let $realm := 'kikl-spz'
return
    for $c in $cs
    return
        compmigr:update-1.0-2($c)