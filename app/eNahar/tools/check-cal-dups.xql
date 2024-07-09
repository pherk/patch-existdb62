xquery version "3.1";

let $cs := collection('/db/apps/eNaharData/data/calendars/individuals')/cal
for $id in distinct-values($cs/owner/reference/@value)
let $ics := $cs[owner/reference/@value=$id]
return
    if(count($ics)>1)
    then
        for $ic in $ics
        return
        <dup-cals id="{string-join($ic/@xml:id,'::')}">
            { $ic/lastModified }
            { $ic/owner }
        </dup-cals>
    else
        ()