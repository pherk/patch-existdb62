xquery version "3.0";

(:~
: driver for doc transformation
: @author Peter Herkenrath 
: @version 1.0
: @see http://enahar.org
:
:)

import module namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace helper         = "http://enahar.org/exist/apps/nabudocs/helper"  at "../modules/helper.xqm";
import module namespace dl2tei         = "http://enahar.org/exist/apps/nabudocs/dl2tei"  at "../modules/dl2tei.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace fhir= "http://hl7.org/fhir";

let $import-date := "2020-07-02"
let $import-folder := "Befunde2020"

let $groups      := ('Arzt','Psychologie')
let $data-perms    := "rwxrw-r--"
let $data-group    := "spz"
let $import-base := "/db/apps/nabuCom/import"
let $error-base  := "/db/apps/nabuCom/errors"
let $fhir-base   := "/db/apps/nabuCompositions/data"

for $group in $groups
let $letters := collection(concat($import-base, "/",$import-folder, "/", $group,'/Herkenrath'))
let $ass     := 
    <asserter xmlns="http://hl7.org/fhir">
        <reference value="metis/practitioners/u-admin"/>
        <display value="importBot"/>
    </asserter>
(: 
let $lll := util:log-system-out(count($letters))
let $lll := util:log-system-out(count($letters[//*:table/*:tr[1]/*:td[2][matches(.,'Zentrum')]]))
:)
for $l in xmldb:find-last-modified-since($letters,xs:dateTime(concat($import-date, "T00:00:00")))[matches(.,'Cork')]
let $coll := substring-after(util:collection-name($l), concat($import-base,'/'))
let $fn := util:document-name($l)
return
try {
    let $lt := dl2tei:ltrans($l,$fn)

    let $subject := $lt//tei:opener/tei:subject
    let $ss   := helper:subject2patient($subject)
    let $as   := helper:signees($lt//tei:signed, $coll)
    let $rec  := helper:physician($lt//tei:opener/tei:address)

    return
        if ($ss/*:error or $rec/*:error or $as/*:error)
        then
            let $uid := concat('e-',util:uuid())
            let $data :=
                    <error id="{$uid}">
                        <file>{$fn}</file>
                        <collection>{$coll}</collection>
                        { if ($ss/*:error) then $ss else () }
                        { if ($as/*:error) then $as else () }
                        { if ($rec/*:error) then $rec else () }
                    </error>
            return
                ($lt,$data)
        else
            (:
            for $sub in $ss/fhir:subject
            let $com := helper:composition($lt, $coll, $fn, $sub, $group, $as/fhir:author, $rec/fhir:recipient)
            let $cds := helper:conditions($lt,$coll,$fn,$sub,$ass)
            return
                ($com,$cds)
            :)
            ($lt,$ss,$as,$rec)

} catch * {
    <error>
        <file>{$fn}</file>
        <collection>{$coll}</collection>
        <convert>{string-join(($err:code , $err:description, $err:value),'_')}</convert>
    </error>
}