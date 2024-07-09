xquery version "3.0";
let $import-date := "2017-05-21"
let $groups      := ('Arzt','Bayley3','Ergotherapie','Logopaedie','Orthoptik','Physiotherapie','Psychologie','Sozialarbeit')
let $ordner      := 'Befunde17'
let $error-base  := "/db/apps/nabuCom/errors"

for $group in $groups
let $errors := collection($error-base)/*:error
let $new    := xmldb:find-last-modified-since($errors,xs:dateTime(concat($import-date, "T00:00:00")))
for $e in $errors[starts-with(*:collection, $group)]
return
<errlog>
    {
    try {
            let $coll := concat('Befunde17/',$e/collection)
            let $upd := system:as-user('vdba', 'kikl823!', update value $e/collection with $coll)
            return
                <item>updated</item>
        } catch * {
            <item>{concat($e/file, ' : not updated')}</item>
        }
    }
</errlog>
