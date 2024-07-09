xquery version "3.1";

(:~
: Defines the RestXQ endpoints for responsibilities and managinOrganization
: @author Peter Herkenrath
: @version 1.0
: @see http://enahar.org
:
:)
module namespace r-respon = "http://enahar.org/exist/restxq/nabu/patient-responsibility";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";

import module namespace r-eoc       = "http://enahar.org/exist/restxq/nabu/eocs"       at "../../FHIR/EpisodeOfCare/episodeofcare-routes.xqm";
import module namespace r-careteam  = "http://enahar.org/exist/restxq/nabu/careteams"  at "../../FHIR/CareTeam/careteam-routes.xqm";
import module namespace r-encounter = "http://enahar.org/exist/restxq/nabu/encounters" at "../../FHIR/Encounter/encounter-routes.xqm";


declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare variable $r-respon:collpath := '/db/apps/nabuData/data/FHIR/Patients';
declare variable $r-respon:history  := concat($config:history-data,'/Patients');
declare variable $r-respon:startSPZ := "1994-06-01T08:00:00";
declare variable $r-respon:endSPZ   := "2025-04-01T23:00:00";


declare function r-respon:formatFHIRName($pat as element(fhir:Patient)) as xs:string
{
    concat($pat/fhir:name[fhir:use/@value='official']/fhir:family/@value, ', ', $pat/fhir:name[fhir:use/@value='official']/fhir:given/@value, ', *', tokenize($pat/fhir:birthDate/@value,'T')[1])
};

declare %private function r-respon:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : GET: /nabu/patients/{$pid}/responsibilities?group=arzt
 : get responsibilities for a patient
 : 
 : @param $pid
 : @param $start
 : @param $length
 : @param $group
 : 
 : @return <responsibility/>
 : 
 : @since v0.6
 : @version v0.9  merge adjacent temporal intervals
 : @todo group-role??
 :)
declare 
    %rest:GET
    %rest:path("/nabu/patients/{$id}/responsibilities")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}",  "")
    %rest:query-param("role",   "{$role}",    "")
    %rest:query-param("rangeStart", "{$rangeStart}", "1994-06-01T08:00:00")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2021-04-01T23:00:00")
    %rest:query-param("_format",   "{$format}", "full")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-respon:responsibilitiesXML(
              $id as xs:string*
            , $realm as xs:string*
            , $loguid as xs:string*
            , $lognam as xs:string*
            , $role as xs:string*
            , $rangeStart as xs:string*
            , $rangeEnd as xs:string*
            , $format as xs:string*
            ) as item()
{
    let $cts := r-careteam:careteamsXML($realm,$loguid,$lognam, $id, 'active', 'full')
    let $ct := head($cts/fhir:CareTeam)
    let $hasCT := exists($ct)
    let $name := if ($hasCT)
            then $ct/fhir:subject/fhir:display/@value/string()
            else  
                let $coll := collection($r-respon:collpath)
                let $demo := $coll/fhir:Patient[fhir:id[@value=$id]]
                return r-respon:formatFHIRName($demo)
    return
        switch ($format)
        case 'team' return
            <responsibility>
                <subject xmlns="http://hl7.org/fhir">
                    <reference value="nabu/patients/{$id}"/>
                    <display value="{$name}"/>
                </subject>
            {
                if ($hasCT)
                then $ct/fhir:participant
                else r-respon:computeCareTeam($id, $role)
            }
            </responsibility>
        default return
            <responsibility>
                <subject xmlns="http://hl7.org/fhir">
                    <reference value="nabu/patients/{$id}"/>
                    <display value="{$name}"/>
                </subject>
                { r-respon:listTeamContacts($id, $role) }
            </responsibility>
};

declare function r-respon:computeCareTeam(
          $id as xs:string*
        , $role as xs:string*
        ) as element(fhir:participant)*
{
    let $ebs := r-encounter:encountersBySubject($id, 'kikl-spz', 'u-admin', "admin", '1', '*', $r-respon:startSPZ, $r-respon:endSPZ, 'finished')
    let $mrefs := distinct-values($ebs/fhir:Encounter/fhir:participant/fhir:individual/fhir:reference/@value)
    for $mref in $mrefs
    let $ebsm  := $ebs/fhir:Encounter[fhir:participant/fhir:individual/fhir:reference[@value=$mref]]
    let $first := min($ebsm/fhir:period/fhir:start/@value/string())
    let $last  := max($ebsm/fhir:period/fhir:start/@value/string())
    let $laste := $ebsm[fhir:period/fhir:start[@value=$last]][1] (: should be only one :)
    let $role  := $laste/fhir:participant/fhir:type/fhir:coding/fhir:code/@value/string()
    order by $role, $last descending
    return
        <participant xmlns="http://hl7.org/fhir">
            <role>
                <coding>
                    <system value="http://eNahar.org/nabu/system#careteam-participant-role"/>
                    <code value="{$role}"/>
                </coding>
                <text value="{$laste/fhir:participant/fhir:type/fhir:text/@value/string()}"/>
            </role>
            <member>
                <reference value="{$laste/fhir:participant/fhir:individual/fhir:reference/@value/string()}"/>
                <display value="{$laste/fhir:participant/fhir:individual/fhir:display/@value/string()}"/>
            </member>
            <period>
                <start value="{$first}"/>
                <end value="{$last}"/>
            </period>
        </participant>
};

declare %private function r-respon:listTeamContacts(
          $id as xs:string*
        , $role as xs:string*
        ) as element(fhir:participant)*
{
        let $ebs := r-encounter:encountersBySubject($id, 'kikl-spz', 'u-admin', "admin", '1', '*', $r-respon:startSPZ, $r-respon:endSPZ, 'finished')
        for $e in $ebs/fhir:Encounter[matches(fhir:participant/fhir:type/fhir:coding/fhir:code/@value,$role)] (: TODO filter $role :)
        let $start:= $e/fhir:period/fhir:start/@value/string()
        let $end  := $e/fhir:period/fhir:end/@value/string()
        let $part := $e/fhir:participant[1] (: TODO picks only the first :)
        order by $start descending
        return    
            <participant xmlns="http://hl7.org/fhir">
                <role>
                    <coding>
                        <system value="http://eNahar.org/nabu/system#careteam-participant-role"/>
                        <code value="{$part/fhir:type/fhir:coding/fhir:code/@value/string()}"/>
                    </coding>
                    <text value="{$part/fhir:type/fhir:text/@value/string()}"/>
                </role>
                <member>
                    <reference value="{$part/fhir:individual/fhir:reference/@value/string()}"/>
                    <display value="{$part/fhir:individual/fhir:display/@value/string()}"/>
                </member>
                <period>
                    <start value="{$start}"/>
                    <end value="{$end}"/>
                </period>
            </participant>
};

(:~
 : GET: /nabu/patients/{$pid}/responsibilities?group=arzt
 : get responsibilities for a patient
 : 
 : @param $pid
 : @param $start
 : @param $length
 : @param $group
 : 
 : @return bundle for select2
 : 
 : @since v0.6
 : @todo merge adjacent temporal intervals
 : @todo group-role??
 : 
 :)
declare 
    %rest:GET
    %rest:path("/nabu/patients/{$id}/responsibilities")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:query-param("role",   "{$role}",   "")
    %rest:query-param("rangeStart", "{$rangeStart}", "1994-06-01T08:00:00")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2025-04-01T23:00:00")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-respon:responsibilitiesJSON(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $role as xs:string*
        , $rangeStart as xs:string*
        , $rangeEnd as xs:string*
        )
{
    let $ct := r-careteam:careteamsXML($realm,$loguid,$lognam, $id, 'active', 'full')/fhir:CareTeam[1]
    let $name := $ct/fhir:subject/fhir:display/@value/string()
    return
    <json:value xmlns:json="http://www.json.org">
            <data>
            {   
                for $g in distinct-values($ct/fhir:participant/fhir:role/fhir:text/@value)
                order by $g
                return
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                        <text>{$g}</text>
                        <children>
                        {
                            for $p in $ct/fhir:participant[fhir:role/fhir:text/@value=$g]
                            let $date := tokenize($p/fhir:period/fhir:end/@value,'T')[1]
                            let $a := $p/fhir:member
                            let $text := concat($a/fhir:display/@value, ' # ', $date)
                            order by $date descending
                            return
                                <json:value xmlns:json="http://www.json.org" json:array="true">
                                    <id>{substring-after($a/fhir:reference/@value,'metis/practitioners/')}</id>
                                    <text>{$text}</text>
                                </json:value>
                        }
                        </children>
                    </json:value>
            }
            </data>
    </json:value>
};

declare 
    %rest:GET
    %rest:path("/nabu/patients/{$id}/responsibilitiesOld")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:query-param("role",   "{$role}",   "")
    %rest:query-param("rangeStart", "{$rangeStart}", "1994-06-01T08:00:00")    
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2025-04-01T23:00:00")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-respon:responsibilitiesJSONOld(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $role as xs:string*
        , $rangeStart as xs:string*
        , $rangeEnd as xs:string*
        )
{
    let $ebs := r-encounter:encountersBySubject($id, $realm, $loguid, $lognam, '1', '*', $rangeStart, $rangeEnd, 'finished')
    return
    <json:value xmlns:json="http://www.json.org">
            <data>
            {   
                for $g in distinct-values($ebs/fhir:Encounter/fhir:participant/fhir:type/fhir:text/@value)
                order by $g
                return
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                        <text>{$g}</text>
                        <children>
                        {
                            for $e in $ebs/fhir:Encounter[fhir:participant/fhir:type/fhir:text/@value=$g]
                            let $date := tokenize($e/fhir:period/fhir:start/@value,'T')[1]
                            let $a := $e/fhir:participant[fhir:type/fhir:text/@value=$g]/fhir:individual
                            let $text := concat($a/fhir:display/@value, ' # ', $date)
                            order by $date descending
                            return
                                <json:value xmlns:json="http://www.json.org" json:array="true">
                                    <id>{substring-after($a/fhir:reference/@value,'metis/practitioners/')}</id>
                                    <text>{$text}</text>
                                </json:value>
                        }
                        </children>
                    </json:value>
            }
            </data>
    </json:value>
};

(:~
 : GET: /nabu/patients/{$pid}/oe
 : get patient and return oe as XML.
 : 
 : @param   $pid  patient id
 : 
 : @return <Patient/>
 :)
declare
    %rest:GET
    %rest:path("/nabu/patients/{$pid}/oe")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:produces("application/xml", "text/xml")
function r-respon:managingOrganizationByIDXML(
      $pid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $coll := collection($r-respon:collpath)
    let $p := $coll/fhir:Patient[fhir:id[@value=$pid]]
    return
        if (count($p)=1)
        then $p/fhir:managingOrganization
        else if (count($p)=0)
        then r-respon:rest-response(407, 'Patient OE not found.')
        else r-respon:rest-response(407, 'Patient OE, version error.')
};
