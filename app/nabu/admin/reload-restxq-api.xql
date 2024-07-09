xquery version "3.0";

import module namespace repair="http://exist-db.org/xquery/repo/repair"
at "resource:org/exist/xquery/modules/expathrepo/repair.xql";
declare namespace exrest = "http://exquery.org/ns/restxq/exist";

(: reregistering restxq functions :)
  exrest:register-module(xs:anyURI('/db/apps/nabudocs/modules/letter-routes.xqm'))
(: 
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Appointment/appointment-routes.xqm'))
:)
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Encounter/encounter-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Encounter/eo-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Encounter/epdf-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Encounter/orphan-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Order/order-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Patient/patient-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Patient/everything-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Patient/responsibility-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Condition/condition-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Communication/communication-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Composition/composition-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/CarePlan/careplan-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/CarePlan/cp-activity-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/CareTeam/careteam-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Goal/goal-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Protocol/protocol-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Questionnaire/questionnaire-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/QuestionnaireResponse/questresponse-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/QuestionnaireResponse/qrpdf-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/nabu/FHIR/Task/task-routes.xqm'))

 
, exrest:register-module(xs:anyURI('/db/apps/metis/FHIR/Device/device-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/metis/FHIR/Group/group-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/metis/FHIR/Leave/leave-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/metis/FHIR/Location/location-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/metis/FHIR/Organization/organization-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/metis/FHIR/Practitioner/practitioner-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm'))

, exrest:register-module(xs:anyURI('/db/apps/eNahar/cal/cal-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/eNahar/holidays/holiday-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/eNahar/schedule/schedule-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/eNahar/wkload/wk-routes.xqm'))

, exrest:register-module(xs:anyURI('/db/apps/terminology/claml/claml-routes.xqm'))

, exrest:register-module(xs:anyURI('/db/apps/golem/plans/plan-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/golem/tests/test-routes.xqm'))

