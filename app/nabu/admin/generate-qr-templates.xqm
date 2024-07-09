xquery version "3.0";

import module namespace q2qr    = "http://enahar.org/exist/apps/nabu/q2qr" at "../../FHIR/QuestionnaireResponse/q2qr.xqm";
import module namespace qrxf    = "http://enahar.org/exist/apps/nabu/qr-xform" at "../../FHIR/QuestionnaireResponse/qrxform.xqm";
import module namespace qrhtml = "http://enahar.org/exist/apps/nabu/qr-html" at "../../FHIR/QuestionnaireResponse/qrxhtml.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace fhir= "http://hl7.org/fhir";

(:~
 : Transfors the Questionnaire to QuestionnaireResponse and XFORMs (editing and read-only)
 : storing the xform/xhtml in nabu/FHIR and the QR template nabuWorkflow/data/QuestionnaireResponses
 :)
let $qname := 'neons-v2018-01-08'
let $qdata-perms := "rwxrw-r--"
let $qdata-group := "spz"
let $qid  := concat('q-',$qname)
let $qrid := concat('qr-',$qname)
let $qrfhirpath := '/db/apps/nabu/data/FHIR/QuestionnaireResponse'
let $qrwfpath   := '/db/apps/nabuWorkflow/data/QuestionnaireResponses'
let $q := collection('/db/apps/nabuWorkflow/data/Questionnaires')/fhir:Questionnaire[fhir:id[@value=$qid]]
let $qr     := q2qr:transform($q)
let $qxform := qrxf:transform($q)
let $qxhtml := qrhtml:transform($q)
let $qr-filename     := concat($qrid,'.xml')
let $qxform-filename := concat($qrid,'-xform.xml')
let $qxhtml-filename := concat($qrid,'-xhtml.xml')

let $store  := system:as-user("vdba","kikl823!",
        (
          xmldb:store($qrfhirpath,$qxform-filename,$qxform)
        , sm:chmod(xs:anyURI($qrfhirpath || '/' || $qxform-filename), $qdata-perms)
        , sm:chgrp(xs:anyURI($qrfhirpath || '/' || $qxform-filename), $qdata-group)
        , xmldb:store($qrfhirpath,$qxhtml-filename,$qxhtml)
        , sm:chmod(xs:anyURI($qrfhirpath || '/' || $qxhtml-filename), $qdata-perms)
        , sm:chgrp(xs:anyURI($qrfhirpath || '/' || $qxhtml-filename), $qdata-group)
        , xmldb:store($qrwfpath,$qr-filename,$qr)
        , sm:chmod(xs:anyURI($qrwfpath || '/' || $qr-filename), $qdata-perms)
        , sm:chgrp(xs:anyURI($qrwfpath || '/' || $qr-filename), $qdata-group)
        ))
return
    <ok/>
