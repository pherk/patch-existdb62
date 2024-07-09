xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')
for $o in $os/fhir:Order[fhir:status[@value=('tentative','accepted','')]] | $os/fhir:Order[fhir:status[@value='active']][fhir:detail/fhir:status[@value=('cancelled','tentative','accepted')]]
order by $o/fhir:lastModified/@value/string() descending
return
    if ($o/fhir:status/@value='')
    then
        if (count(distinct-values($o/fhir:detail/fhir:status/@value))=1)
        then <updateStatus>{$o/fhir:detail[1]/fhir:status/@value/string()}</updateStatus>
        else if (count(distinct-values($o/fhir:detail[./fhir:status/@value!='cancelled']/fhir:status/@value))=1)
        then <updateStatus>{$o/fhir:detail[1]/fhir:status/@value/string()}</updateStatus>
        else $o
    else if (count(distinct-values($o/fhir:detail/fhir:status/@value))=1 and $o/fhir:detail/fhir:status[@value=('cancelled','tentative','accepted')])
    then
        let $upd := system:as-user('vdba', 'kikl823!',
                        (
                            update value $o/fhir:status/@value with $o/fhir:detail/fhir:status/@value/string()
                        ))
        return
            <cancelled lm="{$o/fhir:lastModified/@value/string()}">
                <detail status="{$o/fhir:detail/fhir:status/@value/string()}"/>
            </cancelled>
    else if ($o/fhir:detail/fhir:status[@value=('active')])
    then ()
    else
        $o
        
    (:
    system:as-user('vdba', 'kikl823!',
    (
        update value $o/fhir:status/@value with 'completed'
    ))
    :)
