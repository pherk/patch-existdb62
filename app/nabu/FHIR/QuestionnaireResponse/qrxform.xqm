xquery version "3.0";

(:~
 : Transforms Questionnaire to an XML file (model plus input elements) which can be load from XForms
 : the first group level will transformed to tab panels
 : 
 : @author Peter Herkenath
 : @version 0.2
 : @since Nabu 0.8
 :)

module namespace qrxf = "http://enahar.org/exist/apps/nabu/qr-xform";

import module namespace q2qr = "http://enahar.org/exist/apps/nabu/q2qr" at "/db/apps/nabu/FHIR/QuestionnaireResponse/q2qr.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace bf="http://betterform.sourceforge.org/xforms";
declare namespace fhir= "http://hl7.org/fhir";

declare function qrxf:transform(
      $q as element(fhir:Questionnaire)
    ) as item()
{
    let $callsGolem := exists($q//fhir:extension[@url='www.enahar.org/exist/apps/nabu/questionnaire-item-mapping'])
    let $root := $q/fhir:item
    let $isTab :=
            $root/fhir:item/fhir:extension[@url="http://hl7.org/fhir/StructureDefinition/questionnaire-displayCategory"]//fhir:code/@value='tab'
    return
    <div xmlns="http://www.w3.org/1999/xhtml" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:bf="http://betterform.sourceforge.org/xforms" xmlns:xf="http://www.w3.org/2002/xforms">
        { qrxf:mkModel($q, $callsGolem) }

        { qrxf:mkQRItem($root,0,$isTab, $callsGolem) }
    </div>
};

declare function qrxf:mkModel(
      $q as element(fhir:Questionnaire)
    , $callsGolem as xs:boolean
    ) as item()
{
    (: TODO eval tab extension :)
    let $qid := $q/fhir:id/@value/string()
    let $tabset := for $t in $q/fhir:item/fhir:item[fhir:type/@value='group']
        let $tid := concat('1-',$t/fhir:linkId/@value/string())
        let $text := $t/fhir:text/@value/string()
        return
          <item value="{$tid}">{$text}</item>
    return
    <div xmlns="http://www.w3.org/1999/xhtml" style="display:none">
        <xf:model id="{$qid}" ev:event="xforms-revalidate" ev:defaultAction="cancel">
            <xf:instance xmlns="" id="i-qr">
                <data/>
            </xf:instance>

            <xf:submission id="s-load-qr-from-master" resource="model:m-qrmaster#instance('i-qrs-user')//*:QuestionnaireResponse[index('r-qrs-id')]" instance="i-qr" replace="instance" method="get">
                <xf:action ev:event="xforms-submit-done">
                </xf:action>
                <xf:message ev:event="xforms-submit-error" level="ephemeral">Subform: cannot load from Master!.</xf:message>
            </xf:submission>
            <xf:submission id="s-update-qr-master" resource="model:m-qrmaster#instance('i-qrs-user')//*:QuestionnaireResponse[index('r-qrs-id')]" instance="i-qr" model="q-hilfsmittel--v2018-04-08" replace="none" method="post">
                <xf:action ev:event="xforms-submit-done">
                    <xf:message level="ephemeral">QR updated</xf:message>
                </xf:action>
                <xf:message ev:event="xforms-submit-error" level="ephemeral">Subform: cannot update Master!.</xf:message>
            </xf:submission>
            <xf:submission id="s-submit-qr" ref="instance('i-qr')" method="put" replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/questionnaireresponses?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
                <xf:header>
                    <xf:name>Content-Type</xf:name>
                    <xf:value>application/xml</xf:value>
                </xf:header>
                <xf:action ev:event="xforms-submit-done">
                </xf:action>
                <xf:message ev:event="xforms-submit-error" level="modal">cannot submit QuestionnaireResponse!</xf:message>
            </xf:submission>
            <xf:submission id="s-submit-pdf" ref="instance('i-qr')" method="post" replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/qr2pdf?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
                <xf:header>
                    <xf:name>Content-Type</xf:name>
                    <xf:value>application/xml</xf:value>
                </xf:header>
                <xf:action ev:event="xforms-submit-done"/>
                <xf:message ev:event="xforms-submit-error" level="modal">cannot submit QR PDF!</xf:message>
            </xf:submission>
        {
                if ($callsGolem)
                then
            (
                <xf:instance xmlns="" id="i-testitem">
                    <data/>
                </xf:instance>
            ,   <xf:submission id="s-golem-testitem" instance="i-testitem" replace="instance" method="get">
                    <xf:resource value="concat('/exist/restxq/golem/test/loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;item?item=',instance('i-control-center')/*:qr-itemid,'&amp;value=',encode-for-uri(instance('i-control-center')/*:qr-itemval),'&amp;context=',encode-for-uri('nabu/patients/'),bf:instanceOfModel('m-qrmaster','i-pat')/*:id/@value)"/>
                    <xf:action ev:event="xforms-submit-done">
                    </xf:action>
                    <xf:message ev:event="xforms-submit-error" level="ephemeral">Subform: cannot load from Master!.</xf:message>
                </xf:submission>
            )
            else ()
        }  
            <xf:instance xmlns="" id="i-login">
                <data/>
            </xf:instance>
            <xf:submission id="s-load-login-from-master" resource="model:m-patient#instance('i-login')//*:data" instance="i-login" replace="instance" method="get">
                <xf:message ev:event="xforms-submit-error" level="ephemeral">login: cannot load from Master!.</xf:message>
            </xf:submission>

 			<xf:instance xmlns="" id="i-control-center">
				<data>
					<qr-wf>false</qr-wf>
					<qr-xform>0.2</qr-xform>
                    <qr-itemid/>
                    <qr-itemval/>
                    <qr-iter/>
				</data>
			</xf:instance>
            <xf:instance xmlns="" id="tabset-instance">
                <tabset value="editQR">
                    {$tabset}
                </tabset>
            </xf:instance>
            { qrxf:mkBricks($q) }
            <xf:action ev:event="xforms-ready">
                <xf:send submission="s-load-login-from-master"/>
                <xf:send submission="s-load-qr-from-master"/>
                { qrxf:initialValues($q) }
            </xf:action>
        </xf:model>
    </div>
};

declare function qrxf:initialValues(
      $q
    ) as item()?
{
    let $set := for $t in $q//fhir:item
        let $linkId := $t/fhir:linkId/@value/string()
        return
            switch($t/fhir:initialDateTime/@value)
            case 'h' return
                let $ref := concat("instance('i-qr')//*:item[*:linkId/@value='",$linkId,"']/*:answer/*:valueDateTime/@value")
                let $ival := 'adjust-dateTime-to-timezone(current-dateTime())'
                return
                    <xf:setvalue ref="{$ref}" value="{$ival}"/>
            default return ()
    return
        $set
};

(:~ 
 : group childs of root -> tab
 : 
 : TODO: item childs of root?? tab0
 :)
declare function qrxf:tabs()
{
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
};

declare function qrxf:tabset($q)
{
    for $t in $q/fhir:item/fhir:item[fhir:type='group']
    let $tid := concat('1-',$item/fhir:linkId/@valze/string())
    let $text := $item/fhir:text/@value/string()
    return
         <item xmlns="http://www.w3.org/1999/xhtml" value="{$tid}">{$text}</item>
};

declare %private function qrxf:mkBricks($q) 
{
    let $root := $q/fhir:item
    let $repeats := $root/fhir:item[fhir:repeats/@value='true']
    return
        if($repeats)
        then
            <xf:instance xmlns="" id="i-bricks">
                <bricks xmlns="http://hl7.org/fhir">
                {
                    for $r in $repeats
                    return
                        q2qr:item($r)
                }
                </bricks>
            </xf:instance>
        else
            ()
};

declare %private function qrxf:triggerGroup()
{
    <xf:group id="maintriggers" class="svTriggerGroup">
        <table>
            <tr>
                <td>
                    <xf:trigger ref="bf:instanceOfModel('m-qrmaster','i-control-center')/*:qr-dirty[.='true']" class="svUpdateMasterTrigger">
                        <xf:label>Speichern</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:action if="instance('i-control-center')/*:qr-wf='true'">
                                <xf:setvalue ref="instance('i-qr')/*:status/@value" value="'completed'"/>
                            </xf:action>
                            <xf:send submission="s-update-qr-master"/>
                            <xf:send submission="s-submit-qr"/>
                            <xf:toggle case="listQRs"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                    <xf:trigger class="svUpdateMasterTrigger">
                        <xf:label>Schließen</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:toggle case="listQRs"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                    <xf:trigger class="svUpdateMasterTrigger">
                        <xf:label>PDF</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:action if="instance('i-control-center')/*:qr-wf='true'">
                                <xf:setvalue ref="instance('i-qr')/*:status/@value" value="'completed'"/>
                            </xf:action>
                            <xf:load show="new">
                                <xf:resource value="concat('/exist/restxq/nabu/qr2pdf?realm=kikl-spz&amp;loguid=u-admin&amp;lognam=print-bot&amp;qrid=',instance('i-qr')/*:id/@value)"/>
                            </xf:load>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                    <xf:group ref="bf:instanceOfModel('m-qrmaster','i-control-center')/*:qr-dirty[.='true']">
                        <xf:label class="svListHeader">Final?</xf:label>
                        <xf:input ref="instance('i-control-center')/*:qr-wf" class="xsdBoolean"/>
                    </xf:group>
                </td>
            </tr>
        </table>
    </xf:group>
};

declare %private function qrxf:mkQRItem(
      $item as item()
    , $level as xs:integer
    , $isTab as xs:boolean
    , $callsGolem as xs:boolean
    )
{
    (:
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($values)
    return
    :)
    switch($item/fhir:type/@value)
    case 'group'  return qrxf:mkQRGroupItem($item,$level,$isTab, $callsGolem)
    case 'choice' return qrxf:mkQRChoiceItem($item,$level, false())
    default       return qrxf:mkQRSimpleItem($item,$level, false())

};
declare %private function qrxf:mkQRTableItem(
      $item as item()
    , $level as xs:integer
    )
{
    switch($item/fhir:type/@value)
    case 'choice' return qrxf:mkQRChoiceItem($item,$level, true())
    default       return qrxf:mkQRSimpleItem($item,$level, true())
};

declare %private function qrxf:mkQRGroupItem(
      $item as element(fhir:item)
    , $level as xs:integer
    , $isTab as xs:boolean
    , $callsGolem as xs:boolean
    ) as item()
{
    let $linkId := $item/fhir:linkId/@value/string()
    let $sid := concat($level,'-',$linkId)
    let $text := $item/fhir:text/@value/string()
let $lll := util:log-system-out($level)
    return
    if ($level=0)
    then (: root :)
        if ($isTab)
        then
            <xf:group id="{$sid}" ref="instance('i-qr')" class="tabframe">
                { qrxf:insertGolemCopyItems($callsGolem) }
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="bf:instanceOfModel('m-qrmaster','i-control-center')/*:qr-dirty" value="'true'"/>
                </xf:action>
                { qrxf:triggerGroup() }
                { qrxf:tabs() }
                <div xmlns="http://www.w3.org/1999/xhtml" class="tabpane">
                    <xf:label>{$text}</xf:label>
                    <xf:switch>
                    { qrxf:splitChilds($item,$level,$isTab,$callsGolem) }
                    </xf:switch>
                </div>
            </xf:group>
        else
            <xf:group id="{$sid}" class="svFullGroup">
            { qrxf:insertGolemCopyItems($callsGolem) }
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="bf:instanceOfModel('m-qrmaster','i-control-center')/*:qr-dirty" value="'true'"/>
                </xf:action>
                <xf:label>{$text}</xf:label>
                { qrxf:triggerGroup() }
                { qrxf:splitChilds($item,$level,$isTab,$callsGolem) }
            </xf:group>
    else if ($level=1 and $isTab)
    then (: tabs :)
        <xf:case id="{$sid}">
            <xf:label>{$text}</xf:label>
            <br xmlns="http://www.w3.org/1999/xhtml"></br>
            { qrxf:splitChilds($item,$level,$isTab,$callsGolem) }
        </xf:case>
    else (: other groups :)
        <xf:group id="{$sid}">
            { if ($item/fhir:repeats/@value='true')
                then ()
                else <xf:label>{$text}</xf:label>
            }
            { qrxf:splitChilds($item,$level,$isTab,$callsGolem) }
        </xf:group>
};

declare %private function qrxf:insertGolemCopyItems(
          $callsGolem as xs:boolean
        ) as item()?
{
    if ($callsGolem)
    then
        <xf:action ev:event="copyItemsFromGolem">
            <xf:setvalue ref="instance('i-control-center')/*:qr-iter" value="xs:int(1)"/>
            <xf:action while="instance('i-control-center')/*:qr-iter &lt;= count(instance('i-testitem')/*:out)">
                <xf:setvalue ref="instance('i-qr')//*:item[*:linkId/@value=instance('i-testitem')/*:out[xs:int(instance('i-control-center')/*:qr-iter)]/*:id/@value]/*:answer/*:valueInteger/@value" value="instance('i-testitem')/*:out[xs:int(instance('i-control-center')/*:qr-iter)]/*:value/@value"/>
                <xf:setvalue ref="instance('i-control-center')/*:qr-iter" value="instance('i-control-center')/*:qr-iter + 1"/>
            </xf:action>
        </xf:action>
    else ()
};

declare %private function qrxf:splitChilds(
      $item as element(fhir:item)
    , $level as xs:integer
    , $isTab as xs:boolean
    , $callsGolem as xs:boolean
    ) as item()*
{
    (: take first group and make table :)
    let $split := local:splitList($item/fhir:item,function($i){if($i/fhir:type/@value=('group')) then true() else false()})
    let $lll := if ($level>1) then util:log-system-out($split) else ()
    let $pre   := qrxf:mkTable($split/pre/fhir:item,$level+1,$item)
    let $cont :=
        for $i in $split/cont/fhir:item
        return
            qrxf:mkQRItem($i,$level+1,$isTab,$callsGolem)
    let $childs := ($pre,$cont)
    return
        $childs
};

declare %private function qrxf:mkTable(
          $is as element(fhir:item)*
        , $level as xs:integer
        , $parent as element(fhir:item)
        ) as item()*
{
    let $isRepeat := $parent/fhir:repeats/@value='true'
    let $linkId   := $parent/fhir:linkId/@value/string()
    let $rid      := concat('r-',$level,$linkId,'items-id')
    let $childs   := 
            <tr xmlns="http://www.w3.org/1999/xhtml">
            {
                for $i in $is
                return
                    <td xmlns="http://www.w3.org/1999/xhtml">{qrxf:mkQRTableItem($i,$level)}</td>
            }
            </tr>
    return
    if ($is)
    then
        (
        <table xmlns="http://www.w3.org/1999/xhtml">
            <thead>
                <tr>
                {
                    for $l in $is/fhir:text/@value/string()
                    return
                        <th xmlns="http://www.w3.org/1999/xhtml">{$l}</th>
                }
                </tr>
            </thead>
    {
        if ($isRepeat)    
        then
            <tbody  xmlns="http://www.w3.org/1999/xhtml" id="{$rid}" xf:repeat-nodeset=".//*:item[*:linkId/@value='{$linkId}']">
                { $childs }
            </tbody>
        else
            <tbody xmlns="http://www.w3.org/1999/xhtml">
                { $childs }
            </tbody>
    }
        </table>
    ,   if ($isRepeat)
        then qrxf:mkRepeatTriggerGroup($parent, $rid)
        else ()
        )
    else ()
};

declare %private function qrxf:mkRepeatTriggerGroup($item, $rid)
{
    let $linkId := $item/fhir:linkId/@value/string()
    return
    <xf:group class="svTriggerGroup">
        <table xmlns="http://www.w3.org/1999/xhtml">
            <tr>
                <td>
                    <xf:trigger class="svAddTrigger" ref="./*:status[@value=('in-progress','stopped','completed','amended')]">
                        <xf:label>Neu</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert ref="instance('i-qr')//*:item[*:linkId/@value='{$linkId}']" context="instance('i-qr')//*:item[*:linkId/@value='{$linkId}']/.." origin="instance('i-bricks')/*:item[*:linkId/@value='{$linkId}']"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                    <xf:trigger class="svDelTrigger" ref="./*:status[@value=('in-progress','stopped','completed','amended')]">
                        <xf:label>Löschen</xf:label>
                        <xf:action ev:event="DOMActivate" if="count(instance('i-qr')//*:item[*:linkId/@value='{$linkId}'])&gt; 0">
                            <xf:delete ref="instance('i-qr')//*:item[*:linkId/@value='{$linkId}'][index('{$rid}')]"/>
                        </xf:action>
                    </xf:trigger>
                </td>
            </tr>
        </table>
    </xf:group>
};

declare function local:splitList(
      $list as item()*
    , $fun as function(item()) as xs:boolean
    ) as item()*
{
    if (count($list)>0)
    then local:splitList2(head($list),tail($list),$fun,())
    else ()
};

declare function local:splitList2(
      $head as item()
    , $tail as item()*
    , $fun as function(item()) as xs:boolean
    , $acc as item()*
    ) as item()
{
    if ($fun($head))
    then <ret>
            <pre>{reverse($acc)}</pre>
            <cont>{($head,$tail)}</cont>
        </ret>
    else
        let $res := ($head, $acc)
        return
            if (count($tail)>0)
            then local:splitList2(head($tail),tail($tail),$fun,$res)
            else
                <ret>
                    <pre>{reverse($res)}</pre>
                    <cont/>
                </ret>
};

declare %private function qrxf:mkQRSimpleItem(
      $item as element(fhir:item)
    , $level as xs:integer
    , $table as xs:boolean
    )
{
(: 
let $lll := util:log-system-out($item)
let $lll := util:log-system-out($level)
:)
    let $linkId := $item/fhir:linkId/@value/string()
    let $sid := concat($level,'-',$linkId)
    let $text := $item/fhir:text/@value/string()
    let $elem := qrxf:mapQType2QR($item)
    let $unit := qrxf:extension-unit($item)
    let $class := qrxf:extension-css-class($item)
    let $ref := concat(".//*:item[*:linkId/@value='",$linkId,"']/*:answer/*:",$elem,"/@value")
    return
        if ($item/fhir:readOnly and $item/fhir:readOnly/@value='true')
        then
            <xf:output id="{$sid}" ref="{$ref}" class="{$class}">
            {    
                if ($table) 
                then ()
                else <xf:label class="svListHeader">{$text}</xf:label>
            }
            </xf:output>
        else
            <xf:input id="{$sid}" ref="{$ref}" class="{$class}">
            {    
                if ($table) 
                then ()
                else <xf:label class="svListHeader">{$text}</xf:label>
            }
            { $unit }
            { qrxf:extension-GolemCall($item,$linkId,$elem) }
        </xf:input>
};

declare %private function qrxf:mapQType2QR(
          $item as element(fhir:item)
    ) as xs:string
{
    switch ($item/fhir:type/@value)
    case 'integer'   return "valueInteger"
    case 'string'    return "valueString"
    case 'float'     return "valueDecimal"
    case 'boolean'   return "valueBoolean"
    case 'dateTime'  return "valueDateTime"
    case 'date'      return "valueDate"
    case 'reference' return "valueReference"
    default return <error>{$item}</error>
};

declare %private function qrxf:extension-unit(
          $item as element(fhir:item)
    ) as item()?
{
    let $ext := $item/fhir:extension[@url='http://hl7.org/fhir/StructureDefinition/questionnaire-unit']
    return
        if ($ext)
        then
            <xf:hint>{$ext//fhir:display/@value/string()}</xf:hint>
        else ()
};

declare %private function qrxf:extension-css-class(
          $item as element(fhir:item)
    ) as xs:string
{
    let $ext := $item/fhir:type/fhir:extension[@url='http://hl7.org/fhir/StructureDefinition/questionnaire-displayCategory']
    return
        if ($ext)
        then
            $ext//fhir:coding[fhir:system/@value='#nabu-questionnaire-display-class']/fhir:code/@value/string()
        else 
            switch($item/fhir:type/@value)
            case "boolean" return "xsdBoolean svRepeatBool"
            case "string"  return "medium-input"
            default return "short-input"
};

declare %private function qrxf:extension-GolemCall(
          $item as element(fhir:item)
        , $linkId as xs:string
        , $elem as xs:string
        ) as item()?
{
    let $ext := $item/fhir:extension[@url='www.enahar.org/exist/apps/nabu/questionnaire-item-mapping']
    return
        if ($ext)
        then
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-control-center')/*:qr-itemid" value="'{$linkId}'"/>
                <xf:setvalue ref="instance('i-control-center')/*:qr-itemval" value="instance('i-qr')//*:item[*:linkId/@value='{$linkId}']/*:answer/*:{$elem}/@value"/>
                <xf:send submission="s-golem-testitem"/>
                <xf:dispatch name="copyItemsFromGolem" targetid="{concat('0-',tokenize($linkId,'-')[1])}"/>
            </xf:action>
        else ()
};

declare function qrxf:choiceOptions2itemset(
      $item as element(fhir:item)
    , $empty as xs:boolean
    ) as item()*
{
    let $set := for $o in $item/fhir:option
        let $disp := $o/fhir:valueCoding/fhir:display/@value/string()
        let $code := $o/fhir:valueCoding/fhir:code/@value/string()
        return
            <xf:item>
                <xf:label>{$disp}</xf:label>
                <xf:value>{$code}</xf:value>
            </xf:item>
    return
        $set
};

declare %private function qrxf:mkQRChoiceItem(
      $item as element(fhir:item)
    , $level as xs:integer
    , $table as xs:boolean
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
        <xf:select1 id="{$sid}" ref=".//*:item[*:linkId/@value='{$linkId}']/*:answer//*:code/@value" class="short-input">
        {   
            if ($table) 
            then ()
            else <xf:label class="svListHeader">{$text}</xf:label>
        }
            { qrxf:choiceOptions2itemset($item,true()) }
            <!--
            <xf:itemset ref="bf:instanceOfModel('m-qrmaster','i-questionnaire')//*:item[*:linkId/@value='{$linkId}']/*:option/*:valueCoding">
                <xf:label ref=".//*:display/@value"/>
                <xf:value ref=".//*:code/@value"/>                                        
            </xf:itemset>
            -->
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-qr')//*:item[*:linkId/@value='{$linkId}']/*:answer//*:display/@value" value="bf:instanceOfModel('m-qrmaster','i-questionnaire')//*:item[*:linkId/@value='{$linkId}']/*:option[.//*:code/@value=instance('i-qr')//*:item[*:linkId/@value='{$linkId}']/*:answer//*:code/@value]/*:display/@value"/>
            </xf:action>
        </xf:select1> 
};
