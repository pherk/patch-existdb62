xquery version "3.0";
import module namespace date = "http://enahar.org/exist/apps/nabu/date" at "/db/apps/nabu/modules/date.xqm";

declare function local:calcNextDueDate($base as item()*)
{
    try {
        let $due := for $d in distinct-values($base[*:proposal/*:acq/@value='open']/*:spec/*:begin/@value)
            return
                date:easyDateTime($d)
        return
            if (count($due)>0)
            then min($due)
            else $due
    } catch * {
        util:log-system-out($base/*:spec/*:begin/@value/string())
    }
};

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/*:Order
for $o in $os
return
    try { 
        let $date := local:calcNextDueDate($o/*:detail)
        return ()
    } catch * {
        $o/*:when//*:event/@value/string()
    }