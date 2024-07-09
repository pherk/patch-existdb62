xquery version "3.0";

import module namespace repair="http://exist-db.org/xquery/repo/repair"
at "resource:org/exist/xquery/modules/expathrepo/repair.xql";
declare namespace exrest = "http://exquery.org/ns/restxq/exist";

(: reregistering restxq functions :)
  exrest:register-module(xs:anyURI('/db/apps/golem/plans/plan-routes.xqm'))
, exrest:register-module(xs:anyURI('/db/apps/golem/tests/test-routes.xqm'))
