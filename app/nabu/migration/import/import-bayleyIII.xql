xquery version "3.1";

import module namespace qrimport = "http://enahar.org/exist/apps/nabu/qr-import" at "../../FHIR/QuestionnaireResponse/qr-import.xqm";
import module namespace r-qr   = "http://enahar.org/exist/restxq/nabu/questionnaireresponses" at "../../FHIR/QuestionnaireResponse/questresponse-routes.xqm";

declare namespace fhir= "http://hl7.org/fhir";

let $quest := doc('/db/apps/nabu/FHIR/Questionnaire/q-bayleyIII.xml')/fhir:Questionnaire
let $ps    := doc('/db/apps/nabu/migration/import/BayleyTestdaten.xml')//BayleyTestdaten
let $realm := 'kikl-spz'
let $loguid := 'u-admin'
let $lognam := 'Admin'

for $p in subsequence($ps,1,1)
    let $qr := qrimport:mkBayleyIIIQR($p, $quest)
    return
        if ($qr)
        then
            (:
            r-qr:putQuestionnaireResponseXML(<content>{$qr}</content>, $realm, $loguid, $lognam)
            :)
            $qr
        else
            $p
