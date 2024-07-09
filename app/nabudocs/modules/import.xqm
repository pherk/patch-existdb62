xquery version "3.1";

module namespace import = "http://enahar.org/exist/apps/nabudocs/import";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $import:regexp-dateline := "(\d+)\.[ ]?((\d+)\.|([A-Z][a-zä]+))[ ]?(\d+)([ /]*[^ /]*)";

declare function import:invaliddate($loguid,$lognam,$realm,$path)
{
    let $author-name := $lognam
    let $author-uid := $loguid
return
(<div style="display:none;">
    <xf:model id="m-letters" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance id="i-errors">
            <data xmlns="">
            </data>
        </xf:instance>
    </xf:model>
</div>
,<div>
    
</div>
)
};
(: 
<nodate>
    <letter path="Befunde12/Arzt/Kleist-Retzow/SchekaGiovanni0212.xml" y="2012">
        <possible-date>Köln, 15.08.2012 </possible-date>
        <possible-date-first-sentence>wir berichten Ihnen überdie ambulanteWiedervorstellung des o. g. Patienten am 14.02.2012 in unserem Sozialpädiatrischen Zentrum sowie über eine Vorstellung in der orthopädischen Sprechstunde am 02.05.2012.</possible-date-first-sentence>
    </letter>
    <letter path="Befunde16/Physiotherapie/OswaldKlara.xml" y="2016"/>
</nodate>

:)

declare function import:nodate($loguid,$lognam,$realm,$path)
{
     let $author-name := $lognam
     let $author-uid := $loguid
    let $data := doc("/db/apps/nabu/statistics/eval/composition-nodates.xml")
return
(<div style="display:none;">
    <xf:model id="m-letters" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance id="i-errors">
            <data xmlns="">
            {$data}
            </data>
        </xf:instance>
    </xf:model>
</div>
,<div>
    
</div>
)
};

declare function import:errors($loguid,$lognam,$realm,$path)
{
     let $author-name := $lognam
     let $author-uid := $loguid
     let $today := tokenize(current-date(),'\+')[1]
return
(<div style="display:none;">
    <xf:model id="m-letters" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance id="i-errors">
            <data xmlns="">
            </data>
        </xf:instance>
        <xf:submission  id="s-get-errors"
                method="get"
                instance="i-errors"
                replace="instance"
                ref="instance('i-search')">
            <xf:resource value="'/exist/restxq/nabudocs/errors'"/>
            <xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:dispatch name="set-current-error" targetid="m-letters"/>
            </xf:action>
        </xf:submission>
        <xf:submission id="s-delete-error"
                instance="i-errors"
                method="get"
                replace="none"
                ref="instance('i-search')">
            <xf:resource value="concat('/exist/restxq/nabudocs/delete-error/',instance('i-errors')/*:error[index('r-errors-id')]/@id)"/>
            <xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:delete ref="instance('i-errors')/*:error" at="index('r-errors-id')"/>
                <xf:dispatch name="set-current-error" targetid="m-letters"/>
            </xf:action>
            <xf:action ev:event="xforms-submit-error">
                <xf:message level="ephemeral">cannot delete error</xf:message>
            </xf:action>
        </xf:submission>
        <xf:submission id="s-reimport-errors"
                instance="i-errors"
                method="get"
                replace="instance"
                ref="instance('i-search')">
            <xf:resource value="'/exist/restxq/nabudocs/reimport-errors'"/>
            <xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:dispatch name="set-current-error" targetid="m-letters"/>
                <xf:message level="ephemeral">ReImport done</xf:message>
            </xf:action>
            <xf:action ev:event="xforms-submit-error">
                <xf:message level="ephemeral">cannot reimport</xf:message>
            </xf:action>
        </xf:submission>
        <xf:action ev:event="set-current-error">
            <xf:delete ref="instance('i-error')/*:error"/>
            <xf:insert 
                    ref="instance('i-error')/*:error"
                    context="instance('i-error')"
                    origin="instance('i-errors')/*:error[index('r-errors-id')]"/>
            <xf:setvalue ref="instance('i-letter')/*:file" value="instance('i-error')/*:error/*:file"/>
            <xf:setvalue ref="instance('i-letter')/*:path" value="instance('i-error')/*:error/*:collection"/>
            <script type="text/javascript">
                console.log('clear inputs');
                $('.patient-select[name="subject1-hack"]').val('').trigger('change');
                $('.recipient-select[name="recipient-hack"]').val('').trigger('change');
            </script>
            <xf:send submission="s-get-raw"/>
            <xf:setvalue ref="instance('i-letter')/*:date" value="'{$today}'"/>
<!--
            <xf:setfocus control="r-errors-id"/>
-->
        </xf:action>       
        <xf:instance id="i-error">
            <data xmlns=""/>
        </xf:instance>
        
        <xf:instance id="i-search">
            <data xmlns="">
                <base>/db/apps/nabuCom/errors</base>
                <path>{$path}</path>
                <match>birthDate</match>
            </data>
        </xf:instance>
        <xf:instance id="i-letter">
            <data xmlns="">
                <path>{$path}</path>
                <file/>
                <subject-uid/>
                <subject-display/>
                <recipient-uid/>
                <recipient-display/>
                <author-uid>{$author-uid}</author-uid>
                <author-display>{$author-name}</author-display>
                <date>{$today}</date>
            </data>
        </xf:instance>
        <xf:submission id="s-get-raw"
                method="get"
                replace="embedHTML"
                targetid="letterpane"
                ref="instance('i-letter')">
            <xf:resource value="concat('/exist/restxq/nabudocs/letters?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
        </xf:submission>
        <xf:submission id="s-import-letter"
                instance="i-letter"
                method="get"
                replace="none"
                ref="instance('i-letter')">
            <xf:resource value="concat('/exist/restxq/nabudocs/import?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:send submission="s-delete-error"/>
                <xf:setvalue ref="instance('i-search')/*:date" value="{$today}"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot import letter</xf:message>
        </xf:submission>

        <xf:instance id ="i-login" xmlns="">
            <data>
                <realm>{$realm}</realm>
                <loguid>{$loguid}</loguid>
                <lognam>{$lognam}</lognam>
            </data>
        </xf:instance>
        <xf:instance id="views">
            <data xmlns="">
                <NoPatient/>
                <NoPractitioner/>
                <NoAuthor/>
                <PatientSelected/>
                <PractitionerSelected/>
                <AuthorSelected/>
            </data>
        </xf:instance>

        <xf:bind ref="instance('views')/*:NoPatient"
            relevant="instance('i-letter')/*:subject-uid=''"/>
        <xf:bind ref="instance('views')/*:PatientSelected"
            relevant="instance('i-letter')/*:subject-uid!=''"/>
        <xf:bind ref="instance('views')/*:NoPractitioner"
            relevant="instance('i-letter')/*:recipient-uid=''"/>
         <xf:bind ref="instance('views')/*:PractitionerSelected"
            relevant="instance('i-letter')/*:recipient-uid!=''"/>
        <xf:bind ref="instance('views')/*:NoAuthor"
            relevant="instance('i-letter')/*:author-uid=''"/>
         <xf:bind ref="instance('views')/*:AuthorSelected"
            relevant="instance('i-letter')/*:author-uid!=''"/>
            
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-errors"/>
        </xf:action>
        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-raw"/>
        </xf:action>
    </xf:model>
    <xf:input id="subject1-uid" ref="instance('i-letter')/*:subject-uid">
        <xf:action ev:event="xforms-value-changed">
            <xf:message level="ephemeral">subject changed</xf:message>
        </xf:action>
    </xf:input>
    <xf:input id="subject1-display"  ref="instance('i-letter')/*:subject-display">
        <xf:action ev:event="xforms-value-changed">
            <xf:action if="string-length(instance('i-letter')/*:subject-uid)>0">
                <xf:setvalue
                    ref="instance('i-error')/*:error/*:subjects/*:error"
                    value="concat('patient found: ', instance('i-letter')/*:subject-display)"/>
                <xf:delete ref="instance('i-error')/*:error/*:subjects/*:subject"/>
            </xf:action>
        </xf:action>
    </xf:input>
    <xf:input id="recipient-uid"     ref="instance('i-letter')/*:recipient-uid">
        <xf:action ev:event="xforms-value-changed" if="instance('i-letter')/*:recipient-uid!=''">
            <xf:setvalue
                ref="instance('i-error')/*:error/*:physician/*:error"
                value="concat('recipient identified: ',instance('i-letter')/*:recipient-display)"/>
            <xf:delete ref="instance('i-error')/*:error/*:physician/*:recipient"/>
        </xf:action>
    </xf:input>
    <xf:input id="recipient-display" ref="instance('i-letter')/*:recipient-display"/>
    <xf:input id="author-uid"        ref="instance('i-letter')/*:author-uid">
        <xf:action ev:event="xforms-value-changed" if="instance('i-letter')/*:author-uid!=''">
            <xf:setvalue
                ref="instance('i-error')/*:error/*:authors/*:error"
                value="concat('author identified: ',instance('i-letter')/*:author-display)"/>
            <xf:delete ref="instance('i-error')/*:error/*:authors/*:author"/> 
        </xf:action>
    </xf:input>
    <xf:input id="author-display"    ref="instance('i-letter')/*:author-display"/>
    <input id="merge-active" name="merge-active" value="true"/>
</div>
,<div id="xforms">
    <table>
        <tr>
            <td rowspan="4">
                <xf:group class="svFullGroup bordered">
                    <xf:action ev:event="betterform-index-changed">
                        <xf:dispatch name="set-current-error" targetid="m-letters"/>
                    </xf:action>
                    <xf:output ref="instance('i-search')/*:path">
                        <xf:label class="svListHeader">V:\LF-Ordner:</xf:label>
                    </xf:output>
                    <xf:trigger>
                        <xf:label>ReImport</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-reimport-errors"/>
                        </xf:action>
                    </xf:trigger>
                    <xf:repeat id="r-errors-id" ref="instance('i-errors')/*:error" appearance="compact" class="svRepeat">
                        <xf:output ref="./*:file">
                            <xf:label>Dateiname:</xf:label>
                        </xf:output>
                    </xf:repeat>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-error')/*:error/*:subjects" class="svFullGroup bordered">
                    <xf:label><xf:output value="./*:error"/></xf:label>
                    <xf:repeat ref="./*:subject" appearance="compact" class="svRepeat">
                        <xf:output ref="./*:display/@value">
                            <xf:label class="svRepeatHeader">Patient</xf:label>
                        </xf:output>
                    </xf:repeat>
                    <br/>
                    <table>
                        <tr>
                            <td>
                                <xf:group ref="./*:subject/*:fuzzy">
                                    <xf:label>Kandidaten</xf:label>
                                    <xf:repeat id="r-fuzzy-id" ref="./*:subject" appearance="compact" class="svRepeat">
                                        <xf:output ref="./*:display/@value">
                                            <xf:label class="svRepeatHeader">Patient</xf:label>
                                        </xf:output>
                                        <xf:trigger>
                                            <xf:label>!</xf:label>
                                            <xf:action ev:event="DOMActivate">
                                                <xf:setvalue
                                                    ref="instance('i-letter')/*:subject-uid"
                                                    value="substring-after(instance('i-error')//*:fuzzy/*:subject[index('r-fuzzy-id')]/*:reference/@value,'nabu/patients/')"/>
                                                <xf:setvalue
                                                    ref="instance('i-letter')/*:subject-display"
                                                    value="instance('i-error')//*:fuzzy/*:subject[index('r-fuzzy-id')]/*:display/@value"/>
                                                <xf:setvalue
                                                    ref="instance('i-error')/*:error/*:subjects/*:error"
                                                    value="'patient identified'"/>
                                                <xf:delete ref="instance('i-error')/*:error/*:subjects/*:subject"/>
                                            </xf:action>
                                        </xf:trigger>
                                    </xf:repeat>
                                </xf:group>
                            </td>
                            <td>
                                <xf:group ref="bf:instanceOfModel('m-letters','views')/*:NoPatient">
                                    <label for="subject1-hack" class="xfLabel aDefault xfEnabled">Patient?:</label>
                                    <select class="patient-select long-input" name="subject1-hack">
                                        <option></option>
                                    </select>
                                </xf:group>
                            </td>
                        </tr>
                    </table>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td>
                <xf:group ref="instance('i-error')/*:error/*:physician" class="svFullGroup bordered">
                    <xf:label><xf:output value="./*:error"/></xf:label>
                    <xf:repeat ref="./*:recipient//*:Practitioner" appearance="compact" class="svRepeat">
                        <xf:output ref="./*:name/*:familiy/@value">
                            <xf:label class="svRepeatHeader">Zuweiser</xf:label>
                        </xf:output>
                    </xf:repeat>
                    <br/>
                    <table>
                        <tr>
                            <td>
                                <xf:group ref="./*:recipient/*:practitioners">
                                    <xf:label>Kandidaten</xf:label>
                                    <xf:repeat id="r-practitioners-id" ref="./*:Practitioner" appearance="compact" class="svRepeat">
                                        <xf:group>
                                            <xf:output
                                                value="concat(./*:name/*:family/@value,', ',./*:name/*:given/@value)" class="long-output"/>
                                            <xf:output
                                                value="concat(./*:address/*:line[1]/@value,', ',./*:address/*:city/@value)"/>
                                        </xf:group>
                                        <xf:trigger>
                                            <xf:label>!</xf:label>
                                            <xf:action ev:event="DOMActivate">
                                                <xf:setvalue
                                                    ref="instance('i-letter')/*:recipient-uid"
                                                    value="instance('i-error')//*:practitioners/*:Practitioner[index('r-practitioners-id')]/*:id/@value"/>
                                                <xf:setvalue
                                                    ref="instance('i-letter')/*:recipient-display"
                                                    value="concat(instance('i-error')//*:practitioners/*:Practitioner[index('r-practitioners-id')]/*:name/*:family/@value,', ',instance('i-error')//*:practitioners/*:Practitioner[index('r-practitioners-id')]/*:name/*:given/@value)"/>
                                                <xf:setvalue
                                                    ref="instance('i-error')/*:error/*:physician/*:error"
                                                    value="'recipient identified'"/>
                                                <xf:delete ref="instance('i-error')/*:error/*:physician/*:recipient"/>
                                            </xf:action>
                                        </xf:trigger>
                                    </xf:repeat>
                                </xf:group>
                            </td>
                            <td>
                                <xf:group ref="bf:instanceOfModel('m-letters','views')/*:NoPractitioner">
                                    <label for="recipient-hack" class="xfLabel aDefault xfEnabled">Zuweiser?:</label>
                                    <select class="recipient-select long-input" name="recipient-hack">
                                        <option></option>
                                    </select>
                                </xf:group>
                            </td>
                        </tr>
                    </table>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-error')/*:error/*:authors" class="svFullGroup bordered">
                    <xf:label><xf:output value="./*:error"/></xf:label>
                    <xf:repeat ref="./*:author" appearance="compact" class="svRepeat">
                        <xf:output ref="./*:display/@value">
                            <xf:label class="svRepeatHeader">Signatur</xf:label>
                        </xf:output>
                    </xf:repeat>
                    <br/>
                    <xf:group ref="bf:instanceOfModel('m-letters','views')/*:NoAuthor">
                        <label for="author-hack" class="xfLabel aDefault xfEnabled">Erbringer?:</label>
                        <select class="author-select long-input" name="author-hack">
                            <option></option>
                        </select>
                    </xf:group>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-error')/*:error/*:date" class="svFullGroup bordered">
                    <xf:label><xf:output value="./*:error"/></xf:label>
                    <xf:output ref="./*:dateline"/>
                    <xf:input ref="instance('i-letter')/*:date"/>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svAddTrigger">
                    <xf:label>Import</xf:label>
                    <xf:action ev:event="DOMActivate">
                      <xf:action if="not(instance('i-error')/*:error/subjects) or instance('i-letter')/*:subject-uid!=''">
                        <xf:send submission="s-import-letter"/>
                      </xf:action>
                    </xf:action>
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svDelTrigger">
                    <xf:label>Löschen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-delete-error"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
        <tr>
            <td colspan="2">
                <xf:group id="letterpane"/>
            </td>
        </tr>
    </table>
    <script type="text/javascript" defer="defer" src="modules/subject.js"/>
    <script type="text/javascript" defer="defer" src="modules/recipient.js"/>
    <script type="text/javascript" defer="defer" src="modules/author.js"/>
</div>
)
};