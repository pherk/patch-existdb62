xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";


let $oc := collection('/db/apps/nabuCom/data/')
(: 
 :
let $os := $oc/fhir:EpisodeOfCare[fhir:subject/fhir:reference[starts-with(@value,'p-')]]
for $o in $os
let $val := concat('nabu/patients/',$o/fhir:subject/fhir:reference/@value)
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:subject/fhir:reference/@value with $val
   )

 
let $os := $oc/fhir:Condition[fhir:subject/fhir:reference[starts-with(@value,'p-')]]
for $o in $os
let $val := concat('nabu/patients/',$o/fhir:subject/fhir:reference/@value)
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:subject/fhir:reference/@value with $val
   )

let $os := $oc/fhir:Condition[fhir:asserter/fhir:reference[starts-with(@value,'c-')]]
for $o in $os
let $val := concat('metis/practitioners/', $o/fhir:asserter/fhir:reference/@value)
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:asserter/fhir:reference/@value with $val
   )
   
let $os := $oc/fhir:CareTeam[fhir:context/fhir:reference[starts-with(@value,'c-')]]
for $o in $os
let $val := concat('nabu/episodeofcares/', $o/fhir:context/fhir:reference/@value)
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:context/fhir:reference/@value with $val
   )

let $os := $oc/fhir:CareTeam[fhir:lastModifiedBy/fhir:reference[starts-with(@value,'c-')]]
for $o in $os
let $val := concat('metis/practitioners/', $o/fhir:lastModifiedBy/fhir:reference/@value)
order by $o/fhir:lastModified/@value/string() descending
return
   system:as-user('vdba','kikl823!',
        update value $o/fhir:lastModifiedBy/fhir:reference/@value with $val
   )

let $os := $oc/fhir:EpisodeOfCare[fhir:statusHistory/fhir:extension[@url="#eoc-workflow-change-author"]/fhir:valueReference/fhir:reference[starts-with(@value,'c-')]]
for $o in $os
let $val := $o/fhir:statusHistory/fhir:extension[@url="#eoc-workflow-change-author"]/fhir:valueReference/fhir:reference[starts-with(@value,'c-')]/@value
order by $o/fhir:lastModified/@value/string() descending
return
    system:as-user('vdba','kikl823!',
        for $v in $val
        return
        update value 
                $o/fhir:statusHistory/fhir:extension[@url="#eoc-workflow-change-author"]/fhir:valueReference/fhir:reference[@value=$v]/@value 
            with concat('metis/practitioners/',$v)
   )

let $os := $oc/fhir:Task[fhir:requester/fhir:agent/fhir:reference[starts-with(@value,'c-')]]
for $o in $os
let $val := $o/fhir:requester/fhir:agent/fhir:reference/@value/string()
order by $o/fhir:lastModified/@value/string() descending
return
    system:as-user('vdba','kikl823!',
        update value 
                $o/fhir:requester/fhir:agent/fhir:reference/@value 
            with concat('metis/practitioners/',$val)
   )

let $os := $oc/fhir:Task[fhir:note/fhir:authorReference/fhir:reference[starts-with(@value,'c-')]]
for $o in $os
let $val := $o/fhir:note/fhir:authorReference/fhir:reference[starts-with(@value,'c-')]/@value/string()
order by $o/fhir:lastModified/@value/string() descending
return
    system:as-user('vdba','kikl823!',
            for $v in $val
        return
        update value 
                $o/fhir:note/fhir:authorReference/fhir:reference[@value=$v]/@value 
            with concat('metis/practitioners/',$v)
   )

let $os := $oc/fhir:Task[fhir:requester/fhir:agent/fhir:reference[@value='metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
    system:as-user('vdba','kikl823!',
        update value 
                $o/fhir:requester/fhir:agent/fhir:reference/@value with ""
   )


let $os := $oc/fhir:Task[fhir:lastModifiedBy/fhir:reference[@value='metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
    system:as-user('vdba','kikl823!',
        update value 
                $o/fhir:lastModifiedBy/fhir:reference/@value with ""
   )

let $os := $oc/fhir:Task[fhir:note/fhir:authorReference/fhir:reference[@value='metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
    system:as-user('vdba','kikl823!',
        update value 
                $o/fhir:note/fhir:authorReference/fhir:reference/@value with ""
   )

let $os := $oc/fhir:CareTeam[fhir:participant[fhir:member/fhir:reference[@value='metis/practitioners/']]]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
    system:as-user('vdba','kikl823!',
        update value 
                $o/fhir:participant/fhir:member/fhir:reference[@value='metis/practitioners/']/@value with ""
   )

let $os := $oc/fhir:Condition[fhir:asserter/fhir:reference[@value='metis/practitioners/']]
for $o in $os
order by $o/fhir:lastModified/@value/string() descending
return
    system:as-user('vdba','kikl823!',
        (
          update value $o/fhir:asserter/fhir:reference/@value with "metis/practitioners/u-admin"
        , update value $o/fhir:asserter/fhir:display/@value with "import-bot"
        )
   )
:)
let $os := $oc/fhir:Task[.//fhir:reference[@value='metis/practitioners/']]
for $o in $os
let $val := concat('metis/practitioners/', $o/fhir:asserter/fhir:reference/@value)
order by $o/fhir:lastModified/@value/string() descending
return
 $o

