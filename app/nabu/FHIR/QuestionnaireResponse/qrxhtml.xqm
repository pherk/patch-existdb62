xquery version "3.0";

(:~
 : Transforms Questionnaire to an XML file (model plus output elements) which can be load from XForms
 : the first group level will transformed to tab panels
 : 
 : @author Peter Herkenath
 : @version 0.1
 : @since Nabu 0.8
 :)

module namespace qrhtml = "http://enahar.org/exist/apps/nabu/qr-html";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace bf="http://betterform.sourceforge.org/xforms";
declare namespace fhir= "http://hl7.org/fhir";

declare function qrhtml:transform(
      $q as element(fhir:Questionnaire)
    ) as item()
{
    let $item := $q/fhir:item
    return
    <div xmlns="http://www.w3.org/1999/xhtml" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:bf="http://betterform.sourceforge.org/xforms" xmlns:xf="http://www.w3.org/2002/xforms">
        {qrhtml:mkModel($q)}
        <xf:group id="editQRGroup" ref="bf:instanceOfModel('m-qrmaster','i-qrs-user')/*:QuestionnaireResponse[index('r-qrs-id')]" class="tabframe">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="bf:instanceOfModel('m-qrmaster','i-control-center')/*:qr-dirty" value="'true'"/>
            </xf:action>
            <div class="tabs">
                <xf:repeat nodeset="instance('tabset-instance')/item" id="tab-item-repeat">
                    <xf:trigger ref="." appearance="minimal"> 
                        <xf:label>
                            <xf:output ref="."/>
                        </xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('tabset-instance')/@value" value="instance('tabset-instance')/item[index('tab-item-repeat')]"/>
                            <xf:toggle ref=".">
                                <xf:case value="@value"/>
                            </xf:toggle>
                        </xf:action>
                    </xf:trigger>
                </xf:repeat>
            </div>
            {qrhtml:mkQRItem($item,0)}
        </xf:group>
    </div>
};

declare function qrhtml:mkModel(
      $q as element(fhir:Questionnaire)
    ) as item()
{
    let $qid := $q/fhir:id/@value/string()
    let $tabset := for $t in $q/fhir:item/fhir:item[fhir:type/@value='group']
        let $tid := concat('1-',$t/fhir:linkId/@value/string())
        let $text := $t/fhir:text/@value/string()
        return
          <item value="{$tid}">{$text}</item>
    return
    <div xmlns="http://www.w3.org/1999/xhtml" style="display:none">
        <xf:model id="{$qid}" ev:event="xforms-revalidate" ev:defaultAction="cancel">
        <xf:instance xmlns="" id="tabset-instance">
                <tabset value="editQR">
                    {$tabset}
                </tabset>
        </xf:instance>
        </xf:model>
    </div>
};

(:~ 
 : group childs of root -> tab
 : 
 : TODO: item childs of root?? tab0
 :)
declare function qrhtml:tabset($q)
{
    for $t in $q/fhir:item/fhir:item[fhir:type='group']
    let $tid := concat('1-',$item/fhir:linkId/@valze/string())
    let $text := $item/fhir:text/@value/string()
    return
         <item xmlns="http://www.w3.org/1999/xhtml" value="{$tid}">{$text}</item>
};

declare %private function qrhtml:mkQRItem(
      $item as item()
    , $level as xs:integer
    )
{
    (:
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($values)
return
    :)
    switch($item/fhir:type/@value)
    case 'group'  return qrhtml:mkQRGroupItem($item,$level)
    case 'choice' return qrhtml:mkQRChoiceItem($item,$level)
    default       return qrhtml:mkQRSimpleItem($item,$level)

};

declare %private function qrhtml:mkQRGroupItem(
      $item as element(fhir:item)
    , $level as xs:integer
    ) as item()
{
    let $linkId := $item/fhir:linkId/@value/string()
    let $sid := concat($level,'-',$linkId)
    let $text := $item/fhir:text/@value/string()
    let $childs :=
        for $i in $item/fhir:item
        return
            qrhtml:mkQRItem($i,$level+1)
    return
    if ($level=0)
    then (: root :)
        <div xmlns="http://www.w3.org/1999/xhtml" id="{$sid}" class="tabpane">
            <xf:label>{$text}</xf:label>
            <xf:switch>
            { $childs }
            </xf:switch>
        </div>
    else if ($level=1)
    then (: tabs :)
        <xf:case id="{$sid}">
            <xf:label>{$text}</xf:label>
            <br xmlns="http://www.w3.org/1999/xhtml"></br>
            { $childs }
        </xf:case>
    else (: other groups :)
        <xf:group id="{$sid}">
            <xf:label>{$text}</xf:label>
            { $childs }
        </xf:group>
};

declare %private function qrhtml:mkQRSimpleItem(
      $item as element(fhir:item)
    , $level as xs:integer
    )
{
(: 
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($level)
:)
    let $linkId := $item/fhir:linkId/@value/string()
    let $sid := concat($level,'-',$linkId)
    let $text := $item/fhir:text/@value/string()
    let $elem :=
            switch ($item/fhir:type/@value)
            case 'integer'  return "valueInteger"
            case 'string'   return "valueString"
            case 'float'    return "valueDecimal"
            case 'boolean'  return "valueBoolean"
            case 'dateTime' return "valueDateTime"
            case 'date'     return "valueDate"
            default return <error>{$item}</error>
    return
        <xf:output id="{$sid}" ref=".//*:item[*:linkId/@value='{$linkId}']/*:answer/*:{$elem}/@value">
            <xf:label class="svListHeader">{$text}</xf:label>
        </xf:output>
};

declare %private function qrhtml:mkQRChoiceItem(
      $item as element(fhir:item)
    , $level as xs:integer
    ) as item()
{
(: 
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($simple)
:)
    let $linkId := $item/fhir:linkId/@value/string()
    let $sid := concat($level,'-',$linkId)
    let $text := $item/fhir:text/@value/string()
    return
        <xf:output id="{$sid}" ref=".//*:item[*:linkId/@value='{$linkId}']/*:answer//*:display/@value">
            <xf:label class="svListHeader">{$text}</xf:label>
        </xf:output> 
};

