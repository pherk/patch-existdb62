xquery version "3.0";

(:~
 : Transforms Questionnaire to an QuestionnaireResponse
 : 
 : @author Peter Herkenath
 : @version 0.1
 : @since Nabu 0.9
 :)

module namespace q2qr = "http://enahar.org/exist/apps/nabu/q2qr";


declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace bf="http://betterform.sourceforge.org/xforms";
declare namespace fhir= "http://hl7.org/fhir";

declare variable $q2qr:qrinfo := doc('/db/apps/nabu/FHIR/QuestionnaireResponse/questionnaireresponse-infos.xml');

declare %private function q2qr:copy-wo-extension(
          $element as element()
        ) as element() {
    element {node-name($element)}
      {$element/@*,
          for $child in $element/node()[local-name(.)!='extension']
              return
               if ($child instance of element())
                 then q2qr:copy-wo-extension($child)
                 else $child
      }
};

declare function q2qr:item(
      $item as item()
    )
{
    (:
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($values)
return
    :)
    switch($item/fhir:type/@value)
    case 'group'  return q2qr:groupItem($item)
    case 'choice' return q2qr:choiceItem($item)
    default return q2qr:simpleItem($item)

};
declare %private function q2qr:groupItem(
      $item as element(fhir:item)
    ) as item()
{
    <item xmlns="http://hl7.org/fhir">
        {$item/fhir:linkId}
        {$item/fhir:text}
        {$item/fhir:type}
        { for $i at $nth in $item/fhir:item
            return
                q2qr:item($i)
        }
    </item>
};

declare %private function q2qr:simpleItem(
      $item as element(fhir:item)
    )
{
    <item xmlns="http://hl7.org/fhir">
        {$item/fhir:linkId}
        {$item/fhir:text}
        {$item/fhir:readOnly}
        <answer>
        {
            switch ($item/fhir:type/@value)
            case 'integer' return <valueInteger value="{$item/fhir:initialInteger/@value/string()}"/>
            case 'string' return <valueString value="{$item/fhir:initialString/@value/string()}"/>
            case 'float' return <valueDecimal value="{$item/fhir:initialFloat/@value/string()}"/>
            case 'boolean' return <valueBoolean value="{$item/fhir:initialBoolean/@value/string()}"/>
            case 'dateTime' return <valueDateTime value="{$item/fhir:initialDateTime/@value/string()}"/>
            case 'date' return <valueDate value="{$item/fhir:initialDate/@value/string()}"/>
            default return <error>{$item}</error>
        }
        </answer>
    </item>
};

declare %private function q2qr:choiceItem(
      $item as element(fhir:item)
    ) as item()
{
(: 
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($simple)
:)
    let $value := $item/fhir:initialCoding/fhir:code/@value/string()
    let $disp  := $item/fhir:initialCoding/fhir:display/@value/string()
    return
    <item xmlns="http://hl7.org/fhir">
        {$item/fhir:linkId}
        {$item/fhir:text}
        <answer>
            <valueCoding>
                <code value="{$value}"/>
                <display value="{$disp}"/>
            </valueCoding>         
        </answer>
    </item>
};

declare function q2qr:transform(
      $q as element(fhir:Questionnaire)
    ) as element(fhir:QuestionnaireResponse)
{
    let $qname := substring-after($q/fhir:id/@value,'q-')
    let $qrid := concat('qr-',$qname)
    let $qrb  := $q2qr:qrinfo//fhir:QuestionnaireResponse
    let $base := $q2qr:qrinfo//fhir:QuestionnaireResponse/fhir:*[not(self::fhir:id
                              or self::fhir:questionnaire
                            )]
    let $qr := 
            <QuestionnaireResponse xmlns="http://hl7.org/fhir">
                <id value="{$qrid}"/>
                {$base}
                <questionnaire>
                    <reference value="{concat('nabu/questionnaires/q-',$qname)}"/>
                    <display value="{$q/fhir:title/@value/string()}"/>
                </questionnaire>
                { q2qr:item($q/fhir:item) }
            </QuestionnaireResponse>
    return
        $qr
};
