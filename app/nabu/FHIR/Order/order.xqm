xquery version "3.0";
(:~
 : functionality and XFORMS for Orders
 : 
 : @author Peter Herkenrath
 : @version 0.6
 : 2014-10-31
 :)
module namespace order="http://enahar.org/exist/apps/nabu/order";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";

import module namespace r-user = "http://enahar.org/exist/restxq/metis/users"   at "/db/apps/metis/FHIR/user/user-routes.xqm";

import module namespace r-order = "http://enahar.org/exist/restxq/nabu/orders"   at "../Order/order-routes.xqm";

declare namespace ev  = "http://www.w3.org/2001/xml-events";
declare namespace xf  = "http://www.w3.org/2002/xforms";
declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

(:~
 : show order functionality for dashboard
 : 
 : @param $uid user id
 : @return html
 :)
declare function order:showFunctions($uid)
{
    <div>
        <h3>Anforderungen:</h3>
        <ul>
            <li>Neu:
                <a href="index.html?action=newOrder">
                    <img src="resources/images/share16x16.png" alt="MySelf"/>
                </a>
            </li>
            <li>An mich:
                <a href="index.html?action=listOrders&amp;filter=all">alle</a>,
                <a href="index.html?action=listOrders&amp;filter=open">offen</a>
            </li>
            <li>Von mir: <a href="index.html?action=listOrders&amp;filter=send">gesendet&amp;offen</a>
            </li>
        </ul>
    </div>
};

declare %private function order:ordersToRows($uref as xs:string, $roles, $orders)
{

    for $o in $orders/fhir:Order
    let $oid  := $o/fhir:id/@value/string()
    let $when := if ($o/fhir:when/fhir:code) then
            $o/fhir:when/fhir:code/fhir:coding/fhir:code/@value/string()
        else if ($o/fhir:when/fhir:schedule) then
            format-date(xs:date($o/fhir:when/fhir:schedule/fhir:event/fhir:value/@value/string()),"[D01]-[M01]-[Y02]")
        else ""
    let $isMe   := $uref = $o/fhir:source/fhir:reference/@value
    let $isSelf := $uref = $o/fhir:target/fhir:reference/@value
    let $name := $o/fhir:subject/fhir:display/@value/string()
    return
         <tr id="{$oid}">
            <td>{$when}</td>
            <td>{format-date(xs:date(tokenize($o/fhir:date/@value/string(),'T')[1]),"[D01]-[M01]-[Y02]")}</td>
            <td>{$name}</td>
            <td>{$o/fhir:reason/fhir:text/@value/string()}</td>
            <td>{count($o/fhir:detail)}</td>
            <td>{if ($isMe)
                    then (<span style="display:none">{$o/fhir:source//fhir:reference/@value/string()}</span>,<img src="resources/images/myself16x16.png" alt="MySelf"/>)
                    else $o/fhir:source/fhir:display/@value/string()
            }</td>
            <td>{if ($isSelf)
                    then (<span style="display:none">{$o/fhir:target/fhir:reference/@value/string()}</span>,<img src="resources/images/myself16x16.png" alt="MySelf"/>)
                    else $o/fhir:target/fhir:display/@value/string()
            }</td>
         </tr> 
};

(:~
 : show orders
 : 
 : @param $status (open, all, send)
 : @return html
 :)
declare function order:listOrders($status as xs:string)
{
    let $realm := "kikl-spz"
    let $org  := concat('metis/organizations/', $realm)
    let $logu   := r-practrole:userByAlias(xmldb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
let $roles  := r-user:rolesByID($uid, $realm, $uid)
let $myOrders := r-order:orders($realm,$uid, $unam, '1', '*',
                                "", $uid, '', 'appointment', 'requested',
                                "", "",
                                '1994-06-01T08:00:00', '2021-04-01T19:00:00',
                                'spz', 'date:desc', '')

let $head  := switch ($status)
    case 'open' return 'Offene Anforderungen'
    case 'all'  return 'Alle offenen Anforderungen'
    case 'send' return 'Gesendete Anforderungen'
    default return '??? Fehler'
return
<div><h2>{$head}<span> ({$myOrders/count})</span></h2>
    <table id="openorders" class="tablesorter">
    <thead>
        <tr id="0">
            <th>Fällig</th>
            <th>Datum</th>
            <th>Subject</th>
            <th>Anlass</th>
            <th>No.</th>
            <th>Von</th>
            <th>An</th>
        </tr>
    </thead>
    <tbody>{
      order:ordersToRows($loguref,$roles,$myOrders)
   }</tbody>
    <script type="text/javascript" defer="defer" src="FHIR/Order/listOrders.js"/>
    </table>
    <p><br/>
        <a href="index.html?action=newOrder">Neue Anforderung</a>
    </p>
</div>
};


declare variable $order:restxq-metis-users  := "/exist/restxq/metis/users";
declare variable $order:restxq-metis-users-ref  := "/exist/restxq/metis/users?_format=ref";
declare variable $order:restxq-metis-roles  := "/exist/restxq/metis/roles";
declare variable $order:restxq-metis-orgas  := "/exist/restxq/metis/organizations";

declare variable $order:restxq-orders       := "/exist/restxq/nabu/orders";
declare variable $order:restxq-patients     := "/exist/restxq/nabu/patients";

declare variable $order:order-infos-uri     := "FHIR/Order/order-infos.xml";

(:~
 : 
 : show xform for order
 : 
 : @return: () 
 :  
:)
declare function order:editOrdersByPID($pid as xs:string)
{
    let $logu   := r-practrole:userByAlias(xmldb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $realm  := 'metis/organizations/kikl-spzn'
    let $header := "Neue Anforderung: "
return
(<div style="display:none;">
    <xf:model id="order" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance  xmlns="" id="i-orders">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-orders"
                instance="i-orders"
				method="get"
				replace="instance"
				resource="{concat($order:restxq-orders,'?subject=', $pid)}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $uid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:action if="instance('i-orders')/*:count=0">
                            <xf:insert
                                    nodeset="instance('i-orders')/*:Order"
                                    context="instance('i-orders')"
                                    origin="instance('i-o-infos')/*:bricks/*:Order"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:date/@value"             value="'{adjust-dateTime-to-timezone(current-dateTime(),())}'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:source/*:reference/@value" value="'{concat('metis/practitioners/',$uid)}'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:source/*:display/@value" value="'{$unam}'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:target/*:role/@value"    value="'spz-ateam'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:target/*:display/@value" value="'SPZ ATeam'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:subject/*:reference/@value"
                                    value="concat('nabu/patients/',instance('i-patient')/*:id/@value)"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:subject/*:display/@value"
                                    value="concat(instance('i-patient')/*:name[fhir:use/@value='official']/*:family/@value,', ',instance('i-patient')/*:name[fhir:use/@value='official']/*:given/@value,', *',instance('i-patient')/*:birthDate/@value)"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:extension[@url='#order-status']//*:text/@value" value="'zugewiesen'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:extension[@url='#order-status']//*:display/@value" value="'zugewiesen'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[1]/*:extension[@url='#order-status']//*:code/@value" value="'requested'"/>
                            <xf:setvalue ref="instance('i-orders')/*:count" value="'1'"/>
                            <xf:setvalue ref="instance('i-orders')/*:length" value="'1'"/>
                        <xf:message level="modal">Neue Anforderung! Wird verworfen, wenn keine Bearbeitung! </xf:message>
                </xf:action>
                    
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get orders!</xf:message>
        </xf:submission>

        <xf:submission id="s-submit-order"
                				   ref="instance('i-orders')/*:Order[index('r-orders-id')]"
								   method="put"
								   replace="none">
			<xf:resource value="concat('{$order:restxq-orders}','?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit order!</xf:message>
        </xf:submission>

        <xf:bind ref="instance('i-orders')//*:detail/*:spec/*:begin/@value" type="xs:string" constraint="matches(.,'|h|m|nw|\dw|\dm|\d{{2}}-\d{{2}}-\d{{2}}')"/>    
        <xf:bind ref="instance('i-orders')//*:detail/*:spec/*:combination/@value" type="xs:string" constraint="matches(.,'\d')"/>    
        <xf:bind ref="instance('i-orders')//*:detail/*:spec/*:interdisciplinary/@value" type="xs:boolean"/>    
      
        <xf:instance  xmlns="" id="i-patient">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-patient"
                instance="i-patient"
				method="get"
				replace="instance">
			<xf:resource value="concat('{$order:restxq-patients}','/', $pid, '?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $uid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:send submission="s-get-orders"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get patient!</xf:message>
        </xf:submission>    

        <xf:instance xmlns="" id="i-groups">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-groups"
                	instance="i-groups"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$order:restxq-metis-roles}','?filter=service&amp;loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get groups!</xf:message>
        </xf:submission>
 
        <xf:instance xmlns="" id="i-users">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-users"
                	instance="i-users"
					method="get"
					replace="instance"
					resource="{$order:restxq-metis-users-ref}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{$uid}</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get users!</xf:message>
        </xf:submission>
   
        <xf:instance id="i-o-infos" xmlns="" src="{$order:order-infos-uri}"/>
        
        <xf:instance id="views">
            <data xmlns="">
                <OrdersToSelect/>
                <noOrders/>
            </data>
        </xf:instance>
   
        <xf:bind id="OrdersToSelect"
            ref="instance('views')/*:OrdersToSelect"
            relevant="count(instance('i-orders')/*:Order) &gt; 0"/>
         <xf:bind id="noOrders"
            ref="instance('views')/*:noOrders"
            relevant="count(instance('i-orders')/*:Order) = 0"/>
         
        <xf:instance id="i-memo">
            <data xmlns="">
                <lfdno>1</lfdno>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-memo')/*:lfdno" type="xs:string" constraint="matches(.,'\d')"/>
        
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-groups"/>
            <xf:send submission="s-get-users"/>
            <xf:send submission="s-get-patient"/>
        </xf:action>
    </xf:model>
</div>,
<div id="xforms">
    <h2>Anforderungen</h2>
    <h4><xf:output
            value="concat(instance('i-patient')/*:name[fhir:use/@value='official']/*:family/@value,', ',instance('i-patient')/*:name[fhir:use/@value='official']/*:given/@value,', *',instance('i-patient')/*:birthDate/@value)"/>
    </h4>
    <table>
        <tr>
            <td colspan="6">
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Zurück</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/nabu/index.html?action=listPatients"/> 
                </xf:trigger>
            </td>
<!--
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:hint>This button will save the order.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-order"/>
                    </xf:action>
                </xf:trigger>
            </td>
-->
        </tr>
        <tr>
            <td colspan="6">
                {order:mkOrderListGroup($uid,$unam)}
            </td>
        </tr>
    </table>
</div>
)
};
            
declare %private function order:mkOrderListGroup($uid, $uname)
{
    <xf:group>
        <xf:group id="orders" class="svFullGroup bordered">
            <xf:action ev:event="unload-subforms">
                <xf:message level="ephemeral">unloading subform...</xf:message>
                <xf:load show="none" targetid="orderSubForm"/>
            </xf:action>
            <xf:repeat id="r-orders-id" ref="instance('i-orders')/*:Order" appearance="compact" class="svRepeat">
                <xf:output value="format-date(xs:date(tokenize(./*:date/@value,'T')[1]),'[Y0000]-[M02]-[D02]')">
                    <xf:label class="svListHeader">Datum</xf:label>                        
                </xf:output>
                <xf:output ref="./*:subject/*:display/@value">
                    <xf:label class="svListHeader">Patient</xf:label>
                </xf:output>
                <xf:output value="choose((./*:reason/*:text/@value='Ambulanter Besuch'),string-join(./*:detail/*:info/@value,', '),./*:reason/*:text/@value)">
                    <xf:label class="svListHeader">Anlass</xf:label>                        
                </xf:output>
                <xf:output value="tokenize(./*:when/*:schedule/*:event/@value,'T')[1]">
                    <xf:label class="svListHeader">Fällig</xf:label>                        
                </xf:output>
                <xf:output value="concat(count(./*:detail/*:proposal/*:acq[@value='open']),' (',count(./*:detail),')')">
                    <xf:label class="svListHeader">Zahl</xf:label>                        
                </xf:output>
                <xf:output ref="*:when/*:code/*:text/@value">
                    <xf:label class="svListHeader">Wichtigkeit</xf:label>                        
                </xf:output>
            </xf:repeat>            
        </xf:group>
        <xf:group ref="instance('views')/noOrders">
            <xf:output value="'Keine offenen Anforderungen'"/>
        </xf:group>

        <xf:switch id="switch">
            <xf:case id="listOrders">
                {order:mkOrderListTriggerGroup($uid,$uname)}
            </xf:case>
            <xf:case id="editOrder">
                {order:mkEditGroup()}
            </xf:case>
        </xf:switch>
    </xf:group>
};

declare %private function order:mkOrderListTriggerGroup($uid,$uname)
{
        <xf:group class="svTriggerGroup">
        <table>
            <tr>
                <td>
                    <xf:trigger class="svSubTrigger" ref="instance('i-orders')/*:Order">
                        <xf:label>Edit</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue 
                                ref="instance('i-memo')/*:lfdno"
                                value="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'][index('r-details-id')]/*:spec/*:combination/@value"/>
                            <xf:toggle case="editOrder"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                    <xf:trigger class="svAddTrigger">
                        <xf:label>Neu</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert position="after" at="index('r-orders-id')"
                                    nodeset="instance('i-orders')/*:Order"
                                    context="instance('i-orders')"
                                    origin="instance('i-o-infos')/*:bricks/*:Order"/>
                        </xf:action>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:date/@value"             value="'{adjust-dateTime-to-timezone(current-dateTime(),())}'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:source/*:reference/@value" value="'{concat('metis/practitioners/',$uid)}'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:source/*:display/@value" value="'{$uname}'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:target/*:role/@value"    value="'spz-ateam'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:target/*:display/@value" value="'SPZ ATeam'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:subject/*:reference/@value"
                                    value="concat('nabu/patients/',instance('i-patient')/*:id/@value)"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:subject/*:display/@value"
                                    value="concat(instance('i-patient')/*:name[fhir:use/@value='official']/*:family/@value,', ',instance('i-patient')/*:name[fhir:use/@value='official']/*:given/@value,', *',instance('i-patient')/*:birthDate/@value)"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:extension[@url='#order-status']//*:text/@value" value="'zugewiesen'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:extension[@url='#order-status']//*:display/@value" value="'zugewiesen'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:extension[@url='#order-status']//*:code/@value" value="'requested'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[1]/@id" value="'1'"/>
                            <xf:toggle case="editOrder"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                    <xf:trigger class="svDelTrigger" ref="instance('i-orders')/*:Order">
                        <xf:label>Löschen</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:extension[@url='#order-status']//*:text/@value" value="'cancelled'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:extension[@url='#order-status']//*:display/@value" value="'cancelled'"/>
                            <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:extension[@url='#order-status']//*:code/@value" value="'cancelled'"/>
                            <xf:send submission="s-submit-order"/>
                            <xf:send submission="s-get-orders"/>
                            <xf:toggle case="listOrders"/>
                        </xf:action>
                    </xf:trigger>
                </td>
            </tr>
        </table>
        </xf:group>
};

declare %private function order:mkEditGroup()
{
    <xf:group id="editGroup" ref="instance('i-orders')/*:Order[index('r-orders-id')]">
        <table>
            <tr>
                <td>
                    <xf:trigger class="svUpdateMasterTrigger">
                        <xf:label>Abbrechen</xf:label>
<!--
                        <xf:send submission="s-get-orders"/>
-->
                        <xf:toggle case="listOrders"/>
                    </xf:trigger>
                </td>
                <td>
                    <xf:trigger class="svUpdateMasterTrigger">
                        <xf:label>Speichern</xf:label>
                        <xf:send submission="s-submit-order"/>
                        <xf:send submission="s-get-orders"/>
                        <xf:toggle case="listOrders"/>
                    </xf:trigger>
                </td>
            </tr>
        </table>
        <xf:group class="bordered">
            <xf:label>Edit Details</xf:label>
            <xf:group>
                <xf:select1 ref="./*:when/*:code/*:coding/*:code/@value" class="medium-input">
                    <xf:label>Wichtigkeit:</xf:label>
                    <xf:itemset nodeset="instance('i-o-infos')/when/code">
                        <xf:label ref="./@label"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:when/*:code/*:coding/*:display/@value" 
                            value="instance('i-o-infos')/when/code[@value=instance('i-orders')/*:Order[index('r-orders-id')]/*:when/*:code/*:coding/*:code/@value]/@label"/>
                        <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:when/*:code/*:text/@value"
                            value="instance('i-o-infos')/when/code[@value=instance('i-orders')/*:Order[index('r-orders-id')]/*:when/*:code/*:coding/*:code/@value]/@label"/>
                    </xf:action>
                </xf:select1>
                <xf:textarea ref="./*:reason/*:coding/*:display/@value" class="fullareashort">
                    <xf:label>Anlass:</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue  ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:reason/*:text/@value" value="instance('i-orders')/*:Order[index('r-orders-id')]/*:reason/*:coding/*:display/@value"/>
                    </xf:action>
                </xf:textarea>
                <br/>
                { order:mkClosedDetailList()}
                <br/>
                { order:mkOpenDetailList()}
            </xf:group>
        </xf:group>
    </xf:group>
};

declare %private function order:mkClosedDetailList()
{
    <xf:group id="closeddetails" ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value='closed']" class="svFullGroup">
        <xf:label>Bereits vereinbarte Leistungen</xf:label>
        <table>
            <thead>
                <tr>
                    <th class="svListHeader">LfdNo&#160;</th>
                    <th class="svListHeader">Leistung</th>
                    <th class="svListHeader">Erbringer</th>
                    <th class="svListHeader">Datum</th>
                    <th class="svListHeader">Dauer</th>
                    <th class="svListHeader">Notiz</th>
                </tr>
            </thead>
            <tbody id="r-closed-id" xf:repeat-nodeset="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value='closed']">
                <tr>
                    <td>
                        <xf:output ref="./*:spec/*:combination/@value" class="medium-input"/>
                    </td><td>
                        <xf:output ref="./*:actor/*:role/@value" class="medium-input"/>
                    </td><td>
                        <xf:output ref="./*:actor/*:display/@value" class=""/>
                    </td><td>
                        <xf:output ref="./*:spec/*:begin/@value" class="medium-input"/>
                    </td><td>
                        <xf:output ref="./*:spec/*:duration/@value" class="medium-input"/>
                    </td><td>
                        <xf:textarea ref="./*:info/@value" class="area-input"/>
                    </td>
                </tr>
            </tbody>
        </table>
    </xf:group>
};
declare %private function order:mkOpenDetailList()
{
    <xf:group id="services" class="svFullGroup bordered">
                    <xf:action ev:event="betterform-index-changed">
                        <xf:setvalue 
                            ref="instance('i-memo')/*:lfdno"
                            value="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'][index('r-details-id')]/*:spec/*:combination/@value"/>
                    </xf:action>
                    <xf:label>Angeforderte Leistungen</xf:label>
                    <table>
                        <thead>
                            <tr>
                                <th class="svListHeader">LfdNo&#160;</th>
                                <th class="svListHeader"><img src="resources/images/link.png" alt="Kombi"/></th>
                                <th class="svListHeader">Leistung</th>
                                <th class="svListHeader">Erbringer</th>
                                <th class="svListHeader">Wann?</th>
                                <th class="svListHeader">Dauer</th>
                                <th class="svListHeader">Notiz</th>
                            </tr>
                        </thead>
                        <tbody id="r-details-id" xf:repeat-nodeset="./*:detail[*:proposal/*:acq/@value!='closed']">
                            <tr>
                                <td>
                                    <xf:output ref="./*:spec/*:combination/@value"/>
                                </td>
                                <td>
                                    <xf:input ref="./*:spec/*:interdisciplinary/@value"/>
                                </td>
                                <td>
                                    <xf:select1 ref="./*:actor/*:role/@value" class="medium-select" incremental="true">
                                        <xf:itemset nodeset="instance('i-groups')/*:Group">
                                            <xf:label ref="./*:name/@value"/>
                                            <xf:value ref="./*:code/*:text/@value"/>
                                        </xf:itemset>
                                        <xf:hint>Bitte eine Funktion auswählen</xf:hint>
                                    </xf:select1>
                                </td>
                                <td>
                                    <xf:select1 ref="./*:actor/*:reference/@value" class="medium-select" incremental="true">
                                        <xf:itemset nodeset="instance('i-users')/*:user">
                                            <xf:label ref="./*:display/@value"/>
                                            <xf:value ref="./*:reference/@value"/>
                                        </xf:itemset>
                                        <xf:action ev:event="xforms-value-changed">
                                            <xf:setvalue
                                                ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'][index('r-details-id')]/*:actor/*:display/@value"
                                                value="instance('i-users')/*:user[./*:reference/@value=instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'][index('r-details-id')]/*:actor/*:reference/@value]/*:display/@value"/>
                                        </xf:action>
                                    </xf:select1>
                                </td>
                                <td>
                                    <xf:input ref="./*:spec/*:begin/@value" class="medium-input">
                                        <xf:hint>Zeitraum nach dem Muster '(|h|m|nW|\dw|\dm|\d{{2}}-\d{{2}}-\d{{2}})([|Mo|Di|Mi|Do|Fr|]*)([|:vm|:nm|]*)'</xf:hint>
                                    </xf:input>
                                </td>
                                <td>
                                    <xf:select1 ref="./*:spec/*:duration/@value" class="short-input">
                                        <xf:itemset nodeset="instance('i-o-infos')/*:duration/*:code">
                                            <xf:label ref="./@label"/>
                                            <xf:value ref="./@value"/>
                                        </xf:itemset>
                                        <xf:hint>Dauer ändern?</xf:hint>
                                    </xf:select1>
                                </td>
                                <td>
                                    <xf:textarea ref="./*:info/@value" class="area-input"/>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                    <table appearance="minimal" class="svTriggerGroup">
                        <tr>
                            <td>
                                <xf:trigger class="svAddTrigger">
                                    <xf:label>Neu</xf:label>
                                    <xf:insert ev:event="DOMActivate" position="after" at="index('r-details-id')"
                                            nodeset="./*:detail"
                                            context="."
                                            origin="instance('i-o-infos')/*:bricks/*:detail"/>
                                    <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'][index('r-details-id')]/@id"
                                        value="index('r-details-id')"/>
                                    <xf:setvalue ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'][index('r-details-id')]/*:spec/*:combination/@value" 
                                        value="index('r-details-id')"/>
                                    <xf:setvalue ref="instance('i-memo')/*:lfdno"
                                        value="index('r-details-id')"/>
                                </xf:trigger>
                            </td>
                            <td>
                                <xf:trigger class="svDelTrigger">
                                    <xf:label>Entfernen</xf:label>
                                    <xf:delete ev:event="DOMActivate" if="count(instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'])>1"
                                        ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'][index('r-details-id')]"/>
                                </xf:trigger>
                            </td>
                            <td>
                                <xf:input ref="instance('i-memo')/*:lfdno" class="tiny-input">
                                    <xf:label>LfdNo</xf:label>
                                    <xf:action ev:event="xforms-value-changed">
                                        <xf:setvalue 
                                            ref="instance('i-orders')/*:Order[index('r-orders-id')]/*:detail[*:proposal/*:acq/@value!='closed'][index('r-details-id')]/*:spec/*:combination/@value"
                                            value="instance('i-memo')/*:lfdno"/>
                                    </xf:action>
                                </xf:input>
                            </td>
                        </tr>
                    </table>
                </xf:group>
};