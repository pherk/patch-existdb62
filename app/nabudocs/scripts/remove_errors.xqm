xquery version "3.0";
declare namespace xmldb = "http://exist-db.org/xquery/xmldb";

let $import-base := "/db/apps/nabuCom/import"
let $error-base  := "/db/apps/nabuCom/errors"


let $err := collection($error-base)
for $e in $err
order by xmldb:created($error-base, $e)
return
    <err>{$e/file/text()}</err>