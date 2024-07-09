xquery version "3.0";

(:~
: Defines all the RestXQ endpoints for queries
: @author Peter Herkenrath
: @version 1.0
: @see http://enahar.org
:
:)
module namespace r-api = "http://enahar.org/exist/restxq/nabu/api";

import module namespace patutils = "http://enahar.org/exist/apps/nabu/patutils" at "/db/apps/nabu/FHIR/Patient/patutils.xqm";
import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";
import module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize" at "../../FHIR/meta/serialize-fhir-resources.xqm";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-api:baseComposition  := '/db/apps/nabuComposition/data';
declare variable $r-api:basePatient      := '/db/apps/nabuData/data/FHIR/Patients';
declare variable $r-api:historyPatient   := concat($config:history-data,'/Patients');

declare %private function r-api:rangedCollections(
      $base as xs:string
    , $status as xs:string*
    , $tmin as xs:string
    , $tmax as xs:string
    ) as xs:string*
{
    if ($status="preliminary")
    then
        ("preliminary")
    else
        let $openrange := $tmin='' and $tmax=''
        let $years := 
            if ($openrange)
            then $base
            else
                let $ymin := if ($tmin!='')
                    then let $y := xs:integer(substring($tmin,1,4))
                        return max(($y,1994))
                    else 2004
                let $ymax := if ($tmax!='')
                    then let $y := xs:integer(substring($tmax,1,4))
                        return min(($y,2026))
                    else 2026
                let $inc := 0
                for $y in ($ymin to ($ymax+$inc))
                return
                    concat($base,'/',$y)
        let $lll := util:log-app('TRACE','apps.nabu',string-join(($status,$tmin,$tmax,$openrange,$years),':'))
        return
            ($years,'invaliddate','nodate','preliminary')
};

declare %private function r-api:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare %private function r-api:resources2Bundle(
      $resources as item()*
    )
{
    let $uuid := concat('b-',util:uuid())
    let $total := count($resources)
    return
    <Bundle xmlns="http://hl7.org/fhir" xml:id="{$uuid}">
        <id value="{$uuid}"/>
        <meta>
            <versionId value="0"/>
        </meta>
        <type value="searchset"/>
        <total value="{$total}"/>
    {
        for $r in $resources
        let $url := r-api:fullUrl($r)
        return
            <entry xmlns="http://hl7.org/fhir">
                <fullUrl value="{$url}"/>
                <resource>{ $r }</resource>
            </entry>
    }
    </Bundle>
};

declare %private function r-api:fullUrl($resource as item()) as xs:string
{
    string-join(('http://spz.uk-koeln.de','exist/restxq','nabu',concat(lower-case(local-name($resource)),'s'),$resource/fhir:id/@value),'/')    
};

(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare function r-api:moveToHistory(
      $objects as element()*
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = concat($r-api:historyPatient))
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
               system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, concat($r-api:historyPatient), $nameHistory)
                    )
        )
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
    %rest:path("nabu/Patient/{$pid}")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:produces("application/xml")
function r-api:typePatientXML(
      $pid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $coll := collection($r-api:basePatient)
    let $p := $coll/fhir:Patient[fhir:id[@value = $pid]]
    return
        if (count($p)=1)
        then $p
        else if (count($p)=0)
        then r-api:rest-response(407, 'Patient demographic not found.')
        else r-api:rest-response(407, 'Patient demographic, version error.')
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
    %rest:path("/nabu/Patient/{$pid}")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:produces("application/json")
function r-api:typePatientJSON(
      $pid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()
{
    let $coll := collection($r-api:basePatient)
    let $p := $coll/fhir:Patient[fhir:id[@value = $pid]]
    return
        if (count($p)=1)
        then serialize:resource2json($p, false(),"4.3")
        else if (count($p)=0)
        then r-api:rest-response(407, 'Patient demographic not found.')
        else r-api:rest-response(407, 'Patient demographic, version error.')
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
    %rest:path("/nabu/Patient")
    %rest:query-param("realm", "{$realm}", "")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:query-param("lognam", "{$lognam}", "")
    %rest:query-param("family",   "{$name}",   "")
    %rest:query-param("given",  "{$given}",  "")
    %rest:query-param("birthdate", "{$birthDate}", "")
    %rest:query-param("name-use",    "{$use}", "official")
    %rest:query-param("active", "{$active}", "true")
    %rest:produces("application/json")
function r-api:patientJSON(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $name as xs:string*
    , $given as xs:string*
    , $birthDate as xs:string*
    , $use as xs:string*
    , $active as xs:string*
    )
{
    let $lll := util:log-app('TRACE','apps.nabu',$name)
    let $lll := util:log-app('TRACE','apps.nabu',$given)
    let $lll := util:log-app('TRACE','apps.nabu',$birthDate)
    let $lll := util:log-app('TRACE','apps.nabu',$use)
    let $tstart := util:system-time()
    let $coll := collection($r-api:basePatient)
    let $hits2 := if ($name="" and $given="" and $birthDate="")
        then () (: should give sensible HTTP error $coll/fhir:Patient[fhir:active[@value=$active]] :)
        else if ($given="" and $birthDate="")
        then let $p0 := $coll/fhir:Patient[fhir:name[fhir:use[@value=$use]]/fhir:family[starts-with(@value,$name)]][fhir:active[@value=$active]]
             return $p0
        else if ($name="" and $given="" and string-length($birthDate)>6)
        then
            let $ps := $coll/fhir:Patient[fhir:birthDate[starts-with(@value,$birthDate)]][fhir:active[@value=$active]]
            return
                $ps
        else
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
    return
        serialize:resource2json(r-api:resources2Bundle($hits2),false(),"4.3")
};


declare function r-api:formatFHIRName($pat as element(fhir:Patient)) as xs:string
{
    let $name := $pat/fhir:name[fhir:use[@value='official']]
    return
        concat($name/fhir:family/@value, ', ', $name/fhir:given/@value, ', *', tokenize($pat/fhir:birthDate/@value,'T')[1])
};

(:~
 : GET: /nabu/Patient
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
    %rest:path("/nabu/Patient")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("family",      "{$name}",      "")
    %rest:query-param("given",     "{$given}",     "")
    %rest:query-param("birthdate", "{$birthDate}", "")
    %rest:query-param("name-use",       "{$use}", "official")
    %rest:query-param("pid",       "{$pid}",       "")
    %rest:query-param("active", "{$active}", "true")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-api:patientXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $name as xs:string*
        , $given as xs:string*
        , $birthDate as xs:string*
        , $use as xs:string*
        , $pid as xs:string*
        , $active as xs:string*
        )
{
    let $coll := collection($r-api:basePatient)
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
        r-api:resources2Bundle($sorted-hits)
};


(:~
 : PUT: /nabu/patients
 : Update an existing patient or store a new one.
 : 
 : @param $content request body (xml)
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/nabu/Patient")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-api:putTypePatientXML(
          $content as node()*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        )
{
    let $coll := collection($r-api:base)
    let $isNew   := not($content//Patient/@xml:id)
    let $pid   := if ($isNew)
        then  concat("p-", util:uuid())
        else              
            let $id := $content//Patient/id/@value/string()
            let $pats := $coll/fhir:Patient[fhir:id[@value = $id]]
            let $move := r-api:moveToHistory($pats)
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
                r-api:rest-response(200, 'patient sucessfully stored.')
            ,   $data
            )
    } catch * {
        r-api:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare
    %rest:GET
    %rest:path("nabu/Composition")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("loguid","{$lognam}")
    %rest:query-param("start",   "{$start}",  "1")      
    %rest:query-param("length",  "{$length}", "*")
    %rest:query-param("author",  "{$author}", "")
    %rest:query-param("dateStart", "{$dateStart}")    
    %rest:query-param("dateEnd",  "{$dateEnd}",   "")
    %rest:query-param("subject", "{$subject}", "")
    %rest:query-param("status",  "{$status}", "in-progress")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/json")
function r-api:compositionJSON(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $start as xs:string*
        ,   $length as xs:string*
        ,   $author as xs:string*
        ,   $dateStart as xs:string*
        ,   $dateEnd as xs:string*
        ,   $subject as xs:string*
        ,   $status as xs:string*
        ,   $format as xs:string*
        ) as item()
{
    try{
    let $aref := "metis/practitioners/" || $author
    let $sref := "nabu/patients/" || $subject
    let $colls := r-api:rangedCollections($r-api:baseComposition, $status,"","")
    let $coll := collection($colls)
    let $matched := 
        if ($author="" and $subject="")
        then $coll/fhir:Composition[fhir:status[@value=$status]]
        else if ($subject="")
        then let $c0 := $coll/fhir:Composition[fhir:author[fhir:reference/@value=$aref]]
            return
                $c0/../fhir:Composition[fhir:status[@value=$status]]
        else if ($author="")
        then let $c0 := $coll/fhir:Composition[fhir:subject[fhir:reference/@value=$sref]]
            return $c0/../fhir:Composition[fhir:status[@value=$status]]
        else $coll/fhir:Composition[fhir:subject[fhir:reference/@value=$sref]][fhir:author[fhir:reference/@value=$aref]][fhir:status[@value=$status]]

    return
        switch ($format)
        case 'count' return <compositions><count>{count($matched)}</count></compositions>
    (:
        case 'pdf' return r-composition:compos2PDF($matched)
    :)
        default return 
        serialize:resource2json(r-api:resources2Bundle($matched),false(),"4.3")
    } catch * {
        r-api:rest-response(404, concat('Invalid filter? : ', $dateStart, '-', $dateEnd))
    }
};
