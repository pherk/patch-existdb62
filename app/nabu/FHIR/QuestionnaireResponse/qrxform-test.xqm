xquery version "3.0";

import module namespace qrxf = "http://enahar.org/exist/apps/nabu/qr-xform" at "../../FHIR/QuestionnaireResponse/qrxform.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace fhir= "http://hl7.org/fhir";

let $data-perms := "rwxrw-r--"
let $data-group := "spz"
let $path := '/db/apps/nabu/FHIR/QuestionnaireResponse/'
let $pid  := 'q-hilfsmittel-v2018-04-08'
let $pid  := 'q-soziales-v2019-09-30'
let $file := concat('qr-',substring-after($pid,'q-'),'-xform.xml')
let $q    := collection('/db/apps/nabuWorkflow/data/Questionnaires')/fhir:Questionnaire[fhir:id/@value=$pid]
let $data := qrxf:transform($q)
return
    system:as-user("admin","kikl968",
            (
              xmldb:store($path, $file, $data)
            , sm:chmod(xs:anyURI($path || '/' || $file), $data-perms)
            , sm:chgrp(xs:anyURI($path || '/' || $file), $data-group)
            ))
