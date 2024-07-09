xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

let $cc := collection('/db/apps/nabuCom/data/Compositions')
let $sdir := 'Befunde16'
let $ecs := $cc/fhir:Composition[fhir:section/fhir:code[starts-with(fhir:coding/fhir:code/@value,$sdir)]][fhir:section//tei:div[@type='letter-body'][not(*)]]
let $dirs := for $c in $ecs
        let $dir :=  tokenize($c/fhir:section/fhir:code/fhir:coding[fhir:system/@value="#nabu-report-source"]/fhir:code/@value,'/')[1]
        return $dir
return
    <letters>
        {
for $e in $ecs
return
    <letter path="{$sdir}">{$e/fhir:section/fhir:code/fhir:coding[fhir:system/@value="#nabu-report-source"]/fhir:code/@value/string()}</letter>
        }
    </letters>