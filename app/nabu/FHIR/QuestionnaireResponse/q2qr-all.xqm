xquery version "3.0";

import module namespace q2qr = "http://enahar.org/exist/apps/nabu/q2qr" at "../../FHIR/QuestionnaireResponse/q2qr.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace fhir= "http://hl7.org/fhir";

let $data-perms := "rwxrw-r--"
let $data-group := "spz"
let $qrpath := '/db/apps/nabuWorkflow/data/QuestionnaireResponses/'
let $qids  := 
        (
          'q-bayleyIII-v2017-08-08'
        , 'q-neodat-v2017-08-08'
        , 'q-neons-v2018-01-08'
        , 'q-hilfsmittel-v2018-04-08'
        )

for $qid in $qids
let $file := concat('qr-',substring-after($qid,'q-'),'.xml')
let $q    := collection('/db/apps/nabuWorkflow/data/Questionnaires')/fhir:Questionnaire[fhir:id[@value=$qid]]
let $data := q2qr:transform($q)
return
    system:as-user("admin","kikl968",
            (
              xmldb:store($qrpath, $file, $data)
            , sm:chmod(xs:anyURI($qrpath || '/' || $file), $data-perms)
            , sm:chgrp(xs:anyURI($qrpath || '/' || $file), $data-group)
            ))
    
