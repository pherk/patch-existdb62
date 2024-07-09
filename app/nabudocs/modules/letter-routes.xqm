xquery version "3.0";

module namespace r-letter="http://enahar.org/exist/rextxq/letter";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace helper         = "http://enahar.org/exist/apps/nabudocs/helper"  at "../modules/helper.xqm";
import module namespace dl2tei         = "http://enahar.org/exist/apps/nabudocs/dl2tei"  at "../modules/dl2tei.xqm";


declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare variable $r-letter:compositions := collection('/db/apps/nabuComposition/data');

declare %private function r-letter:prepareResult($hits, $start, $length)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    return
        <communications xmlns="">
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            { subsequence($hits, $start, $len1) }
        </communications>
};


declare %private function r-letter:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : GET: nabudocs/erros
 : List errors from letter import
 : 
 : @param   $base  base uri
 : @param   $path  relative path
 : 
 : @return  bundle <errors/>
 : 
 : @since v0.7
 :)
declare
    %rest:GET
    %rest:path("nabudocs/errors")
    %rest:query-param("realm", "{$realm}")   
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("base", "{$base}", "/db/apps/nabuCom/errors")   
    %rest:query-param("path", "{$path}", "")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
function r-letter:getErrorsXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $base as xs:string*
        , $path as xs:string*
        )
{
    r-letter:errors($base,$path)
};

(:~
 : GET: nabudocs/reimport-errors
 : reimport letters from error list
 : 
 : @param   $base  base uri
 : @param   $path  relative path
 : 
 : @return  bundle <errors/>
 : 
 : @since v0.7
 :)
declare
    %rest:GET
    %rest:path("nabudocs/reimport-errors")
    %rest:query-param("realm", "{$realm}")   
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("base", "{$base}", "/db/apps/nabuCom/errors")  
    %rest:query-param("path", "{$path}", "")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
function r-letter:reimportErrorsXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $base as xs:string*
        , $path as xs:string*
        )
{
    let $import := "/db/apps/nabuCom/import"
    let $oes := r-letter:errors($base,$path)
    let $group := r-letter:getGroup($path)
    let $imp := for $e in $oes/*:error
        let $resource := concat($e/@id,'.xml')
        let $rm := system:as-user('vdba', 'kikl823!', 
            try { 
                xmldb:remove($base, $resource)
            } catch * {
                xmldb:remove($base, $e/@id)
            })
        return
            r-letter:importLetter(
                  $loguid, $lognam
                , $import,$e/*:collection,$e/*:file
                , '', ''
                , '', ''
                , '', ''
                , ''
                , $group)

    let $nes := r-letter:errors($base,$path)
    let $lll := util:log-system-out(concat(count($nes/*:error),'/',count($oes/*:error)))
    return
        $nes
};

declare function r-letter:errors($base, $path)
{
    let $errors := collection($base)/*:error[starts-with(*:collection,$path)]
    let $coll := 
            for $e in $errors
            order by $e/*:file
            return
                if ($e/@id)
                then $e
                else
                    <error xmlns="" id="{util:document-name($e)}">
                    {
                        $e/*
                    }
                    </error>
    return
        <errors xmlns="">{$coll}</errors>
};

declare function r-letter:importLetter(
          $loguid as xs:string*
        , $lognam as xs:string*
        , $base as xs:string*
        , $path as xs:string*
        , $file as xs:string*
        , $subject-uid as xs:string*
        , $subject-display as xs:string*
        , $recipient-uid as xs:string*
        , $recipient-display as xs:string*
        , $author-uid as xs:string*
        , $author-display as xs:string*
        , $newdate as xs:string*
        , $group as xs:string*
    ) as xs:boolean
{
    let $fullpath := concat($base,'/',$path,'/',$file)
    let $ass := 
        <asserter xmlns="http://hl7.org/fhir">
            <reference value="{concat('metis/practitioners/',$loguid)}"/>
            <display value="{$lognam}"/>
        </asserter>
(: 
    let $lll := util:log-app('TRACE','apps.nabu',$subject-uid)
    let $lll := util:log-app('TRACE','apps.nabu',$group)
    let $lll := util:log-app('TRACE','apps.nabu',$fullpath)
:)
    return
        try {

            let $l := doc($fullpath)
            let $coll := substring-after(util:collection-name($l), concat($base,'/'))
            let $lll := util:log-app('TRACE','apps.nabu',$coll)
            let $lt   := dl2tei:ltrans($l,$file)
            let $teisubject := $lt//tei:opener/tei:subject
            let $lll := util:log-app('TRACE','apps.nabu',$teisubject)
            let $ss   := helper:subject2patient($teisubject)
            let $as   := helper:signees($lt//tei:signed, $coll)
            let $rec  := helper:physician($lt//tei:opener/tei:address)
            let $vdate := helper:validdate($lt//tei:opener//tei:dateline)
            let $lll := util:log-app('TRACE','apps.nabu',$ss)
            let $subject  := if ($ss/*:error and $subject-uid!='') 
                then
                    <subject xmlns="http://hl7.org/fhir">
                        <reference value="{concat('nabu/patients/',$subject-uid)}"/>
                        <display value="{$subject-display}"/>
                    </subject>
                else if ($ss/*:error)
                then ()
                else $ss/fhir:subject
            let $author := if ($as/*:error)
                then
                    <author xmlns="http://hl7.org/fhir">
                        <reference value="{if ($author-uid!='') then concat('metis/practitioners/',$author-uid) else ''}"/>
                        <display value="{$author-display}"/>                    
                    </author>
                else $as/fhir:author
            let $recipient := if ($rec/*:error)
                then
                    <recipient xmlns="http://hl7.org/fhir">
                        <reference value="{if ($recipient-uid!='') then concat('metis/practitioners/',$recipient-uid) else ''}"/>
                        <display value="{$recipient-display}"/>                         
                    </recipient>
                else $rec/fhir:recipient
            let $validDateline := if ($vdate/*:error)
                then if (r-letter:isProbablyValid($newdate))
                    then <dateline xmlns="http://www.tei-c.org/ns/1.0">Köln, den <date when="{$newdate}">{$newdate}</date></dateline>
                    else () 
                else $vdate/*:dateline
            let $help :=
                if ($subject and $validDateline)
                then
                    for $sub in $subject
                    let $com := helper:compositionWithDateline($lt, $coll, $file,  $sub, $group, $author, $recipient, $validDateline)
                    let $cds := helper:conditions($lt,$coll,$file,$sub,$ass)
                    return
                        ()
                else r-letter:storeError($coll,$file,$ss,$as,$rec,$vdate)
            return
                true()
        } catch * {
            let $lll := util:log-app('DEBUG','apps.nabu',string-join(($err:code , $err:description, $err:value),'_'))
            return
                false()
        }
};

declare function r-letter:storeError($coll,$fn,$ss,$as,$rec,$date)
{
    let $data-perms    := "rwxrw-r--"
    let $data-group    := "spz"
    let $error-base  := "/db/apps/nabuCom/errors"
    let $uid := concat('e-',util:uuid())
    let $data :=
            <error id="{$uid}" xmlns="">
                <file>{$fn}</file>
                <collection>{$coll}</collection>
                { if ($ss/*:error) then $ss else () }
                { if ($as/*:error) then $as else () }
                { if ($rec/*:error) then $rec else () }
                { if ($date/*:error) then $date else () }
            </error>
    let $file := concat($uid, '.xml')
    let $store := system:as-user('vdba', 'kikl823!', (
                              xmldb:store($error-base, $file, $data)
                            , sm:chmod(xs:anyURI($error-base || '/' || $file), $data-perms)
                            , sm:chgrp(xs:anyURI($error-base || '/' || $file), $data-group)))
    return
        ()
};

(:~
 : GET: nabudocs/delete-error/{$uid}
 : delete error
 : 
 : @param   $id  
 : 
 : @return  ()
 : 
 : @since v0.7
 :)
declare
    %rest:GET
    %rest:path("nabudocs/delete-error/{$uid}")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
function r-letter:deleteErrorXML(
          $uid as xs:string
        )
{
    try {
        let $path := '/db/apps/nabuCom/errors'
        let $resource := concat($uid,'.xml')
        let $rm := system:as-user('vdba', 'kikl823!', xmldb:remove($path, $resource))
        return
            r-letter:rest-response(200, 'error deleted')
    } catch * {
            r-letter:rest-response(401, concat('Invalid resource? : ', $uid))
    }
};

(:~
 : GET: nabudocs/letters
 : show letter to be imported
 : 
 : @param   $base  base uri
 : @param   $path  relative path
 : @param   $file
 : 
 : @return  bundle <letter/>
 : 
 : @since v0.7
 :)
declare
    %rest:GET
    %rest:path("nabudocs/letters")
    %rest:query-param("realm", "{$realm}")   
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("base", "{$base}", "/db/apps/nabuCom/import")   
    %rest:query-param("path", "{$path}", "")
    %rest:query-param("file", "{$file}")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
function r-letter:getLetterXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $base as xs:string*
        , $path as xs:string*
        , $file as xs:string*
        )
{
    let $fullpath := concat($base,'/',$path,'/',$file)
    return
        try {
            let $doc := doc($fullpath)/*:body
            return
                <letter>
                {
                    tail(tail($doc/*))
                }</letter>
        } catch * {
            r-letter:rest-response(404, concat('Invalid path? : ', $fullpath))
        }
};

(:~
 : GET: nabudocs/{$id}/raw
 : raw letter 
 : 
 : @return  ()
 : 
 : @since v1.0
 :)
declare
    %rest:GET
    %rest:path("nabu/compositions/{$id}/raw")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
function r-letter:rawLetterXML(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
    )
{
    let $comp := $r-letter:compositions/fhir:Composition[fhir:id[@value = $id]]
    return
        if (count($comp)=1)
        then 
            let $base := "/db/apps/nabuCom/import"
            let $source := tokenize($comp/fhir:section/fhir:code/fhir:coding[fhir:system/@value="#nabu-report-source"]/fhir:code/@value,'/')
            let $path := 
                let $path0 := string-join(subsequence($source,1,count($source)-1),'/')
                return
                    if (starts-with($path0,'Bef')) (: BefundeXX coll :)
                    then $path0
                    else if (starts-with($path0,'Bay') and count($source)=1) (: only file name -> Bayley3 root coll :)
                    then $path0
                    else concat('Befunde17/',$path0)
            let $file := $source[last()]
            let $subject := $comp/fhir:subject

(: 
            let $lll := util:log-app('TRACE','apps.nabu',$comp)
:)
            let $group := r-letter:getGroup($path)
            let $fullpath := concat($base,'/',$path,'/',$file)
            let $lll := util:log-app('TRACE','apps.nabu',concat($fullpath,' - ', $group))
            let $doc := doc($fullpath)/*:body
            return
                <letter>
                {
                    tail(tail($doc/*))
                }</letter>
        else if (count($comp)>1)
        then r-letter:rest-response(404, concat('Composition with ID: ',$id, ' too many. Ask the Admin.'))
        else r-letter:rest-response(404, concat('Composition with ID: ',$id, ' not found. Ask the Admin.'))
};

(:~
 : GET: nabudocs/letters
 : import letter 
 : ignores multiple subjects if used from proof.html
 : 
 : @param   $base  base uri
 : @param   $path  relative path
 : @param   $file
 : 
 : @return  bundle <letter/>
 : 
 : @since v0.7
 :)
declare
    %rest:GET
    %rest:path("nabudocs/import")
    %rest:query-param("realm", "{$realm}")   
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("base", "{$base}", "/db/apps/nabuCom/import")   
    %rest:query-param("path", "{$path}")
    %rest:query-param("file", "{$file}")
    %rest:query-param("subject-uid",       "{$subject-uid}")
    %rest:query-param("subject-display",   "{$subject-display}")
    %rest:query-param("recipient-uid",     "{$recipient-uid}")
    %rest:query-param("recipient-display", "{$recipient-display}")
    %rest:query-param("author-uid",        "{$author-uid}")
    %rest:query-param("author-display",    "{$author-display}")
    %rest:query-param("date",    "{$newdate}")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
function r-letter:importLetterXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $base as xs:string*
        , $path as xs:string*
        , $file as xs:string*
        , $subject-uid as xs:string*
        , $subject-display as xs:string*
        , $recipient-uid as xs:string*
        , $recipient-display as xs:string*
        , $author-uid as xs:string*
        , $author-display as xs:string*
        , $newdate as xs:string*
        , $group as xs:string*
        )
{
    let $group := r-letter:getGroup($path)
    return
    if (r-letter:importLetter(
                  $loguid, $lognam
                , $base,$path,$file
                , $subject-uid,$subject-display
                , $recipient-uid,$recipient-display
                , $author-uid,$author-display
                , $newdate
                , $group))
    then
        r-letter:rest-response(200, concat('file : ', $file))
    else
        r-letter:rest-response(404, concat('Invalid path? : ', string-join(($base,$path,$file),'/')))
};

(:~
 : GET: nabudocs/{$id}/reimport
 : reimport letter 
 : 
 : @return  ()
 : 
 : @since v0.8
 :)
declare
    %rest:GET
    %rest:path("nabu/compositions/{$id}/reimport")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
function r-letter:reimportLetterXML(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
    )
{
    let $comp := $r-letter:compositions/fhir:Composition[fhir:id[@value = $id]]
    return
        if (count($comp)=1)
        then 
            let $base := "/db/apps/nabuCom/import"
            let $source := tokenize($comp/fhir:section/fhir:code/fhir:coding[fhir:system/@value="#nabu-report-source"]/fhir:code/@value,'/')
            let $path := 
                let $path0 := string-join(subsequence($source,1,count($source)-1),'/')
                return
                    if (starts-with($path0,'Bef')) (: BefundeXX coll :)
                    then $path0
                    else if (starts-with($path0,'Bay') and count($source)=1) (: only file name -> Bayley3 root coll :)
                    then $path0
                    else concat('Befunde17/',$path0)
            let $file := $source[last()]
            let $subject := $comp/fhir:subject

(: 
            let $lll := util:log-app('TRACE','apps.nabu',$comp)
:)
            let $group := r-letter:getGroup($path)
            let $fullpath := concat($base,'/',$path,'/',$file)
            let $lll := util:log-app('TRACE','apps.nabu',concat($fullpath,' - ', $group))
            let $l := doc($fullpath)
            let $coll := substring-after(util:collection-name($l), concat($base,'/'))
            let $lt0 := dl2tei:ltrans($l,$file)
            let $lt  := helper:canonizeTEISubject($lt0, $subject)
            let $lll := util:log-app('TRACE','apps.nabu',$lt)
            let $vdate := helper:validdate($lt//tei:opener//tei:dateline)
            let $upd := system:as-user('vdba','kikl823!',
                    (
                      update replace $comp/fhir:section/fhir:text/tei:div with $lt/tei:div
                    , if ($vdate/ok)
                        then update replace $comp/fhir:date/@value with $lt/tei:div//tei:opener/tei:dateline/tei:date/@when/string()
                        else ()
                    , update value $comp/fhir:section/fhir:code/fhir:coding[fhir:system/@value="#nabu-report-source"]/fhir:code/@value with concat($path,'/',$file)
                    , update value $comp/fhir:section/fhir:code/fhir:coding[fhir:system/@value="#nabu-report-source"]/fhir:display/@value with concat($path,'/',$file)
                    , update value $comp/fhir:section/fhir:code/fhir:text/@value with concat($group,':',$path,'/',$file)
                    )
                )
            return
                r-letter:rest-response(200, concat('Composition with ID: ',$id, 'successfully reimported.'))
        else if (count($comp)>1)
        then r-letter:rest-response(404, concat('Composition with ID: ',$id, ' too many. Ask the Admin.'))
        else r-letter:rest-response(404, concat('Composition with ID: ',$id, ' not found. Ask the Admin.'))
};

declare function r-letter:getGroup($path)
{
    let $ptoks := tokenize($path,'/')
    let $group := switch($ptoks[2])
        case 'Arzt' return 'Arzt'
        case 'Bayley3' return 'Bayley3'
        case 'Psychologie' return 'Psychologie'
        case 'Logopaedie' return 'Logopädie'
        case 'Logo' return 'Logopädie'
        case 'Ergotherapie' return 'Ergotherapie'
        case 'Ergo' return 'Ergotherapie'
        case 'Physiotherapie' return 'Physiotherapie'
        case 'Physio' return 'Physiotherapie'
        case 'Orthoptik' return 'Orthoptik'
        default return if ($ptoks[1]='Bayley3')
            then 'Bayley3'
            else 'Arzt'
    return
        $group
};

(: ~
 : GET: nabu/compositions/{$id}/new-date?date=
 : 
 : @return  ()
 :)
declare
    %rest:GET
    %rest:path("nabu/compositions/{$id}/new-date")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("date", "{$newdate}")
    %rest:produces("application/xml", "text/xml")
function r-letter:compositionNewDateByID(
          $id as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $newdate as xs:string*
        ) as item()
{
    let $lll := util:log-app("TRACE", "apps.nabu", $id)
    let $lll := util:log-app("TRACE", "apps.nabu", $newdate)
    let $coms := $r-letter:compositions/fhir:Composition[fhir:id[@value = $id]]
    return
        if (count($coms)=1 and r-letter:isProbablyValid($newdate))
        then
            let $lll := util:log-app("TRACE", "apps.nabu", "setting date of composition")
            let $ndt := concat($newdate,"T08:00:00")
            let $ntitle := concat($coms/fhir:title/@value, $newdate)
            let $upd := system:as-user('vdba','kikl823!',
                    (
                      update value $coms/fhir:date/@value with $ndt
                    , update value $coms/fhir:title/@value with $ntitle
                    , update replace $coms/fhir:section/fhir:text/tei:div//tei:opener/tei:dateline
                        with <dateline xmlns="http://www.tei-c.org/ns/1.0">Köln, den <date when="{$newdate}">{$newdate}</date></dateline>
                    ))
            return
                r-letter:rest-response(200, concat('Composition with ID: ',$id, 'new-date set.'))
        else if (count($coms)>1)
        then r-letter:rest-response(404, concat('Composition with ID: ',$id, ' too many. Ask the Admin.'))
        else r-letter:rest-response(404, concat('Composition with ID: ',$id, ' not found. Ask the Admin.'))
};

declare function r-letter:isProbablyValid($d as xs:string) as xs:boolean
{
    try { let $nd := xs:date($d)
          return $d > "1994-01-01" and $d < xs:string(current-date())
        }
    catch * { false() }
};

(:~
 : GET: nabu/collections
 : List collections
 : 
 : @param   $base  base uri
 : @param   $path  relative path
 : 
 : @return  bundle <collections/>
 : 
 : @since v0.7
 :)
declare
    %rest:GET
    %rest:path("nabu/collections")
    %rest:query-param("base", "{$base}", "/db/apps/nabuData/data/FHIR")   
    %rest:query-param("path", "{$path}", "")
    %rest:produces("application/xml")
    %output:media-type("application/xml")
function r-letter:collectionsXML(
          $base as xs:string*
        , $path as xs:string*
        )
{
        let $path := r-letter:stripPath($path)
        let $full := string-join(($base,$path),'/')
let $lll := util:log-system-out($path)
        let $coll := 
                (
                  if ($path="") 
                    then () 
                    else 
                        <path>{string-join(($path,'..'),'/')}</path>
                , <path>{string-join(($path,'.'),'/')}</path>
                , for $c in xmldb:get-child-collections($full)
                  order by $c
                  return
                    <path>{string-join(($path,$c),'/')}</path>
                )
        return
            <collections>{$coll}</collections>
};

(:~
 : GET: nabu/collections
 : List collections
 : 
 : @param   $base  base uri
 : @param   $path  relative path
 : 
 : @return  bundle <collections/>
 : 
 : @since v0.7
 :)
declare
    %rest:GET
    %rest:path("nabu/collections")
    %rest:query-param("base", "{$base}", "/db/apps/nabuData/data/FHIR")   
    %rest:query-param("path", "{$path}", "")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-letter:collectionsJSON(
          $base as xs:string*
        , $path as xs:string*
        )
{
        let $path := r-letter:stripPath($path)
        let $full := string-join(($base,$path),'/')
let $lll := util:log-system-out($path)
        let $coll := 
                (
                  if ($path="") 
                    then () 
                    else 
                        <path>{string-join(($path,'..'),'/')}</path>
                , <path>{string-join(($path,'.'),'/')}</path>
                , for $c in xmldb:get-child-collections($full)
                  order by $c
                  return
                    <path>{string-join(($path,$c),'/')}</path>
                )
        return
            <json:array xmlns:json="http://www.json.org">
            {   
                for $c in subsequence($coll, 1, 30)
                return
                    <json:value xmlns:json="http://www.json.org" json:array="true">
                        <id>{$c/string()}</id>
                        <text>{$c/string()}</text>
                    </json:value>
            }
            </json:array>
};

declare function r-letter:stripPath($path)
{
    (: remove leading '/' :)
    let $toks := tokenize($path,'/')
    let $path := switch($toks[1]) 
        case ''   return string-join(subsequence($toks,2,count($toks)-1),'/')
        case '.'  return string-join(subsequence($toks,2,count($toks)-1),'/')
        default   return $path
    (: remove trailing '/', '.', '../ :)
    let $toks := tokenize($path,'/')
    let $path := switch($toks[last()]) 
        case ''   return string-join(subsequence($toks,1,count($toks)-1),'/')
        case '.'  return string-join(subsequence($toks,1,count($toks)-1),'/')
        case '..' return string-join(subsequence($toks,1,count($toks)-2),'/')
        default   return $path
    return
        $path
};

declare function r-letter:addPath($base,$path)
{
        string-join(($base, r-letter:stripPath($path)),'/')
};

(:~
 : GET: nabu/dos
 : List docs in collection 
 : 
 : @param   $base  base uri
 : @param   $path  relative path
 : 
 : @return  bundle <collections/>
 : 
 : @since v0.7
 :)
declare
    %rest:GET
    %rest:path("nabu/docs")
    %rest:query-param("base", "{$base}", "/db/apps/nabuData/data/FHIR")   
    %rest:query-param("path", "{$path}", "")
    %rest:produces("application/xml", "text/xml")
function r-letter:docs(
          $base as xs:string*
        , $path as xs:string*
        )
{
    try{
        let $collpath := r-letter:addPath($base,$path)
        let $coll := 
            <docs>
                <collection>{$collpath}</collection>
            {
                for $c in xmldb:xcollection($collpath)
                order by util:document-name($c)
                return
                    $c
            }
            </docs>
        return
            $coll
    } catch * {
        r-letter:rest-response(404, concat('Invalid path? : ', $path))
    }
};
