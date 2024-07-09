xquery version "3.0";
let $import-date := "2021-03-07"
let $groups      := ('Arzt','Bayley3','Ergotherapie','Logopaedie','Orthoptik','Physiotherapie','Psychologie','Sozialarbeit')
let $ordner      := 'Befunde2021'
let $error-base  := "/db/apps/nabuCom/errors"


let $errors := collection($error-base)/*:error
let $new    := xmldb:find-last-modified-since($errors,xs:dateTime(concat($import-date, "T00:00:00")))
for $e in $new
return
    if ($e/*:date)
    then if ($e/*:date/ok)
        then ()
        else $e
    else $e
