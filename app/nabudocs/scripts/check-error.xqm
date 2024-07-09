xquery version "3.0";
let $import-date := "2017-05-27"
let $groups      := ('Arzt','Bayley3','Ergotherapie','Logopaedie','Orthoptik','Physiotherapie','Psychologie','Sozialarbeit')
let $ordner      := 'Befunde17'
let $error-base  := "/db/apps/nabuCom/errors"

for $group in $groups
let $errors := collection('/db/apps/nabuCom/errors')/*:error[starts-with(*:collection, concat($ordner,'/',$group))]
let $new    := xmldb:find-last-modified-since($errors,xs:dateTime(concat($import-date, "T00:00:00")))
return
    string-join(($group, count($new), count($errors)),' - ')
