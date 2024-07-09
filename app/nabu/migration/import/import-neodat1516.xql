xquery version "3.1";

import module namespace qrimport = "http://enahar.org/exist/apps/nabu/qr-import" at "../../FHIR/QuestionnaireResponse/qr-import.xqm";
import module namespace r-qr   = "http://enahar.org/exist/restxq/nabu/questionnaireresponses" at "../../FHIR/QuestionnaireResponse/questresponse-routes.xqm";
declare namespace fhir= "http://hl7.org/fhir";


let $quest := doc('/db/apps/nabu/FHIR/Questionnaire/q-neodat.xml')/fhir:Questionnaire
let $ps := doc('/db/apps/nabu/migration/import/GEB-JG-2015-16-utf8.xml')//patient
let $realm := 'kikl-spz'
let $loguid := 'u-admin'
let $lognam := 'Admin'

for $p in subsequence($ps,2,1)
return
    if (qrimport:isAlreadyImported($p))
    then ()
    else
        let $qr := qrimport:mkNeoDatQR($p,(),$quest)
        return
            if ($qr)
            then
            (:
            - check GBA-FG NeoNachsorge tag
            - check Enc BayleyIII
            - check CarePlan
            :)
                let $check := qrimport:checkPatData($p)
                return
            (:
                    r-qr:putQuestionnaireResponseXML(<content>{$qr}</content>, $realm, $loguid, $lognam)
            :)
                    $qr
            else
                $p
