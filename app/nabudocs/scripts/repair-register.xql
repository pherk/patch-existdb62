xquery version "3.0";

import module namespace repair="http://exist-db.org/xquery/repo/repair"
at "resource:org/exist/xquery/modules/expathrepo/repair.xql";
declare namespace exrest = "http://exquery.org/ns/restxq/exist";

(: repair expath repo 
  repair:clean-all()
, repair:repair()
:)
(: reregistering restxq functions :)
exrest:register-module(xs:anyURI('/db/apps/nabudocs/modules/letter-routes.xqm'))

