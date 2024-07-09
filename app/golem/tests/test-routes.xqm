xquery version "3.0";
module namespace retest = "http://enahar.org/exist/apps/restxq/golem-tests";

import module namespace rec       = "http://enahar.org/exist/apps/golem/context"        at "/db/apps/golem/context/context.xqm";

import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients"      at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";

declare namespace   rest = "http://exquery.org/ns/restxq";
declare namespace   http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";


declare namespace golem = "http://enahar.org/ns/1.0/golem";
declare namespace  fhir = "http://hl7.org/fhir";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";

declare variable $retest:qcoll := '/db/apps/nabuWorkflow/data/Questionnaires';
declare variable $retest:data := '/db/apps/golem/data';

declare function local:addNamespaceToXML($noNamespaceXML as element(*),$namespaceURI as xs:string) as element(*)
{
    element {fn:QName($namespaceURI,fn:local-name($noNamespaceXML))}
    {
         $noNamespaceXML/@*
        ,for $node in $noNamespaceXML/node()
            return
                if (exists($node/node()))
                then local:addNamespaceToXML($node,$namespaceURI)
                else if ($node instance of element()) 
                then element {fn:QName($namespaceURI,fn:local-name($node))}{$node/@*}
                else $node
    }
};
declare %private function retest:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : GET: nabu/test/item
 : execute calculation for test item with id within context.
 : requests are parametrized but not stored into db
 : 
 : @param @item    ItemId form QR
 : @param @value   ItemValue
 : @param $context PatientId
 : @return  </results>
 :)
declare
    %rest:GET
    %rest:path("golem/test/item")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("item",   "{$iid}")
    %rest:query-param("value",  "{$ival}")
    %rest:query-param("context","{$cid}")
    %rest:produces("application/xml")
function retest:evalTestItem(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $iid as xs:string*
        , $ival as xs:string*
        , $cid as xs:string*
        ) as item()
{
    let $lll   := util:log-app('TRACE','apps.nabu',string-join(($iid,$ival,$cid),'-'))
    let $item := collection($retest:qcoll)/fhir:Questionnaire//fhir:item[fhir:linkId[@value=$iid]]
    let $type  := 'integer'

    let $pcntxt := rec:getPatientContext($realm,$loguid,$lognam,$cid)
    let $pid := $pcntxt/fhir:Patient/fhir:id/@value/string()
    let $other := rec:getAdditionalPatientContext($realm,$loguid,$lognam,$pid,$rec:q-bayleyIII-id)
    let $age := rec:age($pcntxt, $other)
    let $pid := $pcntxt/fhir:Patient/fhir:id/@value/string()
    let $tid  := retest:test($iid)
    let $norms := collection("/db/apps/golem/data")/testnorms[id/@value=concat($tid,'-norms')]
    let $out0 := retest:evalNorm($tid,$norms,'raw2subscale',$iid,$ival,$age)
    let $out1 := retest:evalNorm($tid,$norms,'raw2devage',$iid,$ival,$age)
    return
        <result xmlns="http://enahar.org/ns/1.0/golem">
            { $item }
            { ($out0 , $out1) }
        </result>
};

declare function retest:evalNorm(
          $tid as xs:string
        , $norms as item()
        , $map as xs:string
        , $itemid as xs:string
        , $itemval as xs:string
        , $age as xs:string
    ) as item()*
{
        switch($map)
        case 'raw2subscale' return
                    retest:raw2subscale($tid, $norms, $itemid, $itemval, $age)
        case 'raw2devage' return
                    retest:raw2devage($tid, $norms, $itemid, $itemval)
        default return <error/>
};

declare function retest:raw2subscale(
          $tid as xs:string
        , $norms as item()
        , $itemid as xs:string
        , $itemval as xs:string
        , $age as xs:string
    ) as item()
{
    let $lll := util:log-app('TRACE','apps.nabu',$age)
    let $table := $norms/table[id/@value='raw2subscale']
    let $valid := retest:valid($table,$itemval)
    let $scale := retest:scale($itemid)
    let $subtable := retest:matchAge($table,$age)
    let $val :=
        if (count($subtable)=1)
        then
            let $lll := util:log-app('TRACE','apps.nabu',$subtable)
            let $row := $subtable/row[raw[low/@value<=xs:int($itemval)][high/@value>=xs:int($itemval)][starts-with(id/@value,$scale)]]
            let $lll := util:log-app('TRACE','apps.nabu',$row)
            return
                $row/subscale/@value/string()
        else
            'undef'
    return
        <out>
            <id value="{string-join(($tid,$scale,'scale'),'-')}"/>
            <value value="{$val}"/>
        </out>
};

declare function retest:raw2devage(
          $tid as xs:string
        , $norms as item()
        , $itemid as xs:string
        , $itemval as xs:string
    ) as item()
{
    let $table := $norms/table[id/@value='raw2devage']
    let $valid := retest:valid($table,$itemval)
    let $scale := retest:scale($itemid)
let $lll := util:log-app('TRACE','apps.nabu',$itemid)
let $lll := util:log-app('TRACE','apps.nabu',$itemval)
let $lll := util:log-app('TRACE','apps.nabu',$scale)
    let $row := $table/row[raw[low/@value<=xs:int($itemval)][high/@value>=xs:int($itemval)][starts-with(id/@value,$scale)]]
let $lll := util:log-app('TRACE','apps.nabu',$row)
    return
        <out>
            <id value="{string-join(($tid,$scale,'age'),'-')}"/>
            <value value="{$row/devage/@value/string()}"/>
        </out>
};

declare function retest:test(
          $id as xs:string
    ) as xs:string
{
    tokenize($id,'-')[1]
};

declare function retest:scale(
          $id as xs:string
    ) as xs:string
{
    tokenize($id,'-')[2]
};

declare function retest:valid(
          $table as item()
        , $value as xs:string
    ) as xs:boolean
{
    true()    
};

declare function retest:matchAge(
          $table as item()
        , $age as xs:string
    ) as item()*
{
    $table/subtable[age[low/@value <= $age][high/@value >= $age]]
};
