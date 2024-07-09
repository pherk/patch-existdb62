xquery version "3.0";

module namespace recnd = "http://enahar.org/exist/apps/golem/conditions";

import module namespace refun = "http://enahar.org/exist/apps/golem/functions" at "/db/apps/golem/context/funs.xqm";

declare namespace golem = "http://enahar.org/ns/1.0/golem";
declare namespace  fhir = "http://hl7.org/fhir";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";



declare function recnd:checkCondition(
        $condition as element(fhir:condition)?
      , $context as element(golem:context)
    ) as xs:boolean
{
    let $lll := util:log-app('TRACE', 'apps.nabu', $condition/fhir:description/@value/string())
    return
        switch ($condition/fhir:kind/@value)
        case 'applicability' return recnd:evalApplicability($condition/fhir:expression/@value,$context)
        default return true()
};



declare function recnd:evalApplicability(
        $expr as xs:string
      , $context as element(golem:context)
    ) as xs:boolean
{
    let $lll := util:log-app('TRACE', 'apps.nabu', $expr)
    let $res   := util:eval($expr)
    return
        $res
};

