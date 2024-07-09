xquery version "3.1";

let $c := collection("/db/apps/eNaharData/data/calendars/individuals")

let $cal :=
    $c/cal[owner/display[matches(@value,'Dafsari')]]
return
    $cal
