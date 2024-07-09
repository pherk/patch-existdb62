xquery version "3.1";

let $import-date := "2017-05-27"
let $groups      := ('Arzt','Bayley3','Ergotherapie','Logopaedie','Orthoptik','Physiotherapie','Psychologie','Sozialarbeit')

let $import-base := "/db/apps/nabuCom/import/Befunde17"


for $group in $groups
let $letters := collection(concat($import-base, "/", $group))
let $new    := xmldb:find-last-modified-since($letters,xs:dateTime(concat($import-date, "T00:00:00")))
return
    string-join(($group,count($new),count($letters)),' - ')