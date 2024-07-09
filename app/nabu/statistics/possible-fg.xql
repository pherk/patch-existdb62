xquery version "3.1";

let $year := "Befunde95-96-97"
let $coll := collection('/db/apps/nabuCom/import/' || $year)

return
    <possible-fg dir="{$year}">
        {
for $dok in $coll
let $d := util:document-name($dok)
let $pat := $dok/body/p[span[matches(.,'geb\.')]]
let $diag := $dok/body/p[matches(.,'SSW') or span[matches(.,'SSW')]]
order by $d
return
    if (count($diag) > 1)
    then <file name="{$d}">
            <patient>{$pat}</patient>
            <diagnosen>{
                for $dx in $diag
                return
                    if  (string-length($dx) < 100)
                    then <dx>{$dx}</dx>
                    else <dx>SSW in long text</dx>
            }</diagnosen>
        </file>
    else if (count($diag) = 1 and string-length($diag) < 100 )
    then <file name="{$d}">
            <patient>{$pat}</patient>
            <diagnosen>{
                <dx>{$diag}</dx>
            }</diagnosen>
        </file>
    else ()
        }
        </possible-fg>