xquery version "3.0";

module namespace goalrv="http://enahar.org/exist/apps/nabu/goalrv";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace config  = "http://enahar.org/exist/apps/nabu/config" at "/db/apps/nabu/modules/config.xqm";

import module namespace r-practrole       = "http://enahar.org/exist/restxq/metis/practrole"
                          at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
(: 

import module namespace order       = "http://enahar.org/exist/apps/nabu/order"         at "../FHIR/Order/order.xqm";
:)
import module namespace goalrvlg =  "http://enahar.org/exist/apps/nabu/goalrvlg"    at "goal-rvlg.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace  bf = "http://betterform.sourceforge.net/xforms";
declare namespace bfc = "http://betterform.sourceforge.net/xforms/controls";


declare variable $goalrv:restxq-goals      := "/exist/restxq/nabu/goals";
declare variable $goalrv:restxq-conditions := "/exist/restxq/nabu/conditions";
declare variable $goalrv:restxq-patients   := "/exist/restxq/nabu/patients";
declare variable $goalrv:goal-infos-uri    := "/exist/apps/nabu/FHIR/Goal/goal-infos.xml";
declare variable $goalrv:condition-infos-uri := "/exist/apps/nabu/FHIR/Condition/condition-infos.xml";

declare function goalrv:showFunctions($uid)
{
    <ul>
        <li>
            <a href="index.html?action=listGoals&amp;id={$uid}">Ziele</a>
        </li>
    </ul>
};


(:~
 : show reviews
 : 
 : @param $id
 : @param $filter
 : @return html
 :)
declare function goalrv:review(
          $id as xs:string*
        , $topic as xs:string*
        , $filter as xs:string*
        ) as item()*
{
    let $id := ($id,"")[1]
    let $topic  := ($topic,"")[1]
    let $filter := ($filter,"")[1]
    let $realm  := "kikl-spzn"
    let $logu   := r-practrole:userByAlias(xmldb:get-current-user())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid   := substring-after($uref,'metis/practitioners/')
    let $unam  := $logu/fhir:practitioner/fhir:display/@value/string()
    let $roles  := r-practrole:rolesByID($prid, $realm, $uid, $unam)
    let $perms := r-practrole:perms($prid)/fhir:perm
    let $org   := concat('metis/organizations/',$realm)
    let $isAdmin := $uid=('u-admin','u-duechtingc','u-pmh')
    let $today := adjust-dateTime-to-timezone(current-dateTime(),())
    let $hasUA   := $isAdmin or 'perm_reviewGoals' = $perms
    let $hasRG   := 'perm_reviewRegGoals' = $perms
    let $itsMe := $uid =$id
    return
(<div style="display:none;">

    <xf:model id="model">
        <xf:instance xmlns="" id="i-goals">
            <data/>
        </xf:instance>

        <xf:instance xmlns="" id="i-search-goals">
            <parameters>
                <start>1</start>
                <length>15</length>
                <subject></subject>
                <expressedBy>{$id}</expressedBy>
                <lifecycleStatus>active-only</lifecycleStatus>
                <achievementStatus></achievementStatus>
                <category></category>
                <description></description>
                <_sort>startDate</_sort>
            </parameters>
        </xf:instance>

        <xf:submission id="s-get-goals"
                method="get" 
                ref="instance('i-search-goals')" 
                instance='i-goals' 
                replace="instance">
            <xf:resource value="concat('{$goalrv:restxq-goals}','?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Suche</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Error: search</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-goal"
                method="put" 
                ref="instance('i-goals')/*:Goal[index('r-goals-id')]" 
                replace="none">
            <xf:resource value="concat('{$goalrv:restxq-goals}','?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Goal submitted</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Error: submit Goal</xf:message>
        </xf:submission>

        <xf:instance id="i-goal-infos" xmlns="" src="{$goalrv:goal-infos-uri}"/>
        <xf:instance id="i-condition-infos" xmlns="" src="{$goalrv:condition-infos-uri}"/>

        <xf:instance id="views">
            <data xmlns="">
                <ListTooLong/>
                <PrevActive/>
                <NextActive/>
                <GoalsToSelect/>
            </data>
        </xf:instance>
        <xf:bind id="ListTooLong"
            ref="instance('views')/*:ListTooLong"
            readonly="instance('i-goals')/*:length &gt; instance('i-goals')/*:count"/>

        <xf:bind id="PrevActive"
            ref="instance('views')/*:PrevActive"
            readonly="instance('i-goals')/*:start = 1"/>
        <xf:bind id="NextActive"
            ref="instance('views')/*:NextActive"
            readonly="instance('i-goals')/*:start &gt; (instance('i-goals')/*:count - instance('i-goals')/*:length)"/>
        <xf:bind id="GoalsToSelect"
            ref="instance('views')/GoalsToSelect"
            relevant="count(instance('i-goals')/*:Goal) &gt; 0"/>
    
        <xf:instance id="iiter">
            <iiter xmlns=""></iiter>
        </xf:instance>
        
        <xf:instance xmlns="" id="i-memo">
            <parameters>
                <subject-uid></subject-uid>
                <subject-display></subject-display>
                <app-group></app-group>
                <service-display></service-display>
                <actor-uid>{$id}</actor-uid>
                <actor-display></actor-display>
            </parameters>
        </xf:instance>        

        
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-goals"/>
        </xf:action>        
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
        <xf:input id="subject-uid"  ref="instance('i-search-goals')/*:subject">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:subject-uid" value="instance('i-search-goals')/*:subject"/>
                <xf:send submission="s-get-goals"/>
            </xf:action>
        </xf:input>
        <xf:input id="subject-display" ref="instance('i-memo')/*:subject-display"/>
        <xf:input id="_sort"             ref="instance('i-search-goals')/*:_sort">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:_sort" value="instance('i-search-goals')/*:_sort"/>
                <xf:send submission="s-get-goals"/>
            </xf:action>
        </xf:input>
        <xf:input id="actor-uid"     ref="instance('i-search-goals')/*:expressedBy"/>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:actor-uid" value="instance('i-search-goals')/*:expressedBy"/>
                <xf:send submission="s-get-goals"/>
            </xf:action>
        <xf:input id="actor-display" ref="instance('i-memo')/*:actor-display"/>
        <xf:input id="app-group"     ref="instance('i-memo')/*:app-group">
        </xf:input>
        <xf:input id="service-display" ref="instance('i-memo')/*:service-display">
        </xf:input>
        <xf:input id="onset" ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:target/*:dueDate/@value" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'">
            <xf:label>Fälligkeit:</xf:label>
            <xf:alert>a valid date is required</xf:alert>
        </xf:input>
</div>
,<div class="col-md-12" padding-left="1px" padding-right="1px">
    <h4>Goal-Review</h4>
    { if ($hasUA or $itsMe)
      then
        <div>
        {
          (
              goalrvlg:mkGoalListGroup()
            , goalrv:mkGoalDetails($uid,$unam)
          )
        }
        </div>
      else
        <h4>Sie sind nicht authorisiert (Admin)</h4>
    }
</div>
)
};

declare %private function goalrv:mkGoalDetails($uid, $unam)
{
<xf:switch>
    <xf:case id="info">
    <table>
        <tr>
            <td>
                <xf:trigger class="svSubTrigger">
                    <xf:label>Edit</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:toggle case="edit"/>
                    </xf:action>
                </xf:trigger>
            </td><td>
                <xf:trigger class="svDelTrigger">
                    <xf:label>Löschen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:action>
                            <xf:setvalue
                                    ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:statusDate/@value"
                                    value="current-dateTime()"/>
                            <xf:setvalue
                                    ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:statusReason/@value"
                                    value="'byReview'"/>
                            <xf:setvalue
                                    ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:lifecycleStatus/@value"
                                    value="'cancelled'"/>
                        </xf:action>
                        <xf:send submission="s-submit-goal"/>
                    </xf:action>
                </xf:trigger>
            </td>
                <td>
                    <xf:trigger ref="instance('i-goals')/*:Goal[index('r-goals-id')]" class="svSaveTrigger">
                    <xf:label>./. Patient</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:load show="new">
                                <xf:resource value="concat('/exist/apps/nabu/index.html?action=listPatients&amp;id=',substring-after(instance('i-goals')/*:Goal[index('r-goals-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
                            </xf:load>
                        </xf:action>
                    </xf:trigger>
                </td>
        </tr>
    </table>
    { goalrv:info() }
    </xf:case>
    <xf:case id="edit">
    <table>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue
                            ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:statusDate/@value"
                            value="current-dateTime()"/>
                        <xf:setvalue
                            ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:statusReason/@value"
                            value="'byReview'"/>
                        <xf:send submission="s-submit-goal"/>
                    </xf:action>
                </xf:trigger>
            </td><td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Abbrechen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:toggle case="info"/>
                    </xf:action>
                </xf:trigger>
            </td>
                <td>
                    <xf:trigger ref="instance('i-goals')/*:Goal[index('r-goals-id')]" class="svSaveTrigger">
                    <xf:label>./. Patient</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:load show="new">
                                <xf:resource value="concat('/exist/apps/nabu/index.html?action=listPatients&amp;id=',substring-after(instance('i-goals')/*:Goal[index('r-goals-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
                            </xf:load>
                        </xf:action>
                    </xf:trigger>
                </td>
        </tr>
        </table>
        { goalrv:edit($uid,$unam) }
    </xf:case>
</xf:switch>

};

declare %private function goalrv:info()
{
<xf:group ref="instance('i-goals')/*:Goal[index('r-goals-id')]">
    <hr/>
    <table>
        <tr>
            <td><strong>Patient</strong></td>
            <td><xf:output ref="./*:subject/*:display/@value"/></td>
            <td><strong>Priority</strong></td>
            <td><xf:output ref="./*:priority/*:coding[*:system/@value='http://hl7.org/fhir/ValueSet/goal-priority']/*:display/@value"/></td>
        </tr>
        <tr>
            <td><strong>Kategory</strong></td>
            <td><xf:output ref="./*:category/*:coding[*:system/@value='http://hl7.org/fhir/ValueSet/goal-category']/*:display/@value"/></td>
            <td><strong>Erfasst am</strong></td>
            <td><xf:output value="substring(./*:startDate/@value,1,10)"/></td>
        </tr>
        <tr>
            <td><strong>Pat-Gruppe</strong></td>
            <td><xf:output ref="*:description/*:coding[./*:system/@value='http://eNahar.org/nabu/extension#nabu-finding']/*:display/@value"/></td>
            <td><strong>Progress</strong></td>
            <td><xf:output ref="./*:achievementStatus/*:coding/*:display/@value"/></td>
        </tr>
        <tr>
            <td><strong>Beschreibung</strong></td>
            <td colspan="3"><xf:textarea ref="./*:description/*:text/@value" class="fullareashort"/></td>
        </tr>
        <tr> 
            <td><strong>Notizen</strong></td>
            <td colspan="3"><xf:repeat ref="./*:note" class="svRepeat">
                    <xf:textarea ref="./*:text/@value" class="fullareashort"/>
                </xf:repeat>
            </td>
        </tr>
        <tr>
            <td><strong>Status</strong></td>
            <td><xf:output ref="./*:lifecycleStatus/@value"/></td>
            <td><xf:output value="substring(./*:statusDate/@value,1,10)"/></td>
            <td><xf:output ref="./*:statusReason/@value"/></td>
        </tr>
    </table>
</xf:group>
};

declare %private function goalrv:edit($uid, $unam)
{
    <xf:group ref="instance('i-goals')/*:Goal[index('r-goals-id')]">
    <xf:action ev:event="xforms-value-changed">
        <xf:setvalue ref="instance('i-cc')/*:isDirty" value="'true'"/>
    </xf:action>
        <hr/>
    <table>
        <tr>
            <td><strong>Patient</strong></td>
            <td colspan="3"><xf:output ref="./*:subject/*:display/@value"/></td>
        </tr>
        <tr>
            <td><strong>Kategorie</strong></td>
            <td>
        <xf:select1 ref="./*:category/*:coding[*:system/@value='http://hl7.org/fhir/ValueSet/goal-category']/*:code/@value">
            <xf:itemset nodeset="instance('i-goal-infos')/*:category/*:code">
                <xf:label ref="./@label-de"/>
                <xf:value ref="./@value"/>
            </xf:itemset>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue 
                    ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:category/*:coding[./*:system/@value='http://hl7.org/fhir/ValueSet/goal-category']/*:display/@value"
                    value="instance('i-goal-infos')/*:category/*:code[@value=instance('i-goals')/*:Goal[index('r-goals-id')]/*:category/*:coding[./*:system/@value='http://hl7.org/fhir/ValueSet/goal-category']/*:code/@value]/@label-de"/>
            </xf:action>
        </xf:select1>
            </td>
            <td><strong>Priority</strong></td>
            <td>
                <xf:select1 ref="./*:priority/*:coding[*:system/@value='http://hl7.org/fhir/ValueSet/goal-priority']/*:code/@value">
                    <xf:itemset nodeset="instance('i-goal-infos')/*:priority/*:code">
                        <xf:label ref="./@label-de"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue 
                    ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:priority/*:coding[./*:system/@value='http://hl7.org/fhir/ValueSet/goal-priority']/*:display/@value"
                    value="instance('i-goal-infos')/*:priority/*:code[@value=instance('i-goals')/*:Goal[index('r-goals-id')]/*:priority/*:coding[./*:system/@value='http://hl7.org/fhir/ValueSet/goal-priority']/*:code/@value]/@label-de"/>
            </xf:action>
                </xf:select1>
            </td>
            <td>
                <xf:group class="form-group form-inline">
                    <xf:label>Fällig am:   </xf:label>
                    <div class="input-group date col-sm-2" id="cond-onset" data-date-format="yyyy-mm-dd" data-date-language="de">
                        <input type="text" class="form-control" id="cond-onset-input"/>
                        <div class="input-group-addon">
                            <span class="glyphicon glyphicon-th"/>
                        </div>
                    </div>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td><strong>Pat-Gruppe</strong></td>
            <td>
                <xf:select1 ref="./*:description/*:coding[*:system/@value='http://eNahar.org/nabu/extension#nabu-finding']/*:code/@value">
                    <xf:itemset nodeset="instance('i-condition-infos')/*:finding/*:code">
                    <xf:label ref="./@label-de"/>
                    <xf:value ref="./@value"/>
                </xf:itemset>
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue
                        ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:description/*:coding[./*:system/@value='http://eNahar.org/nabu/extension#nabu-finding']/*:display/@value"
                        value="instance('i-condition-infos')/*:finding/*:code[@value=instance('i-goals')/*:Goal[index('r-goals-id')]/*:description/*:coding[./*:system/@value='http://eNahar.org/nabu/extension#nabu-finding']/*:code/@value]/@label-de"/>
                </xf:action>
            </xf:select1>
            </td>
            <td><strong>Status</strong></td>
            <td>
                <xf:select1 ref="./*:lifecycleStatus/@value">
                    <xf:itemset nodeset="instance('i-goal-infos')/*:lifecycleStatus/*:code">
                        <xf:label ref="./@label-de"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                </xf:select1>
            </td>
            <td>
                <xf:select1 ref="./*:achievementStatus/*:coding[*:system/@value='http://hl7.org/fhir/ValueSet/goal-achievement']/*:code/@value">
                    <xf:itemset nodeset="instance('i-goal-infos')/*:achievementStatus/*:code">
                        <xf:label ref="./@label-de"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue
                        ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:achievementStatus/*:coding[./*:system/@value='http://hl7.org/fhir/ValueSet/goal-achievement']/*:display/@value"
                        value="instance('i-condition-infos')/*:achievementStatus/*:code[@value=instance('i-goals')/*:Goal[index('r-goals-id')]/*:achievementStatus/*:coding[./*:system/@value='http://hl7.org/fhir/ValueSet/goal-achievement']/*:code/@value]/@label-de"/>
                </xf:action>
                </xf:select1>
            </td>
        </tr>
        <tr>
            <td><strong>Beschreibung</strong></td>
            <td colspan="3">
                <xf:textarea ref="./*:description/*:text/@value" class="fullareashort"></xf:textarea>
            </td>
        </tr>
        <tr>
            <td><strong>Notizen</strong></td>
            <td colspan="3">
                <xf:repeat ref="./*:note" class="svRepeat">
                    <xf:textarea ref="./*:text/@value" class="fullareashort">
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue 
                            ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:note[index('r-notes-id')]/*:authorReference/*:reference/@value"
                            value="'{$uid}'"/>
                        <xf:setvalue
                            ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:note[index('r-notes-id')]/*:authorReference/*:display/@value"
                            value="'{$unam}'"/>
                        <xf:setvalue
                            ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:note[index('r-notes-id')]/*:time/@value"
                            value="current-dateTime()"/>
                    </xf:action>            
                    </xf:textarea>
                </xf:repeat>
            </td>
        </tr>
    </table>
        <table>
            <tr>
                <td>
                    <xf:trigger ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:achievementStatus/*:coding/*:code[@value='in-progress']" class="svUpdateMasterTrigger">
                    <xf:label>Review</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert nodeset="./*:note" context="." origin="instance('i-goal-infos')/*:bricks/*:note"/>
                            <xf:setvalue 
                                ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:note[last()]/*:authorReference/*:reference/@value"
                                value="concat('metis/practitioners/', instance('i-login')/*:loguid)"/>
                            <xf:setvalue
                                ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:note[last()]/*:authorReference/*:display/@value"
                                value="instance('i-login')/*:lognam"/>
                            <xf:setvalue
                                ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:note[last()]/*:time/@value"
                                value="current-dateTime()"/>
                            <xf:setvalue
                                ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:note[last()]/*:text/@value"
                                value=""/>
                            <xf:setvalue
                                ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:expressedBy/*:reference/@value"
                                value="concat('metis/practitioners/', instance('i-login')/*:loguid)"/>
                            <xf:setvalue
                                ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:expressedBy/*:display/@value"
                                value="instance('i-login')/*:lognam"/>
                            <xf:setvalue
                                ref="instance('i-goals')/*:Goal[index('r-goals-id')]/*:statusReason/@value"
                                value="'byReview'"/>
                            <xf:send submission="s-submit-goal"/>
                        </xf:action>
                    </xf:trigger>
                </td>
            </tr>
        </table>
</xf:group>
};