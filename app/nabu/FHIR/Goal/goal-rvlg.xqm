xquery version "3.1";

module namespace goalrvlg="http://enahar.org/exist/apps/nabu/goalrvlg";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace  bf = "http://betterform.sourceforge.net/xforms";
declare namespace bfc = "http://betterform.sourceforge.net/xforms/controls";

declare function goalrvlg:mkGoalListGroup()
{
    <div>
        <table class="">
            <tr>
                <td colspan="2">
                    <label for="subject-hack" class="xfLabel aDefault xfEnabled">Patient:</label>
                    <select class="review-select" name="subject-hack">
                        <option></option>
                    </select>
                    <br/>
                    <label for="service-hack" class="xfLabel aDefault xfEnabled">Service:</label>
                    <select class="review-select" name="service-hack">
                        <option></option>
                    </select>
                    <br/>
                    <label for="actor-hack" class="xfLabel aDefault xfEnabled">Erbringer:</label>
                    <select class="review-select" name="actor-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="FHIR/review/actor.js"/>
                    <script type="text/javascript" defer="defer" src="FHIR/review/subject.js"/>
                    <script type="text/javascript" defer="defer" src="FHIR/review/service.js"/>
                </td>
                <td>
                    <strong>Sortierung</strong>
                    <xf:select ref="instance('i-search-goals')/*:_sort" incremental="true" class="medium-select">
                            <xf:itemset ref="instance('i-goal-infos')/sort/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                    </xf:select>
                </td>
                <td>
                    <strong>Kategory</strong>
                    <xf:select ref="instance('i-search-goals')/*:category" incremental="true" class="medium-select">
                            <xf:itemset ref="instance('i-goal-infos')/category/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                    </xf:select>
                </td>
                <td>
                    <strong>Gruppe</strong>
                    <xf:select ref="instance('i-search-goals')/*:description" incremental="true" class="long-select">
                            <xf:itemset ref="instance('i-condition-infos')/finding/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                    </xf:select>
                </td>
                <td>
                    <strong>Status</strong>
                    <xf:select ref="instance('i-search-goals')/*:lifecycleStatus" incremental="true" class="medium-select">
                            <xf:itemset ref="instance('i-goal-infos')/lifecycleStatus/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                    </xf:select>
                </td>
                <td>
                    <strong>Progress</strong>
                    <xf:select ref="instance('i-search-goals')/*:achievementStatus" incremental="true" class="medium-select">
                            <xf:itemset ref="instance('i-goal-infos')/achievementStatus/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                    </xf:select>
                </td>
            </tr>
            <tr>
                <td colspan="2">

                </td>
            </tr>
            <tr>
                <td>
                    <xf:trigger class="svFilterTrigger">
                        <xf:label>Patient</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('i-search')/*:subject" value="instance('i-memo')/*:subject-uid"/>
                            <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                            <xf:send submission="s-get-goals"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                        <xf:trigger class="svFilterTrigger">
                            <xf:label>Aktualisieren</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger class="svFilterTrigger">
                            <xf:label>Leeren</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-search-goals')/*:start" value="'1'"/>
                                <xf:setvalue ref="instance('i-search-goals')/*:subject" value="''"/>
                                <xf:setvalue ref="instance('i-search-goals')/*:expressedBy" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:subject-uid" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:subject-display" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:actor-uid" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:actor-display" value="''"/>
                                <script type="text/javascript">
                                console.log('clear filters');
                                    $('.review-select[name="subject-hack"]').val('').trigger('change');
                                    $('.review-select[name="actor-hack"]').val('').trigger('change');
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
            <xf:repeat id="r-goals-id" ref="instance('i-goals')/*:Goal" appearance="compact" class="svRepeat">
                <xf:output ref="./*:subject/*:display/@value">
                    <xf:label class="svListHeader">Patient</xf:label>
                </xf:output>
                <xf:output ref="./*:description/*:text/@value">
                    <xf:label class="svListHeader">Beschreibung</xf:label>                        
                </xf:output>
                <xf:output value="substring(./*:startDate/@value,1,10)">
                    <xf:label class="svListHeader">Erfasst am</xf:label>                        
                </xf:output>
<!--
                <xf:output ref="./*:achievementStatus/*:coding/*:code/@value">
                    <xf:label class="svListHeader">Progress</xf:label>                        
                </xf:output>
-->
                <xf:output ref="./*:note/*:text/@value">
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
                        <xf:setvalue ref="instance('i-search-goals')/*:subject" value="''"/>
                        <xf:setvalue ref="instance('i-search-goals')/*:start" value="instance('i-search-goals')/*:start - instance('i-search-goals')/*:length"/>
                        <xf:send submission="s-get-goals"/>
                    </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance('i-goals')/*:start &gt; instance('i-goals')/*:count),instance('i-goals')/*:count,instance('i-goals')/*:start)"/>
                <xf:output value="' - '"/>
                <xf:output value="choose((instance('i-goals')/*:start + instance('i-goals')/*:length &gt; instance('i-goals')/*:count),instance('i-goals')/*:count,instance('i-goals')/*:start + instance('i-goals')/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance('i-goals')/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/*:NextActive">
                    <xf:label>&gt;&gt;</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-search-goals')/*:subject" value="''"/>
                        <xf:setvalue ref="instance('i-search-goals')/*:start" value="instance('i-search-goals')/*:start + instance('i-search-goals')/*:length"/>
                        <xf:send submission="s-get-goals"/>
                    </xf:action>
                </xf:trigger>
                        </xf:group>
                    </td>
            </tr>
        </table>
        </xf:group>
    </div>
};

declare function goalrvlg:mkGoalRegListGroup()
{
    <div>
        <table class="">
            <tr>
                <td colspan="2">
                    <label for="subject-hack" class="xfLabel aDefault xfEnabled">Patient:</label>
                    <select class="review-select" name="subject-hack">
                        <option></option>
                    </select>
                    <br/>

                    <script type="text/javascript" defer="defer" src="FHIR/review/subject.js"/>
                </td>
                <td>
                    <strong>Sortierung</strong>
                    <xf:select ref="instance('i-search-goals')/*:_sort" incremental="true" class="medium-select">
                            <xf:itemset ref="instance('i-goal-infos')/sort/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                    </xf:select>
                </td>
                <td>
                    <strong>Gruppe</strong>
                    <xf:select ref="instance('i-search-goals')/*:description" incremental="true" class="long-select">
                            <xf:itemset ref="instance('i-condition-infos')/finding/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                    </xf:select>
                </td>
                <td>
                    <strong>Status</strong>
                    <xf:select ref="instance('i-search-goals')/*:registrationStatus" incremental="true" class="medium-select">
                            <xf:itemset ref="instance('i-goal-infos')/registrationStatus/code">
                                <xf:label ref="./@label-de"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                    </xf:select>
                </td>
            </tr>
            <tr>
                <td colspan="2">

                </td>
            </tr>
            <tr>
                <td>
                    <xf:trigger class="svFilterTrigger">
                        <xf:label>Patient</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('i-search')/*:subject" value="instance('i-memo')/*:subject-uid"/>
                            <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                            <xf:send submission="s-get-goals"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                <td>
                        <xf:trigger class="svFilterTrigger">
                            <xf:label>Aktualisieren</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                                <xf:send submission="s-get-goals"/>
                            </xf:action>
                        </xf:trigger>
                    </td>
                    <td>
                        <xf:trigger class="svFilterTrigger">
                            <xf:label>Leeren</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-search-goals')/*:start" value="'1'"/>
                                <xf:setvalue ref="instance('i-search-goals')/*:subject" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:subject-uid" value="''"/>
                                <xf:setvalue ref="instance('i-memo')/*:subject-display" value="''"/>
                                <script type="text/javascript">
                                console.log('clear filters');
                                    $('.review-select[name="subject-hack"]').val('').trigger('change');
                                    $('.review-select[name="actor-hack"]').val('').trigger('change');
                                </script>
                            </xf:action>
                        </xf:trigger>
                    </td>
            </tr>
        </table>
        <xf:group id="reviews" class="svFullGroup">
        <xf:action ev:event="xforms-value-changed">
            <xf:setvalue ref="instance('i-cc')/isDirty" value="'false'"/>
        </xf:action>
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
            <xf:repeat id="r-goals-id" ref="instance('i-goals')/*:Goal" appearance="compact" class="svRepeat">
                <xf:output ref="./*:subject/*:display/@value">
                    <xf:label class="svListHeader">Patient</xf:label>
                </xf:output>
                <xf:output ref="./*:description/*:text/@value">
                    <xf:label class="svListHeader">Beschreibung</xf:label>                        
                </xf:output>
                <xf:output value="substring(./*:startDate/@value,1,10)">
                    <xf:label class="svListHeader">Erfasst am</xf:label>                        
                </xf:output>
<!--
                <xf:output value="./*:achievementStatus/*:coding/*:code/@value">
                    <xf:label class="svListHeader">Progress</xf:label>                        
                </xf:output>
-->
                <xf:output ref="./*:note/*:text/@value">
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
                        <xf:setvalue ref="instance('i-search-goals')/*:subject" value="''"/>
                        <xf:setvalue ref="instance('i-search-goals')/*:start" value="instance('i-search-goals')/*:start - instance('i-search-goals')/*:length"/>
                        <xf:send submission="s-get-goals"/>
                    </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance('i-goals')/*:start &gt; instance('i-goals')/*:count),instance('i-goals')/*:count,instance('i-goals')/*:start)"/>
                <xf:output value="' - '"/>
                <xf:output value="choose((instance('i-goals')/*:start + instance('i-goals')/*:length &gt; instance('i-goals')/*:count),instance('i-goals')/*:count,instance('i-goals')/*:start + instance('i-goals')/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance('i-goals')/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/*:NextActive">
                    <xf:label>&gt;&gt;</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-search-goals')/*:subject" value="''"/>
                        <xf:setvalue ref="instance('i-search-goals')/*:start" value="instance('i-search-goals')/*:start + instance('i-search-goals')/*:length"/>
                        <xf:send submission="s-get-goals"/>
                    </xf:action>
                </xf:trigger>
                        </xf:group>
                    </td>
            </tr>
        </table>
        </xf:group>
    </div>
};
