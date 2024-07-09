xquery version "3.0";

(: 
 : Encounter routes
 : Defines all the RestXQ endpoints used by the XForms.
 : News with v0.8.25
 : Encounters are distributed in 
 :        subdirs per year (2004-2025)
 :   plus planned (status=('planned','tentative))
 :   plus invalid (invalid date)
 : updateStatus()
 :   moves the Encounter to the year subdir from planned if status changes (and reverse)
 : 
 : @since 0.1
 : @version 0.8.25
 : @author Peter Herkenrath (Copyright 2015-17)
 : 
 :)
module namespace r-encounter = "http://enahar.org/exist/restxq/nabu/encounters";

import module namespace config = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-encounter:base    := '/db/apps/nabuEncounter/data';
declare variable $r-encounter:planned := '/db/apps/nabuEncounter/data/planned';
declare variable $r-encounter:history := concat($config:history-data, '/Encounters');
declare variable $r-encounter:valid-status  := ('tentative','planned','arrived','triaged','in-progress','onleave','cancelled','entered-in-error','unknown');

(:~
 : 
 : HTTP RESPONSE CODES USED
 : 
 : 200 - Operation Success
 : 420 - Operation Failed
 : 400 - Bad Request Syntax
 : 410 - Resource Not Available
 : 405 - restXQ operation call error
 : 500 - Internal Server Error
 : 
 : Response header contains a 'mf-message' field where the value has meaning in context.
 : 
 :)

(:~ moveToHistory
 : Move to history
 : 
 : @param $objects
 : @return ()
 :)
declare function r-encounter:moveToHistory(
      $objects as element()*
    ) 
{
    let $history := $r-encounter:history
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $history)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $history, $nameHistory)
                    )
        )
};

declare %private function r-encounter:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <encounters xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </encounters>
};


declare %private function r-encounter:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(: 
 : select (sub-) collections for efficiency
 : 
 : TODO comparing $status order dependant
 :)
declare %private function r-encounter:collections(
      $status as xs:string*
    , $tmin as xs:string
    , $tmax as xs:string
    , $base as xs:string
    ) as xs:string*
{
    let $planned := ('planned','tentative')
    let $hasplanned := if ($status=$planned)
            then concat($base,'/planned')
            else ()
    let $onlyplanned :=
            every $s in $status
            satisfies
                $s=$planned
    let $openrange := $tmin='' and $tmax=''
    let $years := if ($onlyplanned)
        then ()
        else if ($openrange)
        then $base
        else
            let $ymin := if ($tmin!='')
                then let $y := xs:integer(substring($tmin,1,4))
                    return max(($y,2004))
                else 2004
            let $ymax := if ($tmax!='')
                then let $y := xs:integer(substring($tmax,1,4))
                    return min(($y,2025))
                else 2025
            let $inc := 0
            for $y in ($ymin to ($ymax+$inc))
            return
                concat($base,'/',$y)
    let $lll := util:log-app('TRACE','apps.nabu',string-join(($status,$tmin,$tmax,$onlyplanned,$openrange,$hasplanned,$years),':'))
    return
        ($hasplanned,$years)
};

(:~
 : GET: nabu/encounters/{$id}
 : List encounter with id.
 : 
 : @return  <Encounter>...</Encounter>
 :)
declare
    %rest:GET
    %rest:path("nabu/encounters/{$id}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-encounter:encounterByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        ) as item()
{
    let $coll := collection($r-encounter:base)
    let $encs := $coll/fhir:Encounter[fhir:id[@value=$id]]
    return
        if (count($encs)=1)
        then $encs
        else if (count($encs)>1)
        then r-encounter:rest-response(404, concat('Encounter with ID: ',$id, ' too many found. Ask the Admin.'))
        else r-encounter:rest-response(404, concat('Encounter with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : update subject 
 : 
 : @param $id
 : @param $realm
 : @param $loguid
 : @param $pid
 : @param $pnam
 : 
 : @return 
 :)
declare function r-encounter:updateSubject(
      $id as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $pid as xs:string*
    , $pnam as xs:string*
    ) 
{
    let $coll := collection($r-encounter:base)
    let $res := $coll/fhir:Encounter[fhir:id[@value=$id]]
    return
        if (count($res)=1)
        then    
            system:as-user('vdba', 'kikl823!',
                (
                  update value $res/fhir:subject/fhir:reference/@value with concat('nabu/patients/',$pid)
                , update value $res/fhir:subject/fhir:display/@value with $pnam
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:reference/@value with concat('metis/practitioners/',$loguid)
                , update value $res/fhir:meta/fhir:extension[@url="http://eNahar.org/nabu/extension#lastUpdatedBy"]//fhir:display/@value with $lognam
                , update value $res/fhir:meta/fhir:lastUpdated/@value with current-dateTime()
                ))
        else ()
};


(:~
 : GET: /nabu/encounters/{$id}/_history
 : get encounter history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  encounter bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/encounters/{$id}/_history")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-encounter:encounterHistoryByID(
      $id as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $coll := collection(($r-encounter:base,$r-encounter:history))
    let $hits  := $coll/fhir:Encounter[fhir:id[@value=$id]] 
    return
        r-encounter:prepareHistoryBundle($id, $hits)
};

(:~
 : GET: /nabu/encounter/{$id}/_history/{$vid}
 : get encounter history with id $id and version $vid
 : 
 : @param $id encounter id
 : @param $vid version id
 : 
 : @return  encounter bundle
 :)
declare
    %rest:GET
    %rest:path("/nabu/encounters/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-encounter:encounterVersionByID(
      $id as xs:string*
    , $vid as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    )
{
    let $coll := collection(($r-encounter:base,$r-encounter:history))
    let $hits  := $coll/fhir:Encounter[fhir:id[@value=$id]][fhir:meta/fhir:versionId/@value=$vid]
    return
        r-encounter:prepareHistoryBundle($id, $hits)
};

declare %private function r-encounter:prepareHistoryBundle($id, $entries)
{
    let $serverip := 'http://enahar.org'
    return
        <feed>
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <type value="history"/>
            <title value=""/>
            <link rel="self"      href="{$serverip}/exist/restxq/nabu/encounters/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/nabu"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{current-dateTime()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/meta/versionId/@value)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/exist/restxq/nabu/encounters/{$id}/_history/{$e/meta/versionId/@value/string()}</id>
                        <updated>{$e/lastModified/@value/string()}</updated>
                        <published>{$e/lastModified/@value/string()}</published>
                        <link rel="self" href="{$serverip}/exist/restxq/nabu/encounters/{$id}/_history/{$e/meta/versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </feed>
};

(:~
 : Search parameters FHIR 0.4
 : date	date	A date within the period the Encounter lasted	Encounter.period
 : episodeofcare	reference	An episode of care that this encounter should be recorded against	Encounter.episodeOfCare
 : identifier	token	Identifier(s) by which this encounter is known	Encounter.identifier
 : indication	reference	Reason the encounter takes place (resource)	Encounter.indication
 : length	number	Length of encounter in days	Encounter.length
 : location	reference	Location the encounter takes place	Encounter.location.location
 : location-period	date	Time period during which the patient was present at the location	Encounter.location.period
 : part-of	reference	Another Encounter this encounter is part of	Encounter.partOf
 : participant-type	token	Role of participant in encounter	Encounter.participant.type
 : patient	reference	The patient present at the encounter	Encounter.patient
 : special-arrangement	token	Wheelchair, translator, stretcher, etc	Encounter.hospitalization.specialArrangement
 : status	token	planned | arrived | in progress | onleave | finished | cancelled	Encounter.status
 : type	token	Specific type of encounter	Encounter.type
 :)
(:~
 : GET: nabu/encounters/subjects/{$sid}?start=1&length=10&status=...
 : List encounters for subject
 : 
 : @param   $start
 : @param   $length
 : @param   $status
 : 
 : @return  bundle <encounters/>
 : 
 : @since v0.6
 : @todo  implement temporal interval
 :)
declare
    %rest:GET
    %rest:path("nabu/encountersBySubject/{$sid}")
    %rest:query-param("realm",   "{$realm}")
    %rest:query-param("loguid",  "{$loguid}")
    %rest:query-param("lognam",  "{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")      
    %rest:query-param("timeMin", "{$timeMin}", "")    
    %rest:query-param("timeMax", "{$timeMax}", "")
    %rest:query-param("status",  "{$status}", "")
    %rest:produces("application/xml", "text/xml")
function r-encounter:encountersBySubject(
          $sid as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $start as xs:string*
        , $length as xs:string*
        , $timeMin as xs:string*
        , $timeMax as xs:string*
        , $status as xs:string*
        ) as item()
{
    let $tstart := util:system-time()
(:  
    let $tmin := if (string-length($timeMin)>0)
            then $timeMin
            else "1994-06-01T08:00:00"
    let $tmax := if (string-length($timeMax)>0)
            then $timeMax
            else "2021-04-01T20:00:00" 
:)
    let $sref := "nabu/patients/" || $sid
    let $colls := r-encounter:collections($status,$timeMin,$timeMax,$r-encounter:base)
    let $matched0 := collection($colls)/fhir:Encounter[fhir:subject[fhir:reference/@value=$sref]]
    let $matched := $matched0/../fhir:Encounter[fhir:status[@value=$status]]                                    
    (:
        $matched0[fhir:period[fhir:start[@value>$tmin]][fhir:end[@value<$tmax]]]
    :)

    let $sorted-hits := for $e in $matched
            order by $e/fhir:period/fhir:start/@value/string() descending collation "?lang=de-DE"
            return
                $e
    let $res := r-encounter:prepareResult($sorted-hits, $start, $length)
    let $tend := util:system-time()
    let $runtimems := (($tend - $tstart) div xs:dayTimeDuration('PT1S'))  * 1000
    let $lll := util:log-app('TRACE','apps.nabu',concat(count($sorted-hits),':',$runtimems))
    return
        $res
};

(:~
 : GET: nabu/encounters/participants/{$uid}?start=1&length=10&status=...
 : List encounters for participants and return them as XML.
 : 
 : @param   $start
 : @param   $length
 : @param   $timeMin
 : @param   $timeMax
 : @param   $status
 : @return  bundle <Encounter/>
 :)
declare
    %rest:GET
    %rest:path("nabu/encounters/participants/{$uid}")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam","{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}",    "*")
    %rest:query-param("timeMin", "{$timeMin}", "")    
    %rest:query-param("timeMax", "{$timeMax}", "")
    %rest:query-param("status",  "{$status}", "finished")
    %rest:produces("application/xml", "text/xml")
function r-encounter:encountersByParticipant($uid as xs:string*,
            $realm as xs:string*, $loguid as xs:string*, $lognam as xs:string*,
            $start as xs:string*, $length as xs:string*,
            $timeMin as xs:string*, $timeMax as xs:string*,
            $status as xs:string*) as item()
{
    try{
        let $colls := r-encounter:collections($status,$timeMin,$timeMax,$r-encounter:base)
        let $tmin := if ($timeMin)
            then xs:dateTime($timeMin)
            else current-dateTime()
        let $tmax := if ($timeMax)
            then xs:dateTime($timeMax)
            else current-dateTime() + xs:dayTimeDuration('P1D')
        let $aref := concat('metis/practitioners/',$uid)
        let $es := collection($colls)/fhir:Encounter[fhir:participant/fhir:individual[fhir:reference/@value=$aref]]
        let $matched := $es/../fhir:Encounter[fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]][fhir:status[@value=$status]]

        let $sorted-hits := for $e in $matched
                order by $e/period/start/@value/string() collation "?lang=de-DE"
                return
                    $e
        return
            r-encounter:prepareResult($sorted-hits, $start, $length)
    } catch * {
        r-encounter:rest-response(404, concat('Invalid time filter? : ', $timeMin, '-', $timeMax))
    }
};

(:~
 : Search parameters FHIR 0.8
 : individual	reference	Any one of the individuals participating in the Encounter	Encounter.participant.individual
 : date	date	Encounter date/time.	Encounter.start
 : partstatus	token	The Participation status of the subject, or other participant on the Encounter	Encounter.participant.status
 : patient	reference	One of the individuals of the Encounter is this patient	Encounter.subject
 : status	token	The overall status of the Encounter	Encounter.status
 :)
(:~
 : GET: nabu/encounters?start=1&length=10&status=...
 : List encounters for participant $uid and return them as XML.
 : 
 : @param   $uid     ids of participants
 : @param   $group   group
 : @param   $sched   schedule
 : @param   $timeMin start of period
 : @param   $timeMax end of period
 : @param   $start   start of sublist
 : @param   $length  len of sublist
 : @param   $status  FHIR status
 : @param   $sort   
 : @return  bundle <encounters/>
 :)
declare
    %rest:GET
    %rest:path("nabu/encounters")
    %rest:query-param("realm",    "{$realm}")
    %rest:query-param("loguid",   "{$loguid}")
    %rest:query-param("lognam",   "{$lognam}")
    %rest:query-param("start",    "{$start}",   "1")      
    %rest:query-param("length",   "{$length}")
    %rest:query-param("uid",      "{$uid}", "")
    %rest:query-param("group",    "{$group}", "")  
    %rest:query-param("sched",    "{$sched}",  "")
    %rest:query-param("patient",  "{$patient}", "")
    %rest:query-param("rangeStart", "{$rangeStart}", "1970-01-01T00:00:00")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "2025-04-01T23:59:59")
    %rest:query-param("status",   "{$status}",  "")
    %rest:query-param("_sort",   "{$sort}", "date:asc")
    %rest:consumes("application/xml", "text/xml")
    %rest:produces("application/xml", "text/xml")
function r-encounter:encountersXML(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    , $uid as xs:string*
    , $group as xs:string*
    , $sched as xs:string*
    , $patient as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    , $status as xs:string*
    , $sort as xs:string*
    ) as item()
{
    let $length := ($length,'*')[1] 
        let $colls := r-encounter:collections($status,$rangeStart,$rangeEnd,$r-encounter:base)
        let $tstart := util:system-time()
        let $coll := collection($colls)
        let $tmin := if (contains($rangeStart,'T'))
            then $rangeStart
            else concat($rangeStart, 'T00:00:00')
        let $tmax := if (contains($rangeEnd,'T'))
            then $rangeEnd
            else concat($rangeEnd, 'T23:59:59')
        let $uref := concat('metis/practitioners/', $uid)
        let $matched0 := if ($uid!='')
            then $coll/fhir:Encounter[fhir:participant/fhir:individual[fhir:reference/@value=$uref]][fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]]
            else if ($group!='')
                then $coll/fhir:Encounter[fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]][fhir:participant[fhir:type/fhir:coding[fhir:code/@value = $group]]]
                else $coll/fhir:Encounter[fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]]
        let $matched1 : = if ($status!='')
            then $matched0/../fhir:Encounter[fhir:status[@value=$status]]
            else $matched0
        let $matched := if ($sched!='')
            then $matched1/../fhir:Encounter[fhir:type/fhir:coding[fhir:code/@value=$sched]]
            else $matched1
        let $sorted-hits := switch($sort)
            case "patient:asc" return
                for $a in $matched
                order by $a/fhir:subject/display/@value/string() collation "?lang=de-DE"
                return
                    $a
            case "actor:asc" return
                for $a in $matched
                order by $a/fhir:participant/fhir:individual/fhir:display/@value/string() collation "?lang=de-DE"
                return
                    $a
            case "date:asc" return
                for $a in $matched
                order by $a/fhir:period/fhir:start/@value/string() ascending
                return
                    $a
            default return 
                for $a in $matched
                order by $a/fhir:period/fhir:start/@value/string() descending
                return
                    $a
        let $tend := util:system-time()
        let $runtimems := (($tend - $tstart) div xs:dayTimeDuration('PT1S'))  * 1000
        let $lll := util:log-app('TRACE','apps.nabu',string-join((count($sorted-hits),$start,$length,$runtimems),':'))
        return
            r-encounter:prepareResult($sorted-hits, $start, $length)
};

declare
    %rest:GET
    %rest:path("nabu/encounters")
    %rest:query-param("realm",    "{$realm}")
    %rest:query-param("loguid",   "{$loguid}")
    %rest:query-param("lognam",   "{$lognam}")
    %rest:query-param("actor",    "{$uid}", "")
    %rest:query-param("group",    "{$group}", "")  
    %rest:query-param("sched",    "{$sched}",  "")  
    %rest:query-param("rangeStart", "{$rangeStart}", "1970-01-01T00:00:00")      
    %rest:query-param("rangeEnd",   "{$rangeEnd}", "1970-01-01T23:59:59")
    %rest:query-param("start",    "{$start}",   "1")      
    %rest:query-param("length",   "{$length}",  "*")
    %rest:query-param("status",   "{$status}",  "planned")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-encounter:encountersJSON(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $uid as xs:string*
    , $group as xs:string*
    , $sched as xs:string*
    , $rangeStart as xs:string*
    , $rangeEnd as xs:string*
    , $start as xs:string*
    , $length as xs:string*
    , $status as xs:string*
    ) as item()
{
    (: let $roles := r-user:rolesByUID($uid) 
    let $lll := util:log-app('TRACE','apps.nabu',string-join(($uid, $group, $sched),'-'))
    return
    :)

    try {
        let $colls := r-encounter:collections($status,$rangeStart,$rangeEnd,$r-encounter:base)
        let $lll := util:log-app('TRACE','apps.nabu',string-join($colls,':'))
        let $tstart := util:system-time()
        let $coll := collection($colls)
        let $tmin := if (contains($rangeStart,'T'))
            then $rangeStart
            else concat($rangeStart, 'T00:00:00')
        let $tmax := if (contains($rangeEnd,'T'))
            then $rangeEnd
            else concat($rangeEnd, 'T23:59:59')
        let $uref := concat('metis/practitioners/', $uid)
        let $matched0 := if ($uid!='')
            then $coll/fhir:Encounter[fhir:participant/fhir:individual[fhir:reference/@value=$uref]][fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]]
            else if ($group!='')
                then $coll/fhir:Encounter[fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]][fhir:participant[fhir:type/fhir:coding[fhir:code/@value = $group]]]
                else $coll/fhir:Encounter[fhir:period/fhir:start[@value>$tmin]][fhir:period/fhir:end[@value<$tmax]]
        let $matched1 := if ($sched!='')
            then $matched0/../fhir:Encounter[fhir:type/fhir:coding[fhir:code/@value=$sched]]
            else $matched0
        let $matched : = if ($status!='')
            then $matched1/../fhir:Encounter[fhir:status[@value=$status]]
            else $matched1
            
        let $events := for $e in $matched
                let $title := $e/fhir:subject/fhir:display/@value/string()
                let $id    := $e/fhir:id/@value/string()
                let $desc  := $e/fhir:reasonCode/fhir:text/@value/string()
                let $shist := string-join($e/fhir:statusHistory//fhir:text/@value,'-')
                let $start := $e/fhir:period/fhir:start/@value/string()
                let $end   := $e/fhir:period/fhir:end/@value/string()
                let $bkcolor:= switch($e/fhir:status/@value/string())
                            case 'planned' return 'blue'
                            case 'tentative' return 'red'
                            case 'finished' return 'green'
                            case 'arrived' return 'lime'
                            case 'triaged' return 'fuchsia'
                            default return 'grey'
                let $json :=
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                        <id>{$id}</id>
                        <title>{$title}</title>
                        <description>{$desc}</description>
                        <history>{$shist}</history>
                        <pid>{substring-after($e/fhir:subject/fhir:reference/@value,'nabu/patients/')}</pid>
                        <partof>{$e/fhir:partOf/fhir:display/@value/string()}</partof>
                        <app>{$e/fhir:type/fhir:coding[fhir:system[@value='http://hl7.org/fhir/v2/0276']]/fhir:code/@value/string()}</app>
                        <start>{$start}</start>
                        <end>{$end}</end>
                        <allDay json:literal='true'>false</allDay>
                        <editable json:literal='true'>false</editable>
                        <backgroundColor>{$bkcolor}</backgroundColor> 
                    </json:value>
(: 
let $lll := util:log-app('TRACE','apps.nabu',$json)
:)
                order by $e/fhir:period/fhir:start/@value/string() collation "?lang=de-DE"
                return
                    $json
    let $tend := util:system-time()
    let $runtimems := (($tend - $tstart) div xs:dayTimeDuration('PT1S'))  * 1000
    let $lll := util:log-app('TRACE','apps.nabu',string-join(('json:',$colls,count($matched),$runtimems),':'))
    return
            <json:value xmlns:json="http://www.json.org">
            {
                $events
            }
            </json:value>
    } catch * {
        r-encounter:rest-response(404, concat('Invalid time filter? : ', $rangeStart, ' -- ', $rangeEnd))
    }
};


(:~
 : PUT: nabu/encounters/{$cid}/status/{$status}
 : Update an existing encounter.
 :
 : 
 : @return <response>
 :)
declare
    %rest:POST
    %rest:path("nabu/encounters/{$eid}/status/{$new-status}")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-encounter:updateStatus(
      $eid as xs:string*
    , $new-status as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{

    let $enc  := 
        let $enc0 := collection(concat($r-encounter:base,'/planned'))/fhir:Encounter[fhir:id[@value = $eid]]
        let $enc1  := if(count($enc0)=0)
            then collection($r-encounter:base)/fhir:Encounter[fhir:id[@value = $eid]]
            else $enc0
        return $enc1
    let $lll  := util:log-app('TRACE','apps.nabu',$new-status)
    return
        if (count($enc) = 1 and r-encounter:isValid($new-status))
        then   
            let $upd := r-encounter:doUpdateMove($enc, $new-status)
            return
                r-encounter:rest-response(200, 'encounter status updated.')
        else
            r-encounter:rest-response(404, 'encounter status not updated.') 
};

declare %private function r-encounter:doUpdateMove(
      $doc
    , $new-status as xs:string
    ) as xs:boolean
{
    let $old-status := $doc/fhir:status/@value/string()
    let $oldpath    := util:collection-name($doc)
    let $oldname    := util:document-name($doc)
    return
        if ($old-status=$new-status)
        then false()
        else if ($new-status =('planned','tentative'))
        then
            let $up := system:as-user('vdba', 'kikl823!',
                (
                  update value $doc/fhir:status/@value with $new-status
                , if ($old-status =('planned','tentative'))
                    then ()
                    else xmldb:move($oldpath, $r-encounter:planned, $oldname)
                ))
            return true()
        else if ($old-status=('planned','tentative'))
        then       
            let $up := system:as-user('vdba', 'kikl823!',
                (
                  update value $doc/fhir:status/@value with $new-status
                , xmldb:move($oldpath, concat($r-encounter:base,'/',substring($doc/fhir:period/fhir:start/@value,1,4)), $oldname)
                ))
            return true()
        else           
            let $up := system:as-user('vdba', 'kikl823!',
                (
                  update value $doc/fhir:status/@value with $new-status
                ))
            return true()
};

declare %private function r-encounter:isValid($status as xs:string) as xs:boolean
{
    $status = $r-encounter:valid-status
(: 
    $status = ('tentative','planned','arrived','triaged','in-progress','onleave','cancelled','entered-in-error','unknown')
:)
};

(:~
 : PUT: nabu/encounters
 : Update an existing encounter or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/encounters")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-encounter:putEncounterXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    let $isNew := not($content/fhir:Encounter/@xml:id)
    let $eid   := if ($isNew)
        then concat("e-", util:uuid())
        else
            let $id := $content/fhir:Encounter/fhir:id/@value/string()
            let $coll := collection(concat($r-encounter:base,'/planned'))
            let $es0  := $coll/fhir:Encounter[fhir:id[@value = $id]]
            let $es1  := if(count($es0)=0)
                then collection($r-encounter:base)/fhir:Encounter[fhir:id[@value = $id]]
                else $es0
            let $move := r-encounter:moveToHistory($es1)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/fhir:Encounter/fhir:meta/fhir:versionId/@value/string()) + 1
    let $base := $content/Encounter/fhir:*[not(
                                               self::id
                                            or self::meta
                                            )]
    let $meta := $content//meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $uuid := if ($isNew) 
        then $eid
        else concat("e-", util:uuid())
    let $data := 
        <Encounter xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
            <id value="{$eid}"/>
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
            {$base}
        </Encounter>
(: 
    let $lll := util:log-app('TRACE','apps.nabu',$data)
:)
    let $file := $uuid || ".xml"
    let $target := r-encounter:targetColl($data/fhir:status/@value/string(),$data/fhir:period/fhir:start/@value/string(),$r-encounter:base)
    let $lll := util:log-app('TRACE','apps.nabu',$target)
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($target, $file, $data)
            , sm:chmod(xs:anyURI($target || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($target || '/' || $file), $config:data-group)))
        return
            (
                r-encounter:rest-response(200, 'encounter sucessfully stored.')
            , $data
            )
    } catch * {
        let $lll := util:log-app('ERROR','apps.nabu',$target)
        return
            r-encounter:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare function r-encounter:targetColl(
      $status as xs:string
    , $start as xs:string
    , $base as xs:string
    ) as xs:string
{
    let $year   := substring($start,1,4)
    return
        if (xs:integer($year)>2003 and xs:integer($year)<2026)
        then
            if ($status=('planned','tentative'))
            then
                concat($base,'/planned')
            else
                concat($base,'/',$year)
        else '/db/apps/nabuEncounter/data/invalid'
};
