xquery version "3.0";


declare namespace fhir= "http://hl7.org/fhir";

let $oc   := collection('/db/apps/nabuData/data/FHIR/Orders')
let $eocc := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $os := $oc/fhir:Order[fhir:status[@value=('active')]]

let $result :=
<order-type>
{
for $o in $os
let $sref := $o/fhir:subject/fhir:reference/@value
let $eoc  := $eocc/fhir:EpisodeOfCare[fhir:subject[fhir:reference/@value=$sref]][fhir:status[@value=('active','planned')]]
return

if (count($eoc)=1) (: invariant :)
then
    switch ($eoc/fhir:status/@value)
    case 'active' return
        switch($o/fhir:appointmentType/fhir:coding/fhir:code/@value)
        case 'ROUTINE' return
                if (string-length($eoc/fhir:careManager/fhir:reference/@value)=0)
                then
                    let $hascm := system:as-user('vdba','kikl823!',
                    (
                          update value $o/fhir:appointmentType/fhir:coding/fhir:code/@value
                            with 'NOCM'
                        , update value $o/fhir:appointmentType/fhir:coding/fhir:display/@value
                            with 'kein FF'
                        , update value $o/fhir:appointmentType/fhir:text/@value
                            with 'kein FF'
                    ))
                    return
                        <nocm id="{$o/fhir:id/@value/string()}">{$o/fhir:subject}</nocm>
                else
                    ()
        case 'NOCM' return
                if (string-length($eoc/fhir:careManager/fhir:reference/@value)=0)
                then
                    ()
                else
                    let $hascm := system:as-user('vdba','kikl823!',
                        (
                          update value $o/fhir:appointmentType/fhir:coding/fhir:code/@value
                            with 'ROUTINE'
                        , update value $o/fhir:appointmentType/fhir:coding/fhir:display/@value
                            with 'Routine'
                        , update value $o/fhir:appointmentType/fhir:text/@value
                            with 'Routine'
                    ))
                    return 
                        <hascm id="{$o/fhir:id/@value/string()}" cm="{$eoc/fhir:careManager/fhir:reference/@value/string()}"/>
        default return 
                if (string-length($eoc/fhir:careManager/fhir:reference/@value)=0)
                then
                    let $hascm := system:as-user('vdba','kikl823!',
                    (
                          update value $o/fhir:appointmentType/fhir:coding/fhir:code/@value
                            with 'NOCM'
                        , update value $o/fhir:appointmentType/fhir:coding/fhir:display/@value
                            with 'kein FF'
                        , update value $o/fhir:appointmentType/fhir:text/@value
                            with 'kein FF'
                    ))
                    return
                        <order-error xmlid="{$o/@xml:id/string()}" type="{$o/fhir:appointmentType/fhir:coding/fhir:code/@value/string()}"/>
                else
                    let $hascm := system:as-user('vdba','kikl823!',
                        (
                          update value $o/fhir:appointmentType/fhir:coding/fhir:code/@value
                            with 'ROUTINE'
                        , update value $o/fhir:appointmentType/fhir:coding/fhir:display/@value
                            with 'Routine'
                        , update value $o/fhir:appointmentType/fhir:text/@value
                            with 'Routine'
                    ))
                    return 
                        <order-error xmlid="{$o/@xml:id/string()}" type="{$o/fhir:appointmentType/fhir:coding/fhir:code/@value/string()}"/>
    case 'planned' return
        switch ($o/fhir:appointmentType/fhir:coding/fhir:code/@value)
        case 'ROUTINE' return
                if (string-length($eoc/fhir:careManager/fhir:reference/@value)=0)
                then
                    let $hascm := system:as-user('vdba','kikl823!',
                        (
                          update value $o/fhir:appointmentType/fhir:coding/fhir:code/@value
                            with 'NOCM'
                        , update value $o/fhir:appointmentType/fhir:coding/fhir:display/@value
                            with 'kein FF'
                        , update value $o/fhir:appointmentType/fhir:text/@value
                            with 'kein FF'
                        ))
                    return
                        <nocm id="{$o/fhir:id/@value/string()}">{$o/fhir:subject}</nocm>
                else ()
        case 'NOCM' return ()
        default return 
                if (string-length($eoc/fhir:careManager/fhir:reference/@value)=0)
                then
                    let $hascm := system:as-user('vdba','kikl823!',
                        (
                          update value $o/fhir:appointmentType/fhir:coding/fhir:code/@value
                            with 'NOCM'
                        , update value $o/fhir:appointmentType/fhir:coding/fhir:display/@value
                            with 'kein FF'
                        , update value $o/fhir:appointmentType/fhir:text/@value
                            with 'kein FF'
                        ))
                    return
                        <order-error xmlid="{$o/@xml:id/string()}" type="{$o/fhir:appointmentType/fhir:coding/fhir:code/@value/string()}"/>
                else
                    <hascm id="{$o/fhir:id/@value/string()}" cm="{$eoc/fhir:careManager/fhir:reference/@value/string()}"/>
    default return <eoc-error>{$eoc}</eoc-error>
else
        <wrong-eoc-no xmlid="{$o/@xml:id/string()}">{$o/fhir:subject}</wrong-eoc-no>
}
</order-type>

let $log := util:log-app('TRACE','apps.nabu', $result)
return
    $result