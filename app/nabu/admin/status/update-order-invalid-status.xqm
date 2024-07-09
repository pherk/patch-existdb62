xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order
return
<updateOrder>
{
for $o in $os[fhir:status[@value=('tentative','accepted','')]] | $os[fhir:status[@value='active']][fhir:detail/fhir:status[@value=('tentative','accepted')]]
order by $o/fhir:lastModified/@value/string() descending
return

    (:
    system:as-user('vdba', 'kikl823!',
    (
        update value $o/fhir:status/@value with 'completed'
    ))
    :)
    if ($o/fhir:status/@value='')
    then
        if (count(distinct-values($o/fhir:detail/fhir:status/@value))=1)
        then
            system:as-user('vdba', 'kikl823!',
            (
                update value $o/fhir:status/@value with $o/fhir:detail[1]/fhir:status/@value/string()
            ))
        else if (count(distinct-values($o/fhir:detail[./fhir:status/@value!='cancelled']/fhir:status/@value))=1)
        then 
            system:as-user('vdba', 'kikl823!',
            (
                update value $o/fhir:status/@value with $o/fhir:detail[1]/fhir:status/@value/string()
            )) 
        else $o
    else ()
    (:
    system:as-user('vdba', 'kikl823!',
    (
        update value $o/fhir:status/@value with 'completed'
    ))
    :)
}
</updateOrder>