xquery version "3.0";
(:~
 : Transforms (external) data structures to populate QuestionnaireResponses
 : 
 : @author Peter Herkenath
 : @version 0.1
 : @since Nabu 0.8
 : @param $item  (root is Questionnaire/fhir:item)
 : @param $values item() structured as below
 : 
 : 
 :  :)
module namespace qrtf = "http://enahar.org/exist/apps/nabu/qr-transform";
declare namespace fhir= "http://hl7.org/fhir";

(:~
 : data must be structured homolog to the item-tree of the corresponding Questionnaire 
 : at the monent group and other 'simple' item will be handled differently
 : root group is '0'-level
 : the first group level converts into tab groups to keep the value panel small enough
 : TODO: mixed content on first level???
 : second and further levels remain as they are
 : semantic categories
 : - group = fhir:item[fhir:type='group']
 : - choice = fhir:item[fhir:type='choice'] also coded as simple in data structure (display values are taken fromQuestionnaire)
 : - simple = fhir:item[fhir:type=('integer','decimal','boolean','string','date','dateTime')]
 : the sequence of value items must be the same as in the Questionnaire
 : example with mixed content: demography from neodat import
 :      <group>
 :          <simple>{$orbis-pid}</simple>                                                        (integer)
 :          <simple>{$fs/field[@linkId='neodat-pid']/@value/string()}</simple>                   (integer)
 :          <group>
 :              <simple>{$fs/field[@linkId='pat-family']/@value/string()}</simple>               (string)
 :              <simple>{$fs/field[@linkId='pat-given']/@value/string()}</simple>                (string)
 :              <simple>{$fs/field[@linkId='pat-birthdate']/@value/string()}T00:00:00</simple>   (dateTime analog to Patient/fhir:birthDate)
 :              <simple>{qrimport:mapSex($fs/field[@linkId='pat-sex']/@value/string())}</simple> (choice: raw value mapped to option)
 :          </group>
 :      </group>
 :)

declare function qrtf:choiceDisplay(
      $field as xs:string
    , $code as xs:string
    , $quest as element(fhir:Questionnaire)
    ) as xs:string?
{
    $quest//fhir:item[fhir:linkId/@value=$field]/fhir:option[.//fhir:code/@value=$code]//fhir:display/@value/string()
};


declare function qrtf:mkQRItem(
      $item as item()
    , $values as item()*
    )
{
    (:
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($values)
return
    :)
    switch($item/fhir:type/@value)
    case 'group'  return qrtf:mkQRGroupItem($item,$values)
    case 'choice' return qrtf:mkQRChoiceItem($item,$values)
    default return qrtf:mkQRSimpleItem($item,$values)

};

declare %private function qrtf:mkQRGroupItem(
      $item as element(fhir:item)
    , $values as element(group)
    ) as item()
{
    <item xmlns="http://hl7.org/fhir">
        {$item/fhir:linkId}
        {$item/fhir:text}
        {$item/fhir:type}
        { for $i at $nth in $item/fhir:item
            return
                qrtf:mkQRItem($i, $values/*[$nth])
        }
    </item>
};

declare %private function qrtf:mkQRSimpleItem(
      $item as element(fhir:item)
    , $simple as element(simple)
    )
{
    let $value := $simple/string()
(: 
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($value)
:)
    return
    <item xmlns="http://hl7.org/fhir">
        {$item/fhir:linkId}
        {$item/fhir:text}
        <answer>
        {
            switch ($item/fhir:type/@value)
            case 'integer' return <valueInteger value="{$value}"/>
            case 'string' return <valueString value="{$value}"/>
            case 'float' return <valueDecimal value="{$value}"/>
            case 'boolean' return <valueBoolean value="{$value}"/>
            case 'dateTime' return <valueDateTime value="{$value}"/>
            case 'date' return <valueDate value="{$value}"/>
            default return <error>{$item}</error>
        }
        </answer>
    </item>
};

declare %private function qrtf:mkQRChoiceItem(
      $item as element(fhir:item)
    , $simple as element(simple)
    ) as item()
{
(: 
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($simple)
:)
    let $value := $simple/string()
    let $disp := $item/fhir:option[.//fhir:code/@value=$value]//fhir:display/@value/string()
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
