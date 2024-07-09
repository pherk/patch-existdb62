xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Patients')/*:Patient[*:active/@value='false']
return
    <patients-inactive>
    {
    for $o in $os
    order by $o/*:name/*:family/@value/string()
    return
        <synopsis>
        {
            concat($o/*:id/@value,'   ',$o/*:name/*:family/@value, ', ', $o/*:name/*:given/@value, ', *', $o/*:birthDate/@value,
                    ' : ',$o/*:lastModified/@value,'   ', $o/*:extension//*:code/@value)
        }</synopsis>
}
</patients-inactive>