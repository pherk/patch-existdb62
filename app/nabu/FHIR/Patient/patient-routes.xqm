xquery version "3.0";

(:~
: Defines all the RestXQ endpoints for patient queries
: @author Peter Herkenrath
: @version 1.0
: @see http://enahar.org
:
:)
module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients";

import module namespace patutils = "http://enahar.org/exist/apps/nabu/patutils" at "/db/apps/nabu/FHIR/Patient/patutils.xqm";
import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";
import module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize" at "../../FHIR/meta/serialize-fhir-resources.xqm";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-patient:base    := '/db/apps/nabuData/data/FHIR/Patients';
declare variable $r-patient:history := concat($config:history-data,'/Patients');

declare %private function r-patient:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <patients xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </patients>
};

declare %private function r-patient:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare function r-patient:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = concat($config:history-data,'/Patients'))
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
               system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, concat($config:history-data,'/Patients'), $nameHistory)
                    )
        )
};


(:~
 : GET: /nabu/patients/{$pid}/orbis-pnr
 : Retrieve the demographic of an patient identified by ORBIS PatNr.
 : 
 : @param  $pid  patient id
 : 
 : @return <Patient/>
 : 
 : TODO move to patients()
 :)
declare 
    %rest:GET
    %rest:path("/nabu/patients/{$pid}/orbis-pnr")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:produces("application/xml", "text/xml")
function r-patient:patientByIdentifierXML(
      $pid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
      ) as item()
{
    let $coll := collection('/db/apps/nabuData/data/FHIR/Patients')
    let $p := $coll/fhir:Patient[fhir:identifier[fhir:value/@value=$pid]]
    return
        if (count($p)=1)
        then $p
        else if (count($p)>1)
        then r-patient:rest-response(407, 'too many demographic found.')
        else r-patient:rest-response(407, 'Patient demographic not found.')
};


(:~
 : GET: /nabu/patients/{$pid}
 : get patient and return demographics as XML.
 : 
 : @param   $pid  patient id
 : 
 : @return <Patient/>
 :)
declare
    %rest:GET
    %rest:path("nabu/patients/{$pid}")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:consumes("application/xml")
    %rest:produces("application/xml")
function r-patient:patientByIDXML(
      $pid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $coll := collection('/db/apps/nabuData/data/FHIR/Patients')
    let $p := $coll/fhir:Patient[fhir:id[@value = $pid]]
    return
        if (count($p)=1)
        then $p
        else if (count($p)=0)
        then r-patient:rest-response(407, 'Patient demographic not found.')
        else r-patient:rest-response(407, 'Patient demographic, version error.')
};

(:~
 : GET: /nabu/patients/{$pid}
 : get patient and return demographics as XML.
 : 
 : @param   $pid  patient id
 : 
 : @return <Patient/>
 :)
declare
    %rest:GET
    %rest:path("/nabu/patients/{$pid}")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
function r-patient:patientByIDJSON(
      $pid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $coll := collection('/db/apps/nabuData/data/FHIR/Patients')
    let $p := $coll/fhir:Patient[fhir:id[@value = $pid]]
    return
        if (count($p)=1)
        then serialize:resource2json($p, false(),"4.3")
        else if (count($p)=0)
        then r-patient:rest-response(407, 'Patient demographic not found.')
        else r-patient:rest-response(407, 'Patient demographic, version error.')
};

(:~
 : GET: /nabu/patients
 : Search patients using a given field (name, bday, pid) and a (lucene) query string.
 : 
 : @param $start
 : @param $length
 : @param $name
 : @param $bday
 : @param $pid patient identifier or medicalRecordNumber
 : @return json array
 : 
 : @todo start length nyi
 :)
declare 
    %rest:GET
    %rest:path("/nabu/patients")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:query-param("start",  "{$start}",  "1")
    %rest:query-param("length", "{$length}", "15")
    %rest:query-param("name",   "{$name}",   "")
    %rest:query-param("given",  "{$given}",  "")
    %rest:query-param("birthDate", "{$birthDate}", "")
    %rest:query-param("use",    "{$use}", "official")
    %rest:query-param("pid",    "{$pid}",    "")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-patient:patientsJSON(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    , $name as xs:string*
    , $given as xs:string*
    , $birthDate as xs:string*
    , $use as xs:string*
    , $pid as xs:string*
    , $active as xs:string*
    )
{
    let $tstart := util:system-time()
    let $coll := collection('/db/apps/nabuData/data/FHIR/Patients')
    let $hits2 := if ($name="" and $given="" and $birthDate="" and $pid="")
        then () (: should give sensible HTTP error $coll/fhir:Patient[fhir:active[@value=$active]] :)
        else if ($given="" and $birthDate="" and $pid="")
        then let $p0 := $coll/fhir:Patient[fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:active[@value=$active]]
             return $p0
        else if ($name="" and $given="" and $pid="" and string-length($birthDate)>6)
        then
            let $ps := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][fhir:active[@value=$active]]
            return
                $ps
        else if ($pid="")
        then
            let $lll := util:log-app('TRACE','apps.nabu',concat($name,',',$given,'*',$birthDate))
            let $ps0 := if ($birthDate="")
                then $coll/fhir:Patient[fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:name[fhir:use[@value=$use]]/fhir:given[starts-with(@value,$given)]]
                else if($name!='' and $given!='')
                then if (string-length($birthDate)>4)
                    then 
                        let $ps0 := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][matches(fhir:name/fhir:family/@value,$name)][matches(fhir:name/fhir:given/@value,$given)]
                        return $ps0
                    else
                        let $ps0 := $coll/fhir:Patient[fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:name[fhir:use[@value=$use]]/fhir:given[starts-with(@value,$given)]][fhir:birthDate[starts-with(@value,$birthDate)]]
                        return $ps0
                else if (($name!='' or $given!='') and string-length($birthDate)>2)
                then
                    let $ps0 := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:name[fhir:use[@value=$use]]/fhir:given[starts-with(@value,$given)]]
                    return $ps0
                else ()
                
            let $lll := util:log-app('TRACE','apps.nabu',count($ps0))

            return $ps0/../fhir:Patient[fhir:active[@value=$active]]
        else
            let $ps0 := $coll/fhir:Patient[fhir:identifier[starts-with(fhir:value/@value,$pid)]][fhir:active[@value=$active]]
            return
                $ps0

    let $count := count($hits2)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count > $len0)
        then $len0
        else $count
    
    let $hits3 := if($count > $len0)
        then 
            for $p in $hits2
            let $n := $p/fhir:text/string()
            order by $n
            return $p
        else $hits2
    let $patients :=
            for $p in subsequence($hits3, $start , $len1)
            let $n := $p/fhir:text/string()
            order by $n
            return
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                        <id>{$p/fhir:id/@value/string()}</id>
                        <text>{$n}</text>
                    </json:value>
    let $tend := util:system-time()
    let $runtimems := (($tend - $tstart) div xs:dayTimeDuration('PT1S'))  * 1000
    let $lll := if (count($hits2)>100)
        then
            util:log-app('TRACE','apps.nabu',string-join(('json100:',count($hits2),$runtimems,$name,$given,$birthDate,$pid),':'))
        else
            util:log-app('TRACE','apps.nabu',string-join(('json:',count($hits2),$runtimems),':'))
    return
            <json:array xmlns:json="http://www.json.org">
            {   
                $patients
            }
            </json:array>
};

declare 
    %rest:GET
    %rest:path("/nabu/patientsDT")
    %rest:query-param("draw",  "{$draw}",  "1")
    %rest:query-param("start",  "{$start}",  "0")
    %rest:query-param("length", "{$length}", "10")
    %rest:query-param("search[value]",      "{$name}",      "")
    %rest:query-param("birthDate", "{$birthDate}", "")
    %rest:query-param("use",   "{$use}", "official")
    %rest:query-param("pid",       "{$pid}",       "")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-patient:patientsJSONDT(
          $draw as xs:string*
        , $start as xs:string*,  $length as xs:string*
        , $name as xs:string*, $birthDate as xs:string*
        , $use as xs:string*
        , $pid as xs:string*
        , $active as xs:string*
        )
{
    let $coll := collection('/db/apps/nabuData/data/FHIR/Patients')
    let $hits2 := if ($name="" and $given="" and $birthDate="" and $pid="")
        then $coll/fhir:Patient[fhir:active[@value=$active]]
        else if ($given="" and $birthDate="" and $pid="")
        then let $p0 := $coll/fhir:Patient[fhir:name/fhir:family[starts-with(@value,$name)]][fhir:active[@value=$active]]
             let $p1 := $p0[fhir:name/fhir:use/@value=$use]
             return $p1
        else if ($name="" and $given="" and $pid="" and string-length($birthDate)>4)
        then
            let $ps0 := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]]
            let $ps  := $ps0[fhir:active[@value=$active]]
            return
                $ps
        else if ($pid="")
        then
            let $lll := util:log-app('TRACE','apps.nabu',concat($name,',',$given,'*',$birthDate))
            let $ps0 := if ($birthDate="")
                then $coll/fhir:Patient[fhir:name/fhir:family[starts-with(@value,$name)]][fhir:name/fhir:given[starts-with(@value,$given)]]
                else if($name!='' and $given!='')
                then if (string-length($birthDate)>6)
                    then 
                        let $ps0 := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][matches(fhir:name/fhir:family/@value,$name)][matches(fhir:name/fhir:given/@value,$given)]
                        return $ps0
                    else 
                        let $ps0 := $coll/fhir:Patient[fhir:name/fhir:family[starts-with(@value,$name)]][fhir:name/fhir:given[starts-with(@value,$given)]][fhir:birthDate[starts-with(@value,$birthDate)]]
                        return $ps0
                else 
                    let $ps0 := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][fhir:name/fhir:family[starts-with(@value,$name)]][fhir:name/fhir:given[starts-with(@value,$given)]]
                    return $ps0
 
            let $lll := util:log-app('TRACE','apps.nabu',count($ps0))

            return $ps0[fhir:active[@value=$active]][fhir:name/fhir:use/@value=$use]
        else
            let $ps0 := $coll/fhir:Patient[fhir:identifier[starts-with(fhir:value/@value,$pid)]][fhir:active[@value=$active]]
            return
                $ps0
                
    let $sorted-hits := for $d in $hits2
            order by $d/fhir:name[fhir:use/@value='official']/family/@value/string(),$d/fhir:name[fhir:use/@value='official']/given/@value/string()  collation "?lang=de-DE"
            return
                $d
    let $rtot := count($coll)
    let $count := count($sorted-hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $limited := if ($length='*')
        then $sorted-hits
        else subsequence($sorted-hits, xs:integer($start)+1, $len1)
    return
    <json:value xmlns:json="http://www.json.org">
        <draw>{$draw}</draw>
        <recordsTotal>{$rtot}</recordsTotal>
        <recordsFiltered>{$count}</recordsFiltered>
        <data>
            {   
                for $p in $limited
                return
                    <json:value json:array="true">
                        <id>{$p/id/@value/string()}</id>
                        <family>{$p/fhir:name[fhir:use/@value='official']/family/@value/string()}</family>
                        <given>{$p/fhir:name[fhir:use/@value='official']/given/@value/string()}</given>
                        <birthDate>{$p/birthDate/@value/string()}</birthDate>
                    </json:value>
            }
        </data>
    </json:value>
};


declare function r-patient:formatFHIRName($pat as element(fhir:Patient)) as xs:string
{
    let $name := $pat/fhir:name[fhir:use[@value='official']]
    return
        concat($name/fhir:family/@value, ', ', $name/fhir:given/@value, ', *', tokenize($pat/fhir:birthDate/@value,'T')[1])
};

(:~
 : GET: /nabu/patients
 : Search patients using given fields
 : 
 : @param $start
 : @param $length
 : @param $name
 : @param $bday
 : @param $pid
 : 
 : @return bundle <Patient/>
 :)
declare 
    %rest:GET
    %rest:path("/nabu/patients")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("start",     "{$start}",     "1")
    %rest:query-param("length",    "{$length}",    "15")
    %rest:query-param("name",      "{$name}",      "")
    %rest:query-param("given",     "{$given}",     "")
    %rest:query-param("birthDate", "{$birthDate}", "")
    %rest:query-param("use",       "{$use}", "official")
    %rest:query-param("pid",       "{$pid}",       "")
    %rest:query-param("active", "{$active}", "true")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-patient:patients(
          $realm as xs:string*
        , $loguid as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $name as xs:string*
        , $given as xs:string*
        , $birthDate as xs:string*
        , $use as xs:string*
        , $pid as xs:string*
        , $active as xs:string*
        )
{
    let $coll := collection($r-patient:base)
    let $hits2 := if ($name="" and $given="" and $birthDate="" and $pid="")
            then $coll/fhir:Patient[fhir:active[@value=$active]]
        else if ($given="" and $birthDate="" and $pid="")
        then let $p0 := $coll/fhir:Patient[fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:active[@value=$active]]
             return $p0
        else if ($name="" and $given="" and $pid="")
        then
            let $ps := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][fhir:active[@value=$active]]
            return
                $ps
        else if ($pid="")
        then
            let $lll := util:log-app('TRACE','apps.nabu',concat($name,',',$given,'*',$birthDate))
            let $ps0 := if ($birthDate="")
                then $coll/fhir:Patient[fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:name/fhir:given[starts-with(@value,$given)]]
                else if($name!='' and $given!='')
                then if (string-length($birthDate)>4)
                    then 
                        let $ps0 := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][matches(fhir:name/fhir:family/@value,$name)][matches(fhir:name/fhir:given/@value,$given)]
                        return $ps0
                    else 
                        let $ps0 := $coll/fhir:Patient[fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:name/fhir:given[starts-with(@value,$given)]][fhir:birthDate[starts-with(@value,$birthDate)]]
                        return $ps0
                else 
                    let $ps0 := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:name/fhir:given[starts-with(@value,$given)]]
                    return $ps0
 
            let $lll := util:log-app('TRACE','apps.nabu',count($ps0))

            return $ps0[fhir:active[@value=$active]]
        else
            let $ps0 := $coll/fhir:Patient[fhir:identifier[starts-with(fhir:value/@value,$pid)]][fhir:active[@value=$active]]
            return
                $ps0

    let $sorted-hits := for $d in $hits2
            order by $d/fhir:name[fhir:use[@value='official']]/fhir:family/@value/string(),$d/fhir:name[fhir:use[@value='official']]/fhir:given/@value/string()  collation "?lang=de-DE"
            return
                $d
    return
        r-patient:prepareResult($sorted-hits, $start, $length)
};

(:~
 : GET: /nabu/patients/fuzzy
 : Search patients using given fields
 : 
 : @param $name
 : @param $given
 : @param $bday
 : 
 : @return bundle <Patient/>
 :)
declare 
    %rest:GET
    %rest:path("/nabu/patients/fuzzy")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("start",     "{$start}",     "1")
    %rest:query-param("length",    "{$length}",    "15")
    %rest:query-param("name",      "{$name}",      "")
    %rest:query-param("given",     "{$given}",     "")
    %rest:query-param("birthDate", "{$birthDate}", "")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-patient:fuzzy(
              $realm as xs:string*
            , $loguid as xs:string*
            , $start as xs:string*, $length as xs:string*
            , $name as xs:string*
            , $given as xs:string*
            , $birthDate as xs:string*
            )
{
    let $coll := collection($r-patient:base)
    let $hits1 := if ($name!='' and $given!='')
        then $coll/fhir:Patient[fhir:name/fhir:family[starts-with(@value,$name)]][fhir:name/fhir:given[starts-with(@value,$given)]][fhir:active[@value='true']]
        else ()
    let $hits2 := if ($birthDate!='' and $name!='')
        then let $ps := $coll/fhir:Patient[fhir:birthDate[@value=$birthDate]]
            return $ps[fhir:name/fhir:family[starts-with(@value,$name)]][fhir:active[@value='true']]
        else ()
    let $hits3 := if ($birthDate!='' and $given!='')
        then let $ps := $coll/fhir:Patient[fhir:birthDate[@value=$birthDate]]
            return $ps[fhir:name/fhir:given[starts-with(@value,$given)]][fhir:active[@value='true']]
        else ()
    let $all   := ($hits1,$hits2,$hits3)
    let $ids := distinct-values($all/fhir:id/@value/string())
    let $sorted-hits := for $id in $ids
            let $d := head($all[fhir:id/@value=$id]) 
            order by $d/fhir:name[fhir:use[@value='official']]/family/@value/string(),$d/fhir:name[fhir:use[@value='official']]/fhir:given/@value/string()  collation "?lang=de-DE"
            return
                $d
    return
        r-patient:prepareResult($sorted-hits, $start, $length)
};

(:~
 : GET: /nabu/patients/{$id}/dups
 : Search dups of patient with id
 : 
 : @param $pid
 : 
 : @return bundle <Patient/>
 :)
declare 
    %rest:GET
    %rest:path("/nabu/patients/{$id}/dups")
    %rest:query-param("id",     "{$id}", "")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-patient:dups(
          $realm as xs:string*
        , $loguid as xs:string*
        , $id as xs:string*
        ) as item()
{
    let $coll := collection($r-patient:base)
    let $p := $coll/fhir:Patient[fhir:id[@value=$id]]
    return
        if (count($p)=1)
        then
            let $bd := $p/fhir:birthDate/@value/string()
            let $nm := $p/fhir:name[fhir:use[@value='official']]/fhir:family/@value/string()
            let $hits2 :=
                let $dups0 := $coll/fhir:Patient[fhir:birthDate[@value=$bd]]
                let $dups  := $dups0[fhir:name/fhir:family[starts-with(@value,$nm)]]
                return
                if (count($dups)>1)
                then
                    for $d in $dups
                    let $dis := string-join(
                            (
                              $d/fhir:name[fhir:use[@value='official']]/fhir:family/@value
                            , $d/fhir:name[fhir:use[@value='official']]/fhir:given/@value
                            , $d/fhir:birthDate/@value
                            , $d/fhir:extension[@url="#patient-presenting-problem"]/fhir:valueString/@value
                            )
                            ,', ')
                    order by $dis collation "?lang=de-DE"
                    return
                        let $dg := $d/fhir:name[fhir:use[@value='official']]/fhir:given/@value/string()
                        let $pg := $p/fhir:Patient/fhir:name[fhir:use[@value='official']]/fhir:given/@value /string()
                        return
                            if ($d/fhir:id/@value = $p/fhir:id/@value) 
                            then ()
                            else if (starts-with($dg,$pg) or starts-with($pg,$dg))
                            then
                                <p>{$dis}</p>
                            else ()
                else ()
            return
                <dups>{$hits2}</dups>
        else <dups/>
};


(:~
 : PUT: /nabu/patients
 : Update an existing patient or store a new one.
 : 
 : @param $content request body (xml)
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/nabu/patients")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-patient:putPatientXML(
          $content as node()*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        )
{
    let $coll := collection($r-patient:base)
    let $isNew   := not($content//Patient/@xml:id)
    let $pid   := if ($isNew)
        then  concat("p-", util:uuid())
        else              
            let $id := $content//Patient/id/@value/string()
            let $pats := $coll/fhir:Patient[fhir:id[@value = $id]]
            let $move := r-patient:moveToHistory($pats)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content//Patient/meta/versionId/@value/string()) + 1
    let $base := $content//Patient/fhir:*[not(
                                               self::id
                                            or self::meta
                                            or self::text
                                            )]
    let $meta := $content//meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $text := patutils:generateText($content//fhir:Patient)
    let $uuid := concat("p-", util:uuid())    
    let $data :=
        <Patient xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$pid}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                <extension url="http://eNahar.org/nabu/extension#lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
            </meta>
            {$text}
            {$base}
        </Patient>
(:         
    let $log := util:log-app('TRACE','apps.nabu',$data)
:) 
    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:nabu-patients, $file, $data)
            , sm:chmod(xs:anyURI($config:nabu-patients || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:nabu-patients || '/' || $file), $config:data-group)))
        return
            (
                r-patient:rest-response(200, 'patient sucessfully stored.')
            ,   $data
            )
    } catch * {
        r-patient:rest-response(401, 'permission denied. Ask the admin.') 
    }
};


