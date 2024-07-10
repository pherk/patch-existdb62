xquery version "3.0";

module namespace register="http://enahar.org/exist/apps/nabu/register";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace config  = "http://enahar.org/exist/apps/nabu/config" at "/db/apps/nabu/modules/config.xqm";

import module namespace r-practrole       = "http://enahar.org/exist/restxq/metis/practrole"
                          at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
(: 

import module namespace order       = "http://enahar.org/exist/apps/nabu/order"         at "../FHIR/Order/order.xqm";
:)
declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace bf = "http://betterform.sourceforge.net/xforms";
declare namespace bfc = "http://betterform.sourceforge.net/xforms/controls";

declare function register:review($node as node(), $model as map(*), $action, $id, $filter, $self, $status, $topic) {
let $server := request:get-header('host')
(:  let $log := util:log-app('DEBUG','nabu', ($server,"?", $action, ":", $id, ":", $filter, ":", $self, ":", $status, ":", $topic)) :)
return
    switch ($action)
        case "reviewTagged"    return  register:tagged($filter)
        default
            return register:tagged('')
};     


declare variable $register:restxq-conditions := "/exist/restxq/nabu/conditions";
declare variable $register:restxq-patients   := "/exist/restxq/nabu/patients";
declare variable $register:con-infos-uri     := "/exist/apps/nabu/FHIR/Condition/condition-infos.xml";


(:~
 : show reviews
 : 
 : @param $tag
 : @return html
 :)
declare function register:tagged($tag as xs:string) as item()*
{
    let $realm  := "kikl-spz"
    let $user   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $loguid := $user/fhir:id/@value/string()
    let $lognam := concat(string-join($user/fhir:name[fhir:use/@value='official']/fhir:family/@value, ' '),', ',$user/fhir:name[fhir:use/@value='official']/fhir:given/@value)

    let $now    := current-dateTime()
    return
(<div style="display:none;">

    <xf:model id="model">
        <xf:instance xmlns="" id="i-cons">
            <data/>
        </xf:instance>

        <xf:instance xmlns="" id="i-search-cons">
            <parameters>
                <start>1</start>
                <length>30</length>
                <subject></subject>
                <status>active</status>
                <verification>confirmed</verification>
                <category>finding</category>
                <code>MMC</code>
                <_sort>subject</_sort>
            </parameters>
        </xf:instance>

        <xf:submission id="s-get-cons"
                method="get" 
                ref="instance('i-search-cons')" 
                instance='i-cons' 
                replace="instance">
            <xf:resource value="concat('{$register:restxq-conditions}','?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Suche</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="ephemeral">Error: search</xf:message>
        </xf:submission>

        <xf:instance id="i-cond-infos" xmlns="" src="{$register:con-infos-uri}"/>

        <xf:instance id="views">
            <data xmlns="">
                <ListTooLong/>
                <PrevActive/>
                <NextActive/>
                <ConToSelect/>
            </data>
        </xf:instance>
        <xf:bind id="ListTooLong"
            ref="instance('views')/*:ListTooLong"
            readonly="instance('i-cons')/*:length &gt; instance('i-cons')/*:count"/>

        <xf:bind id="PrevActive"
            ref="instance('views')/*:PrevActive"
            readonly="instance('i-cons')/*:start = 1"/>
        <xf:bind id="NextActive"
            ref="instance('views')/*:NextActive"
            readonly="instance('i-cons')/*:start &gt; (instance('i-cons')/*:count - instance('i-cons')/*:length)"/>
        <xf:bind id="ConToSelect"
            ref="instance('views')/ConToSelect"
            relevant="count(instance('i-cons')/*:Condition) &gt; 0"/>
    
        <xf:instance id="iiter">
            <iiter xmlns=""></iiter>
        </xf:instance>
        
        <xf:instance xmlns="" id="i-memo">
            <parameters>
                <subject-uid></subject-uid>
                <subject-display></subject-display>
                <due></due>
                <due-display></due-display>
                <actor-uid></actor-uid>
                <actor-display></actor-display>
                <fafue-uid></fafue-uid>
                <fafue-display></fafue-display>
            </parameters>
        </xf:instance>        

        
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-cons"/>
        </xf:action>        
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
        <xf:input id="subject-uid"  ref="instance('i-search-cons')/*:subject">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:subject-uid" value="instance('i-search')/*:subject"/>
                <xf:send submission="s-get-cons"/>
            </xf:action>
        </xf:input>
        <xf:input id="subject-display" ref="instance('i-memo')/*:subject-display"/>
        <xf:input id="_sort"             ref="instance('i-search-cons')/*:_sort">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-memo')/*:_sort" value="instance('i-search')/*:_sort"/>
                <xf:send submission="s-get-cons"/>
            </xf:action>
        </xf:input>
        <xf:input id="due-display"     ref="instance('i-memo')/*:due-display"/>
        <xf:input id="fafue-subject" ref="instance('i-memo')/*:subject-uid"/>
        <xf:input id="fafue-uid"     ref="instance('i-memo')/*:fafue-uid">
        </xf:input>
        <xf:input id="fafue-display" ref="instance('i-memo')/*:fafue-display">
        </xf:input>
</div>
,<div class="col-md-12" padding-left="1px" padding-right="1px">
    <xf:switch>
        <xf:case id="listCases">
                <h4>Review</h4>

                { register:mkConditionListGroup() }
<!--
                { review:mkConditionListTriggerGroup() }
-->
        </xf:case>
<!--
        <xf:case id="editDetails">
                { detail:mkDetailListGroup() }
        </xf:case>
-->
    </xf:switch>
    </div>
)
};

declare %private function register:mkConditionListGroup()
{
    <div>
        <table class="">
            <tr>
                <td colspan="2">
                    <label for="subject-hack" class="xfLabel aDefault xfEnabled">Patient:</label>
                    <select class="review-select" name="subject-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="FHIR/review/subject.js"/>
                </td><td>
                    <xf:select1 ref="instance('i-search-cons')/*:_sort" class="medium-input">
                            <xf:label>Sortiert nach</xf:label>
                            <xf:itemset ref="instance('i-cond-infos')/sort/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                    </xf:select1>
                </td>
                <td>
                    <xf:select ref="instance('i-search-cons')/*:code" incremental="true" class="medium-input">
                            <xf:label>Tags</xf:label>
                            <xf:itemset ref="instance('i-cond-infos')/finding/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-cons"/>
                            </xf:action>
                    </xf:select>
                </td>
            </tr>
<!--
                <td colspan="2">
                    <label for="service-hack" class="xfLabel aDefault xfEnabled">Service:</label>
                    <select class="review-select" name="service-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="review/service.js"/>
                </td><td colspan="2">
                    <label for="actor-hack" class="xfLabel aDefault xfEnabled">Erbringer:</label>
                    <select class="review-select" name="actor-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="review/actor.js"/>
                </td>
            </tr>
-->
            <tr>
                <td>
                    <xf:trigger class="svFilterTrigger">
                        <xf:label>Patient</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('i-search')/*:subject" value="instance('i-memo')/*:subject-uid"/>
                            <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                            <xf:send submission="s-get-cons"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                        <xf:trigger class="svFilterTrigger">
                            <xf:label>Aktualisieren</xf:label>
                            <xf:action ev:event="DOMActivate">
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
                                <xf:setvalue ref="instance('i-search')/*:subject" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:subject-uid" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:subject-display" value="''"/>
                                <script type="text/javascript">
                                console.log('clear filters');
                                    $('.review-select[name="subject-hack"]').val('').trigger('change');
                                </script>
                            </xf:action>
                        </xf:trigger>
                    </td>
            </tr>
        </table>
        <xf:group id="reviews" class="svFullGroup">
<!--
                <script type="text/javascript">
                    var subject = $('#subject-uid-value');
                    var subjectname = $('#subject-display-value');
                    $('.review-select[name="subject-hack"]').append('&lt;option value="' + subject.val() + '"&gt;' + subjectname.val() + '&lt;/option&gt;').val(subject.val()).trigger('change');
                    var actor = $('#actor-uid-value');
                    var actorname = $('#actor-display-value');
                    $('.review-select[name="actor-hack"]').append('&lt;option value="' + actor.val() + '"&gt;' + actorname.val() + '&lt;/option&gt;').val(actor.val()).trigger('change');
                </script>
                <xf:send submission="s-get-schedules"/>
    Erbringer Fafue select2 updaten
-->
            <xf:repeat id="r-reviews-id" ref="instance('i-cons')/*:Condition" appearance="compact" class="svRepeat">
                <xf:output value="./*:code/*:coding[*:system/@value='#nabu-finding']/*:code/@value">
                    <xf:label class="svListHeader">Tag</xf:label>                        
                </xf:output>
                <xf:output ref="./*:subject/*:display/@value">
                    <xf:label class="svListHeader">Patient</xf:label>
                </xf:output>
                <xf:output value="./*:code/*:text/@value">
                    <xf:label class="svListHeader">Text</xf:label>                        
                </xf:output>
                <xf:output value="format-date(./*:assertedDate/@value,'[Y0001]-[M01]-[D01]')">
                    <xf:label class="svListHeader">Erfasst am</xf:label>                        
                </xf:output>
                <xf:output value="concat(substring(./*:clinicalStatus/@value,1,1),substring(./*:verificationStatus/@value,1,1))" class="tiny-input">
                    <xf:label class="svListHeader">Status</xf:label>                        
                </xf:output>
                <xf:output value="./*:note/@value">
                    <xf:label class="svListHeader">Notiz</xf:label>
                </xf:output>
            </xf:repeat>
            <table>
                <tr>
                    <td>
            <xf:group ref="instance('views')/*:ListTooLong">
                <xf:trigger ref="instance('views')/*:PrevActive">
                    <xf:label>&lt;&lt;</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-search-cons')/*:subject" value="''"/>
                        <xf:setvalue ref="instance('i-search-cons')/*:start" value="instance('i-search-cons')/*:start - instance('i-search-cons')/*:length"/>
                        <xf:send submission="s-get-cons"/>
                    </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance('i-cons')/*:start &gt; instance('i-cons')/*:count),instance('i-cons')/*:count,instance('i-cons')/*:start)"/>
                <xf:output value="' - '"/>
                <xf:output value="choose((instance('i-cons')/*:start + instance('i-cons')/*:length &gt; instance('i-cons')/*:count),instance('i-cons')/*:count,instance('i-cons')/*:start + instance('i-cons')/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance('i-cons')/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/*:NextActive">
                    <xf:label>&gt;&gt;</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-search-cons')/*:subject" value="''"/>
                        <xf:setvalue ref="instance('i-search-cons')/*:start" value="instance('i-search-cons')/*:start + instance('i-search-cons')/*:length"/>
                        <xf:send submission="s-get-cons"/>
                    </xf:action>
                </xf:trigger>
                        </xf:group>
                    </td>
            </tr>
        </table>
        </xf:group>
    </div>
};

declare %private function register:mkConditionListTriggerGroup()
{
    <table>
        <tr>
            <td>
                <xf:trigger class="svSubTrigger">
                    <xf:label>Edit</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-get-openapps"/>
                        <xf:toggle case="editDetails"/>
                    </xf:action>
                </xf:trigger>
            </td><td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>(Neu)</xf:label>
                    <xf:action ev:event="DOMActivate">
                    </xf:action>
                </xf:trigger>
            </td><td>
                <xf:trigger class="svDelTrigger" ref="instance('views')/ConditionsToSelect">
                    <xf:label>Löschen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:action>
                            <xf:setvalue
                                    ref="instance('i-all')/*:Condition[index('r-reviews-id')]/*:extension[@url='#review-status']/*:status//*:code/@value"
                                    value="'cancelled'"/>
                            <xf:setvalue
                                    ref="instance('i-all')/*:Condition[index('r-reviews-id')]/*:extension[@url='#review-status']/*:status//*:display/@value"
                                    value="'cancelled'"/>
                            <xf:setvalue
                                    ref="instance('i-all')/*:Condition[index('r-reviews-id')]/*:extension[@url='#review-status']/*:status/*:text/@value"
                                    value="'cancelled'"/>
                        </xf:action>
                        <xf:send submission="s-submit-review"/>
                        <xf:action if="count(instance('i-proposals')/*:proposal) > 0">
                            <xf:delete ref="instance('i-proposals')/*:proposal"/>
                            <xf:setvalue ref="instance('i-proposals')/*:index" value="'-1'"/>
                            <xf:setvalue ref="instance('i-proposals')/*:error" value="'Kein Vorschlag'"/>
                        </xf:action>
                        <xf:action>
                            <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                            <xf:send submission="s-search"/>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
};
