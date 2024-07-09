xquery version "3.0";

let $os := collection('/db/apps/metisData/data/FHIR/Leaves')/*:leave[*:actor/*:display[starts-with(@value,'Passavanti')]]
let $ohs := collection('/db/apps/metisData/data/History/Leaves')
for $o in $os
order by $o/*:period/*:start/@value/string() descending
return
    <leave start="{$o/*:period/*:start/@value/string()}">
        {$o}
        <history>
    {
        for $oh in $ohs/*:leave[*:id[@value=$o/*:id/@value]]
        order by $oh/*:lastModified/@value/string()
        return
        <item id="{$oh/@xml:id/string()}" lastModified="{$oh/*:lastModified/@value/string()}">
            <info>{concat($oh/*:date/@value,' : ', string-join($oh/*:detail/*:actor/*:display/@value,','))}</info>
            <modified>{concat($oh/*:lastModifiedBy/*:display/@value,':',substring-after($oh/*:lastModifiedBy/*:reference/@value,'metis/practitioners/'), ' - ', $oh/*:status/@value)}</modified>
        {$oh}
        </item>
    }
        </history>
    </leave>
    