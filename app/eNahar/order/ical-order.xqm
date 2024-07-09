xquery version "3.0";

module namespace order = "http://enahar.org/exist/apps/enahar/order";

import module namespace config  = "http://enahar.org/exist/apps/enahar/config" at "../modules/config.xqm";

import module namespace r-practrole  = "http://enahar.org/exist/restxq/metis/practrole"
                     at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
import module namespace r-order = "http://enahar.org/exist/restxq/nabu/orders"   at "/db/apps/nabu/FHIR/Order/order-routes.xqm";
import module namespace detail  = "http://enahar.org/exist/apps/enahar/detail"   at "../order/detail.xqm";

declare namespace ev  = "http://www.w3.org/2001/xml-events";
declare namespace xf  = "http://www.w3.org/2002/xforms";
declare namespace bf = "http://betterform.sourceforge.net/xforms";
declare namespace bfc = "http://betterform.sourceforge.net/xforms/controls";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

(: 
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
            <tbody>{order:ordersToRows($uid,$roles,$myOrders)}</tbody>
            <script type="text/javascript" defer="defer" src="resources/scripts/listOrders.js"/>
        </table>
        <p><br/>
                <a href="index.html?action=newOrder">Neue Anforderung</a>
        </p>
        <div>
            <h4>Details</h4>
        </div>
:)
declare %private function order:ordersToRows($uid as xs:string, $roles, $orders)
{
    let $lll := util:log-system-out($orders)
    for $o in $orders/fhir:Order
    let $oid  := $o/id/string()
    let $when := if ($o/fhir:when) then
            $o/fhir:when/fhir:code
        else if ($o/fhir:when/fhir:event/@value!='') then
            format-date(xs:date($o/fhir:when/fhir:event/@value/string()),"[D01]-[M01]-[Y02]")
        else ""
    let $isMe   := $uid = $o/fhir:source/fhir:reference/@value
    let $isSelf := $uid = $o/fhir:target/fhir:reference/@value
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

declare variable $order:cal-infos-uri       := "/exist/apps/eNahar/cal/cal-infos.xml";
declare variable $order:restxq-orders       := "/exist/restxq/nabu/orders";
declare variable $order:order-infos-uri     := "/exist/apps/nabu/FHIR/Order/order-infos.xml";
declare variable $order:restxq-encounters := "/exist/restxq/nabu/encounters";
declare variable $order:restxq-services     := "/exist/restxq/metis/roles?filter=service";
declare variable $order:restxq-patients     := "/exist/restxq/nabu/patients";
declare variable $order:restxq-metis-users-ref  := "/exist/restxq/metis/PractitionerRole/users?_format=ref";

(:~
 : show orders
 : 
 : @param $status (open, all, send)
 : @return html
 :)
declare function order:listOrders() as item()*
{
    let $realm  := "kikl-spz"
    let $logu   := r-practrole:userByAlias(xdb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid  := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $loggrp := $logu/fhir:specialty//fhir:coding[fhir:system/@value="http://hl7.org/fhir/vs/practitioner-specialty"]/fhir:code/@value/string()
    let $roles  := r-practrole:rolesByID($prid, $realm, $uid, $unam)

    let $now    := current-dateTime()
    return
(<div style="display:none;">

    <xf:model id="model">
        <xf:instance xmlns="" id="i-all">
            <orders/>
        </xf:instance>
      
        <xf:bind ref="instance('i-all')/*:Order/*:detail">
            <xf:bind ref="./*:process/@value"                  type="xs:boolean"/>
            <xf:bind ref="./*:actor/*:required/@value"         type="xs:boolean"/>
            <xf:bind ref="./*:spec/*:combination/@value"       type="xs:string" constraint="matches(.,'\d')"/>    
            <xf:bind ref="./*:spec/*:interdisciplinary/@value" type="xs:boolean"/>
        </xf:bind>

<!--
        <xf:bind ref="instance('i-all')/*:Order/*:detail//*:spec/*:begin/@value"         type="xs:string" constraint="matches(.,'|h|m|nW|\dW|\dM|\d{{2}}-\d{{2}}-\d{{2}}')"/>    
-->    
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>10</length>
                <subject></subject>
                <source></source>
                <target></target>
                <reason>appointment</reason>
                <status>active</status>
                <actor></actor>
                <service></service>
                <schedule></schedule>
            <!--
                <rangeStart>1994-06-01T08:00:00</rangeStart>
                <rangeEnd>2021-04-01T19:00:00</rangeEnd>
            -->
                <tag>spz</tag>
                <_sort>date:asc</_sort>
                <acq>active</acq>
                <ro>false</ro>
            </parameters>
        </xf:instance>
        <xf:bind ref="instance('i-search')/*:ro" type="xs:boolean"/>

        <xf:submission id="s-search"
                method="get" 
                ref="instance('i-search')" 
                instance='i-all' 
                replace="instance">
            <xf:resource value="concat('{$order:restxq-orders}','?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:dispatch name="updateSubject" targetid="model"/>
                <xf:dispatch name="updateFaFue" targetid="model"/>
                <xf:message level="ephemeral">Suche</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Error: search</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-order"
                method="put" 
                ref="instance('i-all')/*:Order[index('r-orders-id')]"
                instance='i-all'
                replace="none">
            <xf:resource value="concat('{$order:restxq-orders}','?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Order submitted</xf:message>
                <xf:action if="string-length(instance('i-all')/*:Order[index('r-orders-id')]/*:basedOn/*:reference/@value)>0">
                    <xf:send submission="s-update-careplan-action-outcome"/>
                </xf:action>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Error: submit Order</xf:message>
        </xf:submission>
           <xf:submission id="s-update-careplan-action-outcome"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/careplans/',substring-after(instance('i-all')/*:Order[index('r-orders-id')]/*:basedOn/*:reference/@value,'nabu/careplans/'),'/actions/',instance('i-all')/*:Order[index('r-orders-id')]/*:id/@value,'?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),choose(instance('i-memo')/*:progress='','',concat('&amp;progress=',encode-for-uri(instance('i-memo')/*:progress))),choose(instance('i-memo')/*:outcome='','',concat('&amp;outcome=',encode-for-uri(instance('i-memo')/*:outcome))))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update careplan action status!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-enc"
                method="post" 
                ref="instance('i-all')/*:Order[index('r-orders-id')]"
                instance='i-all'
                replace="none">
            <xf:resource value="concat('/exist/restxq/nabu/order2encs','?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Encounter submitted</xf:message>
                <xf:action if="string-length(instance('i-all')/*:Order[index('r-orders-id')]/*:basedOn/*:reference/@value)>0">
                    <xf:send submission="s-update-careplan-action-outcome"/>
                </xf:action>
                <xf:dispatch name="resetGlobalProposals" targetid="model"/>
                <xf:action>
                    <xf:message level="ephemeral">Leeren, Aktualisieren</xf:message>
                    <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                    <xf:setvalue ref="instance('i-search')/*:subject" value="''"/>
                    <!--
                    <xf:setvalue ref="instance('i-search')/*:service" value="''"/>
                    <xf:setvalue ref="instance('i-search')/*:actor" value="''"/>
                    -->
                    <xf:setvalue ref="instance('i-memo')/*:subject-uid" value="''"/>
                    <xf:setvalue ref="instance('i-memo')/*:subject-display" value="''"/>
                    <xf:setvalue ref="instance('i-memo')/*:progress" value="''"/>
                    <xf:setvalue ref="instance('i-memo')/*:outcome" value="''"/>
                    <script type="text/javascript">
                                console.log('clear filters');
                                    $('.order-select[name="subject-hack"]').val('').trigger('change');
                                    $('.order-select[name="fafue-hack"]').val('').trigger('change');
                                    $('.order-select[name="schedule-hack"]').val('').trigger('change');
                                    $('.order-select[name="ownersched-hack"]').val('').trigger('change');
                    </script>
                    <!--
                                    $('.order-select[name="service-hack"]').val('').trigger('change');
                                    $('.order-select[name="actor-hack"]').val('').trigger('change');
                    -->
                </xf:action>
                <xf:send submission="s-search"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Error: making encounter</xf:message>
        </xf:submission>   

        <xf:instance id="i-eocs">
            <data xmls=""></data>
        </xf:instance>
        <xf:submission id="s-get-eocs"
                	instance="i-eocs"
					method="get"
					replace="instance">
            <xf:resource value="concat('/exist/restxq/nabu/eocs?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;patient=',substring-after(instance('i-all')/*:Order[index('r-orders-id')]/*:subject/*:reference/@value,'nabu/patients/'),'&amp;status=planned&amp;status=active&amp;status=finished')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('i-memo')/*:eocs-id" value="count(instance('i-eocs')/*:EpisodeOfCare[*:status/@value=('planned','active')]/preceding-sibling::EpisodeOfCare)+1"/>
                <xf:action if="string-length(instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-memo')/*:eocs-id)]/*:careManager/*:reference/@value)&gt;0">
                    <xf:setvalue
                                ref="instance('i-all')/*:Order[index('r-orders-id')]/*:appointmentType/*:coding/*:code/@value"
                                value="'FOLLOWUP'"/>
                    <xf:setvalue
                                ref="instance('i-all')/*:Order[index('r-orders-id')]/*:appointmentType/*:coding/*:display/@value"
                                value="'WV'"/>
                </xf:action>
                <xf:action if="string-length(instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-memo')/*:eocs-id)]/*:careManager/*:reference/@value)=0">
                    <xf:setvalue
                                ref="instance('i-all')/*:Order[index('r-orders-id')]/*:appointmentType/*:coding/*:code/@value"
                                value="'NOCM'"/>
                    <xf:setvalue
                                ref="instance('i-all')/*:Order[index('r-orders-id')]/*:appointmentType/*:coding/*:display/@value"
                                value="'kein FaFü'"/>
                </xf:action>
                <xf:message level="ephemeral">EoCs loaded</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot load EoCs!</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-planned-encs">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-planned-encs"
                	instance="i-planned-encs"
					method="get"
					replace="instance">
			<xf:resource value="concat('/exist/restxq/nabu/encountersBySubject/',substring-after(instance('i-all')/*:Order[index('r-orders-id')]/*:subject/*:reference/@value,'nabu/patients/'),'?status=planned&amp;status=tentative&amp;status=cancelled&amp;loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get encs!</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-proposals">
            <proposals>
                <index>-1</index>
                <count>1</count>
                <error>Kein Vorschlag</error>
            </proposals>
        </xf:instance>
<!--        
        <xf:bind id="selectedProposal" ref="instance('i-proposals')/proposal[@id=instance('i-search')/did]/detail"/>

  <xf:bind nodeset="instance('criteria_data')/criteria/set/root" calculate="instance
('choices')/choice[. = instance('criteria_data')/criteria/set/criterion]/../root">      
        -->
        <xf:submission id="s-get-proposals"
                method="post" 
                instance='i-proposals' 
                ref="instance('i-all')/*:Order[index('r-orders-id')]"
                replace="instance">
            <xf:resource value="concat(bf:appContext('contextroot'),'/restxq/enahar/proposals','?realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;mode=',encode-for-uri(instance('i-memo')/*:search-mode))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-done" level="ephemeral">Vorschläge gesucht.</xf:message>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Error: Suchen.</xf:message>
        </xf:submission>  
        <xf:instance xmlns="" id="i-groups">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-groups"
                	instance="i-groups"
					method="get"
					replace="instance"
					resource="{$order:restxq-services}">
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
           
        <xf:instance id="i-calInfos" xmlns="" src="{$order:cal-infos-uri}"/>
        <xf:instance id="i-o-infos"  xmlns="" src="{$order:order-infos-uri}"/>
        
        <xf:instance id="i-login">
            <data xmlns="">
                <loguid>{$uid}</loguid>
                <lognam>{$unam}</lognam>
                <loggrp>{$loggrp}</loggrp>
                <realm>{$realm}</realm>
                <today>{tokenize(current-date(),'\+')[1]}</today>
            </data>
        </xf:instance>
        
        <xf:instance id="views">
            <data xmlns="">
                <ListTooLong/>
                <OrderPrevActive/>
                <OrderNextActive/>
                <OrdersToSelect/>
                <OrderNew/>
                <DetailsOpen/>
                <ProposalsToSelect/>
                <NoProposals/>
                <ProposalPrevActive/>
                <ProposalNextActive/>
                <ProposalAccepted/>
            </data>
        </xf:instance>
        <xf:bind id="ListTooLong"
            ref="instance('views')/ListTooLong"
            readonly="instance('i-all')/length &gt; instance('i-all')/count"/>

        <xf:bind id="OrderPrevActive"
            ref="instance('views')/OrderPrevActive"
            readonly="instance('i-all')/start = 1"/>
        <xf:bind id="OrderNextActive"
            ref="instance('views')/OrderNextActive"
            readonly="instance('i-all')/start &gt; (instance('i-all')/count - instance('i-all')/length)"/>

<!--        
        <xf:bind id="TriggerSaveActive"
            ref="instance('views')/TriggerSaveActive"
            readonly="instance('i-all')/*:Order/id"/>
-->        
        <xf:bind id="OrdersToSelect"
            ref="instance('views')/OrdersToSelect"
            relevant="count(instance('i-all')/*:Order) &gt; 0"/>
        <xf:bind id="OrderNew"
            ref="instance('views')/OrderNew"
            relevant="count(instance('i-all')/*:Order) = 0"/>
        <xf:bind id="DetailsOpen"
            ref="instance('views')/*:DetailsOpen"
            relevant="count(instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')])>0"/>
        <xf:bind id="ProposalsToSelect"
            ref="instance('views')/ProposalsToSelect"
            relevant="count(instance('i-proposals')/*:proposal) &gt; 0"/>
        <xf:bind id="NoProposals"
            ref="instance('views')/NoProposals"
            relevant="count(instance('i-proposals')/*:proposal) = 0 and instance('i-proposals')/*:index = 1"/>
        <xf:bind id="ProposalPrevActive"
            ref="instance('views')/ProposalPrevActive"
            readonly="instance('i-proposals')/*:index = 1"/>
        <xf:bind id="ProposalNextActive"
            ref="instance('views')/ProposalNextActive"
            readonly="instance('i-proposals')/*:index = instance('i-proposals')/*:count"/>   
        <xf:bind id="ProposalAccepted"
            ref="instance('views')/ProposalAccepted"
            relevant="count(instance('i-all')/*:Order[index('r-orders-id')]/*:detail/*:status[@value = ('tentative','accepted')]) &gt; 0"/>
        <xf:instance id="iiter">
            <iiter xmlns=""></iiter>
        </xf:instance>
        <xf:instance xmlns="" id="i-memo">
            <parameters>
                <subject-uid></subject-uid>
                <subject-display></subject-display>
                <service-code></service-code>
                <due></due>
                <due-display></due-display>
                <actor-uid></actor-uid>
                <actor-display></actor-display>
                <fafue-uid></fafue-uid>
                <fafue-display></fafue-display>
                <eocs-id>1</eocs-id>
                <schedule-uid></schedule-uid>
                <schedule-display></schedule-display>
                <ownersched></ownersched>
                <ownersched-display></ownersched-display>
                <_sort>date:asc</_sort>
                <lfdno>1</lfdno>
                <progress/>
                <outcome/>
                <search-mode>normal</search-mode>
            </parameters>
        </xf:instance>        
        <xf:bind ref="instance('i-memo')/*:lfdno" type="xs:string" constraint="matches(.,'\d')"/>
        
        <xf:action ev:event="resetDetailProposals" if="count(instance('i-all')/*:Order[index('r-orders-id')]/*:detail/*:status[@value=('accepted','tentative')])>0">
            <xf:setvalue ref="instance('iiter')" value="'1'"/>
            <xf:action while="instance('iiter') &lt;= count(instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('tentative','accepted')])">
                <xf:setvalue ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('tentative','accepted')][xs:int(instance('iiter'))]/*:proposal/*:start/@value" value="''"/>
                <xf:setvalue ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('tentative','accepted')][xs:int(instance('iiter'))]/*:proposal/*:end/@value" value="''"/>
                <xf:setvalue ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('tentative','accepted')][xs:int(instance('iiter'))]/*:status/@value" value="'active'"/>
                <xf:setvalue ref="instance('iiter')" value="instance('iiter') + 1"/>
            </xf:action>
        </xf:action>
        <xf:action ev:event="resetGlobalProposals" if="count(instance('i-proposals')/*:proposal) > 0">
            <xf:delete ref="instance('i-proposals')/*:proposal"/>
            <xf:setvalue ref="instance('i-proposals')/*:index" value="'-1'"/>
            <xf:setvalue ref="instance('i-proposals')/*:error" value="'Kein Vorschlag'"/>
        </xf:action>
        <xf:action ev:event="updateSubject" if="count(instance('i-all')/*:Order) > 0">
            <xf:setvalue ref="instance('i-memo')/*:subject-uid"
                value="substring-after(instance('i-all')/*:Order[index('r-orders-id')]/*:subject/*:reference/@value,'nabu/patients/')"/>
            <xf:setvalue ref="instance('i-memo')/*:subject-display"
                value="instance('i-all')/*:Order[index('r-orders-id')]/*:subject/*:display/@value"/>
        </xf:action>
        <xf:action ev:event="updateFaFue" if="count(instance('i-all')/*:Order) > 0">
            <xf:setvalue ref="instance('i-memo')/*:service-code"
                value="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:role/@value"/>
            <xf:setvalue ref="instance('i-memo')/*:fafue-uid"
                value="substring-after(instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:reference/@value,'metis/practitioners/')"/>
            <xf:setvalue ref="instance('i-memo')/*:fafue-display"
                value="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:display/@value"/>
            <xf:setvalue 
                ref="instance('i-memo')/*:lfdno"
                value="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:spec/*:combination/@value"/>
        </xf:action>        
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-groups"/>
            <xf:send submission="s-get-users"/>
            <xf:send submission="s-search"/>
        </xf:action>        
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
        <xf:input id="subject-uid"  ref="instance('i-search')/*:subject">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:subject-uid" value="instance('i-search')/*:subject"/>
            </xf:action>
        </xf:input>
        <xf:input id="subject-display" ref="instance('i-memo')/*:subject-display"/>
        <xf:input id="_sort"             ref="instance('i-search')/*:_sort">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:_sort" value="instance('i-search')/*:_sort"/>
            </xf:action>
        </xf:input>
        <xf:input id="due-display"     ref="instance('i-memo')/*:due-display"/>
        <xf:input id="service-code"    ref="instance('i-search')/*:service">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:service-code"
                    value="instance('i-search')/*:service"/>
            </xf:action>
        </xf:input>
        <xf:input id="actor-uid"     ref="instance('i-search')/*:actor">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:actor-uid"
                    value="instance('i-search')/*:actor"/>
                <xf:setvalue ref="instance('i-search')/*:service" value="''"/>
            </xf:action>
        </xf:input>
        <xf:input id="mactor-uid"    ref="instance('i-memo')/*:actor-uid"/>
        <xf:input id="actor-display" ref="instance('i-memo')/*:actor-display"/>
        <xf:input id="actor-service" ref="instance('i-memo')/*:service-code"/>
        <xf:input id="fafue-subject" ref="instance('i-memo')/*:subject-uid"/>
        <xf:input id="schedule-uid"     ref="instance('i-memo')/*:schedule-uid">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-search')/*:schedule"
                    value="instance('i-memo')/*:schedule-uid"/>
            </xf:action>
        </xf:input>
        <xf:input id="schedule-display" ref="instance('i-memo')/*:schedule-display"/>
        <xf:input id="fafue-uid"     ref="instance('i-memo')/*:fafue-uid">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue 
                    ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:reference/@value"
                    value="choose(instance('i-memo')/*:fafue-uid='','',concat('metis/practitioners/',instance('i-memo')/*:fafue-uid))"/>
            <!--
                <xf:setvalue
                    ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:display/@value"
                    value="instance('i-memo')/*:fafue-display"/>
            -->
            </xf:action>
        </xf:input>
        <xf:input id="fafue-display" ref="instance('i-memo')/*:fafue-display">
            <xf:action ev:event="xforms-value-changed">
            <!--
                <xf:setvalue 
                    ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:reference/@value"
                    value="choose(instance('i-memo')/*:fafue-uid='','',concat('metis/practitioners/',instance('i-memo')/*:fafue-uid))"/>
            -->
                <xf:setvalue
                    ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:actor/*:display/@value"
                    value="instance('i-memo')/*:fafue-display"/>
            </xf:action>
        </xf:input>
        <xf:input id="ownersched"  ref="instance('i-memo')/*:ownersched"/>
        <xf:input id="ownersched-display"  ref="instance('i-memo')/*:ownersched-display">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue
                    ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:schedule/*:reference/@value"
                    value="concat('enahar/schedules/',instance('i-memo')/*:ownersched)"/>
                <xf:setvalue 
                    ref="instance('i-all')/*:Order[index('r-orders-id')]/*:detail[*:status/@value=('active','tentative','accepted')][index('r-details-id')]/*:schedule/*:display/@value"
                                value="instance('i-memo')/*:ownersched-display"/>
            </xf:action>
        </xf:input>
</div>
,<div class="col-md-12" padding-left="1px" padding-right="1px">
    <xf:group id="dashboard">
        <xf:switch>
            <xf:case id="listOrders">
                    <h4>Anforderungen - Termine</h4>
                    { order:mkOrderListGroup() }
                    { order:mkOrderListTriggerGroup() }
            </xf:case>
            <xf:case id="editDetails">
                    { detail:mkDetailListGroup() }
            </xf:case>
            <xf:case id="showCalendar">
            </xf:case>
        </xf:switch>
    </xf:group>
    </div>
,   <hr></hr>
,	<div class="col-md-12" padding-left="1px" padding-right="1px">
<!--
                <div id="loading" style="display:none;">loading...</div>
                <div id="calendar"/>
-->
                <div data-template="app:auslastung"/>
</div>
)
};

declare %private function order:mkOrderListGroup()
{
    <div>
        <table class="">
            <thead>
                <tr>
                    <th colspan="2">Patient</th>
                    <th>Sortiert nach</th>
                    <th colspan="2">Service</th>
                    <th colspan="2">Erbringer</th>
                    <th colspan="2">Kalender</th>
                </tr>
            </thead>
            <tbody>
            <tr>
                <td colspan="2">
                    <select class="order-select" name="subject-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="order/subject.js"/>
                </td><td>
                    <xf:select1 ref="instance('i-search')/*:_sort" class="medium-input">
                            <xf:itemset ref="instance('i-o-infos')/sort/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                    </xf:select1>
<!--
                </td><td>
                    <label for="due-hack" class="xfLabel aDefault xfEnabled">Fällig:</label>
                    <select class="order-select" name="due-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="order/due.js"/>
-->
                </td><td colspan="2">
                    <select class="order-select" name="service-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="order/service.js"/>
                </td><td colspan="2">
                    <select class="order-select" name="actor-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="order/actor.js"/>
                </td><td colspan="2">
                    <select class="order-select" name="schedule-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="order/schedule.js"/>
                </td>

            </tr>
            <tr>
                    <td>
                        <xf:trigger class="svFilterTrigger">
                            <xf:label>Patient</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:dispatch name="resetGlobalProposals" targetid="model"/>
                                <xf:setvalue ref="instance('i-search')/*:subject" value="instance('i-memo')/*:subject-uid"/>
                                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                                <xf:send submission="s-search"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger class="svFilterTrigger">
                            <xf:label>Aktualisieren</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:dispatch name="resetGlobalProposals" targetid="model"/>
                                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                                <xf:send submission="s-search"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger class="svFilterTrigger">
                            <xf:label>Leeren</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                                <xf:setvalue ref="instance('i-search')/*:service" value="''"/>
                                <xf:setvalue ref="instance('i-search')/*:subject" value="''"/>
                                <xf:setvalue ref="instance('i-search')/*:actor" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:subject-uid" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:subject-display" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:schedule-uid" value="''"/>
                                <script type="text/javascript">
                                console.log('clear filters');
                                    $('.order-select[name="subject-hack"]').val('').trigger('change');
                                    $('.order-select[name="service-hack"]').val('').trigger('change');
                                    $('.order-select[name="actor-hack"]').val('').trigger('change');
                                    $('.order-select[name="fafue-hack"]').val('').trigger('change');
                                    $('.order-select[name="schedule-hack"]').val('').trigger('change');
                                    $('.order-select[name="ownersched-hack"]').val('').trigger('change');
                                </script>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <strong>Reorder'd only</strong>
                        <xf:input ref="instance('i-search')/*:ro" class="">
                            <xf:label></xf:label>
                        </xf:input>
                    </td>
            </tr>
            </tbody>
        </table>
        <xf:group id="orders" class="svFullGroup">
            <xf:action ev:event="betterform-index-changed">  
                <xf:dispatch name="updateSubject" targetid="model"/>
                <xf:dispatch name="resetGlobalProposals" targetid="model"/>
                <xf:dispatch name="updateFaFue" targetid="model"/>
            </xf:action>
<!--
                <script type="text/javascript">
                    var subject = $('#subject-uid-value');
                    var subjectname = $('#subject-display-value');
                    $('.order-select[name="subject-hack"]').append('&lt;option value="' + subject.val() + '"&gt;' + subjectname.val() + '&lt;/option&gt;').val(subject.val()).trigger('change');
                    var actor = $('#actor-uid-value');
                    var actorname = $('#actor-display-value');
                    $('.order-select[name="actor-hack"]').append('&lt;option value="' + actor.val() + '"&gt;' + actorname.val() + '&lt;/option&gt;').val(actor.val()).trigger('change');
                </script>
                <xf:send submission="s-get-schedules"/>
    Erbringer Fafue select2 updaten
-->
            <xf:repeat id="r-orders-id" ref="instance('i-all')/*:Order" appearance="compact" class="svRepeat">
                <xf:output value="format-date(xs:date(tokenize(./*:date/@value,'T')[1]),'[Y0001]-[M01]-[D01]')">
                    <xf:label class="svListHeader">Datum</xf:label>                        
                </xf:output>
                <xf:output ref="./*:subject/*:display/@value">
                    <xf:label class="svListHeader">Patient</xf:label>
                </xf:output>
                <xf:output value="concat(./*:description/@value,':',string-join(./*:detail/*:info/@value,', '))">
                    <xf:label class="svListHeader">Anlass:Info</xf:label>                        
                </xf:output>
                <xf:output value="tokenize(./*:when/*:schedule/*:event/@value,'T')[1]">
                    <xf:label class="svListHeader">Fälligkeit</xf:label>                        
                </xf:output>
                <xf:output value="choose((./*:detail/*:spec/*:begin/@value=''),'',tokenize(./*:detail/*:spec/*:begin/@value,'T')[1])">
                    <xf:label class="svListHeader">Wunsch</xf:label>                        
                </xf:output>
                <xf:output value="choose(./*:when/*:code/*:coding/*:code/@value=('urgent','high'),./*:when/*:code/*:text/@value,'')">
                    <xf:label class="svListHeader">Prio</xf:label>                        
                </xf:output>
                <xf:output value="concat(count(./*:detail/*:status[@value=('active','tentative','accepted')]),' (',count(./*:detail),')')">
                    <xf:label class="svListHeader">Zahl</xf:label>                        
                </xf:output>
                <xf:output value="''">
                    <xf:label class="svListHeader"></xf:label>                        
                </xf:output>
            </xf:repeat>
            <table>
                <tr>
                    <td>
            <xf:group ref="instance('views')/ListTooLong">
                <xf:trigger ref="instance('views')/OrderPrevActive">
                    <xf:label>&lt;&lt;</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="resetGlobalProposals" targetid="model"/>
                        <xf:setvalue ref="instance('i-search')/*:subject" value="''"/>
                        <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start - instance('i-search')/*:length"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance()/*:start &gt; instance()/*:count),instance()/*:count,instance()/*:start)"/>
                <xf:output value="' - '"/>
                <xf:output value="choose((instance()/*:start + instance()/*:length &gt; instance()/*:count),instance()/*:count,instance()/*:start + instance()/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance()/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/OrderNextActive">
                    <xf:label>&gt;&gt;</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="resetGlobalProposals" targetid="model"/>
                        <xf:setvalue ref="instance('i-search')/*:subject" value="''"/>
                        <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start + instance('i-search')/*:length"/>
                        <xf:send submission="s-search"/>
                    </xf:action>
                </xf:trigger>
                        </xf:group>
                    </td>
            </tr>
        </table>
        </xf:group>
    </div> 
};

declare %private function order:mkOrderListTriggerGroup()
{
    <table>
        <tr>
            <td>
                <xf:trigger class="svSubTrigger">
                    <xf:label>Edit</xf:label>
                    <xf:action ev:event="DOMActivate">
<!-- TODO -->
                        <xf:send submission="s-get-eocs"/>
                        <xf:action if="not(instance('i-eocs')/*:EpisodeOfCare/*:status/@value=('active','planned'))">
                            <xf:message level="modal">Der Patient wird zur Zeit nicht aktiv betreut!</xf:message>
                        </xf:action>
                        <xf:action if="instance('i-eocs')/*:EpisodeOfCare/*:status/@value=('active','planned')">
                            <xf:send submission="s-get-planned-encs"/>
                            <xf:toggle case="editDetails"/>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
            </td><td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>(Neu)</xf:label>
                    <xf:action ev:event="DOMActivate">
                    </xf:action>
                </xf:trigger>
            </td><td>
                <xf:trigger class="svDelTrigger" ref="instance('views')/OrdersToSelect">
                    <xf:label>Löschen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:action>
                            <xf:setvalue
                                    ref="instance('i-all')/*:Order[index('r-orders-id')]/*:status/@value"
                                    value="'cancelled'"/>
                            <xf:setvalue
                                    ref="instance('i-memo')/*:outcome"
                                    value="'gelöscht via eNahar'"/>
                        </xf:action>
                        <xf:send submission="s-submit-order"/>
                        <xf:dispatch name="resetGlobalProposals" targetid="model"/>
                        <xf:action>
                            <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                            <xf:send submission="s-search"/>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
            </td>
            <td colspan="1">
                <xf:trigger class="svSaveTrigger">
                    <xf:label>./. Patient</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:load show="new">
                            <xf:resource value="concat('/exist/apps/nabu/index.html?action=listPatients&amp;id=',substring-after(instance('i-all')/*:Order[index('r-orders-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
                        </xf:load>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
};
