xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Appointments')/*:Appointment
for $o in $os
order by $o/*:start/@value/string()
return
    (:
    concat($o/*:start/@value,' - ',$o/*:end/@value,' : ', string-join($o/*:participant/*:actor/*:display/@value,','), ' ', $o/*:lastModified/@value,'   ', $o/*:status/@value)
    :)
    try {
        let $diff := xs:dateTime($o/*:end/@value/string()) - xs:dateTime($o/*:start/@value/string())
        return 
            if ($diff > xs:dayTimeDuration("PT0M") and $diff <  xs:dayTimeDuration("PT24H"))
            then ()
            else $o
    } catch * {
        let $lll :=util:log-app('DEBUG','nabu',$o/@xml:id/string())
        return $o
    }