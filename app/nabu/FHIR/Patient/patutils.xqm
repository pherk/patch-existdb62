xquery version "3.0";

(:~
: Patient utilities
: @author Peter Herkenrath
: @version 0.9
: @see http://enahar.org
:
:)
module namespace patutils = "http://enahar.org/exist/apps/nabu/patutils";
declare namespace fhir   = "http://hl7.org/fhir";

declare function patutils:formatFHIRname(
          $pat as element(fhir:Patient)
        ) as xs:string
{
    let $name := $pat/fhir:name[fhir:use/@value='official']
    return
        concat(
              $name/fhir:family/@value
            , ', '
            , $name/fhir:given/@value
            , ', *'
            , tokenize($pat/fhir:birthDate/@value,'T')[1]
            )
};

declare function patutils:generateText(
          $patient as element(fhir:Patient)
        ) as element(fhir:text)
{
    let $composite-name := patutils:formatFHIRname($patient)
    let $text :=
            <text xmlns="http://hl7.org/fhir">
                <status value="generated"/>
                <div xmlns="http://www.w3.org/1999/xhtml">
                    <div class="composite-name">{$composite-name}</div>
                </div>
            </text>
    return
        $text
};