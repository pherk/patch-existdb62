xquery version "3.0";

let $import-base := "/db/apps/nabuCom/import"
let $error-base  := "/db/apps/nabuCom/errors"
let $path := ""
let $collpath := ""
let $arzt  := collection(concat($import-base,'/',$path))
let $errors := collection($error-base)/error[collection = $collpath]
let $lll := util:log-system-out(count($arzt))
let $errs := $errors
for $e in $errs
let $file := $e/file/string()
let $doc := $arzt[util:document-name(.)=$file]
return
<errlog>
    {
    if (count($doc)=1)
    then
        try {
            let $coll := substring-after(util:collection-name($doc), concat($import-base,'/'))
            let $upd := system:as-user('vdba', 'kikl823!', update value $e/collection with $coll)
            return
                <item>updated</item>
        } catch * {
            <item>{concat($file, ' : not updated')}</item>
        }
    else
        $file
    }
</errlog>