xquery version "3.0";

import module namespace encmigr      = "http://enahar.org/exist/apps/nabu/encounter-migration"     at "../../FHIR/Encounter/encounter-migration.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

(: 
 : repairs missing basedOn properties
 : there are no empty basedOn refs
 :)
let $os := collection('/db/apps/nabuData/data/FHIR/Orders')
let $es := collection('/db/apps/nabuEncounter/data/planned')/fhir:Encounter[not(fhir:basedOn)]

let $realm := 'kikl-spz'
for $e in $es[1]
let $oid := tokenize(tokenize($e/fhir:appointment/fhir:reference/@value,'\?')[1],'/')[3]
let $o := $os/fhir:Order[fhir:id[@value=$oid]]
return
    if ($o and $o/fhir:basedOn and $o/fhir:basedOn/fhir:reference/@value!='')
    then
        encmigr:update-0.8-28($e,$o)
    else 
        $o
    