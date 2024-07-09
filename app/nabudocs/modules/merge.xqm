xquery version "3.0";

module namespace merge = "http://enahar.org/exist/apps/nabudocs/merge";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function merge:patient($loguid,$lognam,$realm, $cmdln-status)
{
    let $status := if ($cmdln-status="false")
        then 'false'
        else 'true'
    return
(<div style="display:none;">
    <xf:model id="m-patient">
        <xf:instance xmlns="" id="i-patient1">
            <data>
                <Patient/>
            </data>
        </xf:instance>
        <xf:submission id="s-get-subject1"
        			instance="i-patient1"
					method="get"
					targetref="bf:instanceOfModel('m-patient','i-patient1')/*:Patient"
				    replace="instance">
			<xf:resource value="concat('/exist/restxq/nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject1-uid,'?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:send submission="s-get-dups"/>
                <xf:send submission="s-get-resources"/>
            </xf:action>
            <xf:action if="">
                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:transfer" value="'true'"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get patient</xf:message>
        </xf:submission>       
        <!-- store patient instance and replace retour for new patient (id/@value) -->
        <xf:submission id="s-submit-subject1"
        			ref="bf:instanceOfModel('m-patient','i-patient1')"
					method="put"
					replace="instance"
					targetref="bf:instanceOfModel('m-patient','i-patient1')/*:Patient">
                <xf:resource value="concat('/exist/restxq/nabu/patients?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Patient data submitted</xf:message>
                <xf:setvalue 
                    ref="bf:instanceOfModel('m-patient','i-control-center')/*:changed"
                    value="'false'"/>
                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject1-active" value="'true'"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit! Validation? Other error?</xf:message>
        </xf:submission>
        <xf:instance xmlns="" id="i-patient2">
            <data>
                <Patient/>
            </data>
        </xf:instance>
        <xf:submission id="s-get-subject2"
        			instance="i-patient2"
					method="get"
					targetref="bf:instanceOfModel('m-patient','i-patient2')/*:Patient"
				    replace="instance">
			<xf:resource value="concat('/exist/restxq/nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject2-uid,'?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Patient2 loaded</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get patient2</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-dups">
            <data/>
        </xf:instance>
        <xf:submission id="s-get-dups"
        			instance="i-dups"
					method="get"
				    replace="instance">
			<xf:resource value="concat('/exist/restxq/nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject1-uid,'/dups','?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Dups searched</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get dups</xf:message>
        </xf:submission>  

            <xf:instance id="i-eocs">
                <data xmlns=""/>
            </xf:instance>
            <xf:submission id="s-get-eocs" instance="i-eocs" replace="instance" method="get">
                <xf:resource value="concat('/exist/restxq/nabu/eocs?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;subject=', bf:instanceOfModel('m-patient','i-control-center')/*:subject1-uid,'&amp;status=planned&amp;status=active&amp;status=finished&amp;status=cancelled')"/>
                <xf:action ev:event="xforms-submit-done">
                    <xf:setvalue ref="instance('i-control-center')/*:eocs-id" value="count(instance('i-eocs')/*:EpisodeOfCare[*:status/@value=('planned','active')]/preceding-sibling::EpisodeOfCare)+1"/>
                </xf:action>
                <xf:message ev:event="xforms-submit-error" level="ephemeral">cannot load EoCs!.</xf:message>
            </xf:submission>
            <xf:submission id="s-submit-active-EoC" ref="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]" method="put" replace="instance" targetref="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]">
                <xf:resource value="concat('/exist/restxq/nabu/eocs?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
                <xf:header>
                    <xf:name>Content-Type</xf:name>
                    <xf:value>application/xml</xf:value>
                </xf:header>
                <xf:action ev:event="xforms-submit-done">
                </xf:action>
                <xf:message ev:event="xforms-submit-error" level="modal">cannot submit EoC!</xf:message>
            </xf:submission>

            <xf:instance id="i-careteams">
                <data xmlns=""/>
            </xf:instance>
            <xf:submission id="s-get-careteams" instance="i-careteams" method="get" replace="instance">
                <xf:resource value="concat('/exist/restxq/nabu/careteams?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;subject=',bf:instanceOfModel('m-patient','i-control-center')/*:subject1-uid,'&amp;status=active&amp;status=inactive')"/>
                <xf:header>
                    <xf:name>Content-Type</xf:name>
                    <xf:value>application/xml</xf:value>
                </xf:header>
                <xf:action ev:event="xforms-submit-done">
                    <xf:setvalue ref="instance('i-control-center')/*:cts-id" value="count(instance('i-careteams')/*:CareTeam[*:status/@value=('active')]/preceding-sibling::CareTeam)+1"/>
                </xf:action>
                <xf:message ev:event="xforms-submit-error" level="modal">cannot get careteams!</xf:message>
            </xf:submission>
            <xf:submission id="s-submit-active-CT" ref="instance('i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]" method="put" replace="instance" targetref="instance('i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]">
                <xf:resource value="concat('/exist/restxq/nabu/careteams?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
                <xf:header>
                    <xf:name>Content-Type</xf:name>
                    <xf:value>application/xml</xf:value>
                </xf:header>
                <xf:action ev:event="xforms-submit-done">
                </xf:action>
                <xf:message ev:event="xforms-submit-error" level="modal">cannot submit CareTeam!</xf:message>
            </xf:submission>        
        <xf:instance id='i-resources'>
            <data xmlns="">
            </data>
        </xf:instance>
        <xf:submission id="s-get-resources"
        			instance="i-resources"
					method="get"
				    replace="instance">
			<xf:resource value="concat('/exist/restxq/nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject1-uid,'/everymeta','?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Resources meta bundle loaded</xf:message>
                <xf:delete ref="instance('i-resources')/*:meta[@type='Patient']"/>
                <xf:delete ref="instance('i-resources')/*:meta[@type='EpisodeOfCare']"/>
                <xf:delete ref="instance('i-resources')/*:meta[@type='CareTeam']"/>
            </xf:action>
            <xf:action ev:event="xforms-submit-error">
                <xf:message level="modal">error retrieving resources</xf:message>
                <xf:load show="replace" resource="/exist/apps/nabudocs/merge.html"/>
            </xf:action>
        </xf:submission>
        <xf:submission id="s-submit-resources"
                ref="instance('i-resources')"
        			instance="i-resources"
					method="put"
				    replace="none">
			<xf:resource value="concat('/exist/restxq/nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject2-uid,'/updateSubject','?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:delete ref="instance('i-resources')/*:meta[@tdt='true']"/>
                <xf:message level="ephemeral">Resources moved</xf:message>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">error moving resources</xf:message>
        </xf:submission>        
        <xf:bind ref="instance('i-resources')/*:meta/@tdt" type="xs:boolean"/>
        
        <xf:instance id='iiter'>
            <iiter xmlns="">0</iiter>
        </xf:instance>        
        
        <xf:instance id="i-login">
            <data xmlns="">
                <loguid>{$loguid}</loguid>
                <lognam>{$lognam}</lognam>
                <realm>{$realm}</realm>
            </data>
        </xf:instance>
        <xf:instance id="i-control-center">
            <data xmlns="">
                <currentForm/>
                <changed>false</changed>
                <language>de</language>
                <subject1-uid/>
                <subject1-display/>
                <subject1-active>{$status}</subject1-active>
                <cts-id>0</cts-id>
                <eocs-id>0</eocs-id>
                <subject2-uid/>
                <subject2-display/>
                <header1>Patient</header1>
                <header2>--&gt;</header2>
                <transfer>true</transfer>
            </data>
        </xf:instance>
        
        <xf:instance id="views">
            <data xmlns="">
                <NoPatient1/>
                <NewPatient1/>
                <Patient1Stored/>
                <Patient1HasObjects/>
                <Patient1NoObjects/>
                <NoPatient2/>
                <NewPatient2/>
                <Patient2Stored/>
                <TransferMode/>
            </data>
        </xf:instance>
        
        <xf:instance id="brick1">
            <data xmlns="">
                <Patient/>
            </data>
        </xf:instance>
        <xf:instance id="brick2">
            <data xmlns="">
                <Patient/>
            </data>
        </xf:instance>        
        
        <xf:bind id="NoPatient1"
            ref="bf:instanceOfModel('m-patient','views')/*:NoPatient1"
            relevant="not(bf:instanceOfModel('m-patient','i-patient1')/*:Patient/*:id)"/>
        <xf:bind id="NewPatient1"
            ref="bf:instanceOfModel('m-patient','views')/*:NewPatient1"
            relevant="bf:instanceOfModel('m-patient','i-patient1')/*:Patient/*:id/@value=''"/>
        <xf:bind id="Patient1Stored"
            ref="bf:instanceOfModel('m-patient','views')/*:Patient1Stored"
            relevant="bf:instanceOfModel('m-patient','i-patient1')/*:Patient/*:id/@value != ''"/>
        <xf:bind id="Patient1NoObjects"
            ref="bf:instanceOfModel('m-patient','views')/*:Patient1NoObjects"
            relevant="count(instance('i-resources')/*:meta) = 0"/>
        <xf:bind id="Patient1HasObjects"
            ref="bf:instanceOfModel('m-patient','views')/*:Patient1HasObjects"
            relevant="count(instance('i-resources')/*:meta) > 0"/>
        <!-- Patient 2 -->
        <xf:bind id="NoPatient2"
            ref="bf:instanceOfModel('m-patient','views')/*:NoPatient2"
            relevant="not(bf:instanceOfModel('m-patient','i-patient2')/*:Patient/*:id)"/>
        <xf:bind id="NewPatient2"
            ref="bf:instanceOfModel('m-patient','views')/*:NewPatient2"
            relevant="bf:instanceOfModel('m-patient','i-patient2')/*:Patient/*:id/@value=''"/>
        <xf:bind id="Patient2Stored"
            ref="bf:instanceOfModel('m-patient','views')/*:Patient2Stored"
            relevant="bf:instanceOfModel('m-patient','i-patient2')/*:Patient/*:id/@value != ''"/>
        <!-- TransferMode -->
        <xf:bind id="TransferMode"
            ref="bf:instanceOfModel('m-patient','views')/*:TransferMode"
            relevant="bf:instanceOfModel('m-patient','i-control-center')/*:transfer = 'true' and bf:instanceOfModel('m-patient','i-patient2')/*:Patient/*:id/@value!=''"/>
            
        <xf:action ev:event="cleanup">
            <script type="text/javascript">
                    $('.patient-select[name="subject1-hack"]').val('').trigger('change');
                    $('.patient-select[name="subject2-hack"]').val('').trigger('change');
            </script>
            <xf:delete ref="bf:instanceOfModel('m-patient','i-patient1')/*:Patient"/>
            <xf:delete ref="bf:instanceOfModel('m-patient','i-patient2')/*:Patient"/>
            <xf:delete ref="bf:instanceOfModel('m-patient','i-dups')/*:p"/>
            <xf:delete ref="bf:instanceOfModel('m-patient','i-resources')/*:meta"/>
            <xf:insert 
                ref="bf:instanceOfModel('m-patient','i-patient1')/*:Patient"
                context="bf:instanceOfModel('m-patient','i-patient1')"
                origin="bf:instanceOfModel('m-patient','brick1')/*:Patient"/>
            <xf:insert 
                ref="instance('i-patient2')/*:Patient"
                context="instance('i-patient2')"
                origin="instance('brick2')/*:Patient"/>
            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:header1" value="'Patient'"/>
        </xf:action>
    
        <xf:action ev:event="xforms-model-construct-done">
        </xf:action>
        <xf:action ev:event="xforms-ready">
        </xf:action>
    </xf:model>
    <xf:input id="subject1-uid" ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject1-uid"/>
    <xf:input id="subject1-display" ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject1-display">
        <xf:action ev:event="xforms-value-changed">
            <xf:action if="bf:instanceOfModel('m-patient','i-control-center')/*:subject1-uid != ''">
                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject1-active" value="'{$status}'"/>
                <xf:send submission="s-get-subject1"/>
                <xf:send submission="s-get-eocs"/>
                <xf:send submission="s-get-careteams"/>
            </xf:action>
        </xf:action>
    </xf:input>
    <xf:input id="subject2-uid" ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject2-uid"/>
    <xf:input id="subject2-display" ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject2-display">
        <xf:action ev:event="xforms-value-changed">
            <xf:action if="bf:instanceOfModel('m-patient','i-control-center')/*:subject2-uid != ''">
                <xf:send submission="s-get-subject2"/>
            </xf:action>
        </xf:action>
    </xf:input>
    <input id="merge-active" name="merge-active" value="{$status}"/>
</div>,
<div id="xforms">
    <h3>Nabu Resource Explorer</h3>
    <xf:group ref="bf:instanceOfModel('m-patient','i-control-center')[*:subject1-active= 'false']">
        <xf:output value="choose(bf:instanceOfModel('m-patient','i-patient1')/*:Patient/*:active/@value='false', 'Gelöschter Patient ',' ')"/>
        <xf:trigger ref="bf:instanceOfModel('m-patient','i-patient1')/*:Patient[*:id/@value!='']" class="svAddTrigger">
            <xf:label>reActivate</xf:label>
            <xf:action ev:event="DOMActivate">
                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-patient1')/*:Patient/*:active/@value" value="'true'"/>
                <xf:send submission="s-submit-subject1"/>
            </xf:action>
        </xf:trigger>
    </xf:group>
    <table>
        <tr>
            <td colspan="4">
                <xf:group>
                    <h4>
                        <xf:output 
                            value="choose(bf:instanceOfModel('m-patient','i-control-center')/*:subject1-display='',bf:instanceOfModel('m-patient','i-control-center')/*:header1,bf:instanceOfModel('m-patient','i-control-center')/*:subject1-display)"/>
                        <xf:output value="choose(bf:instanceOfModel('m-patient','i-control-center')/*:subject1-display='','',bf:instanceOfModel('m-patient','i-patient1')/*:Patient/*:extension[@url='#patient-presenting-problem']/*:presenting-problem/@value)">
                        </xf:output>
                    </h4>
                </xf:group>
            </td>
            <td colspan="4">
                <xf:group ref="bf:instanceOfModel('m-patient','views')/*:NoPatient1">

                    <select class="patient-select long-input" name="subject1-hack">
                        <option></option>
                    </select>
                    <script type="text/javascript" defer="defer" src="modules/subject.js"/>
                </xf:group>
                <xf:trigger  ref="bf:instanceOfModel('m-patient','views')/*:Patient1Stored" class="svUpdateMasterTrigger">
                    <xf:label>./. Patienten</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="cleanup" targetid="m-patient"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td colspan="4">
                <xf:group ref="bf:instanceOfModel('m-patient','i-control-center')/*:transfer[.='true']">
                    <h4>
                        <xf:output value="choose(bf:instanceOfModel('m-patient','i-control-center')/*:subject2-display='',bf:instanceOfModel('m-patient','i-control-center')/*:header2,bf:instanceOfModel('m-patient','i-control-center')/*:subject2-display)"/>
                        <xf:output value="choose(bf:instanceOfModel('m-patient','i-control-center')/*:subject2-display='','',bf:instanceOfModel('m-patient','i-patient2')/*:Patient/*:extension[@url='#patient-presenting-problem']/*:presenting-problem/@value)">
                        </xf:output>
                    </h4>
                </xf:group>
            </td>
            <td colspan="4">
                <xf:group  ref="bf:instanceOfModel('m-patient','i-control-center')/*:transfer[.='true']">
                    <xf:group ref="bf:instanceOfModel('m-patient','views')/*:NoPatient2">
                        <label for="subject2-hack" class="xfLabel aDefault xfEnabled">Suche:</label>
                        <select class="patient-select long-input" name="subject2-hack">
                            <option></option>
                        </select>
                    </xf:group>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td colspan="4">
                <xf:group ref="instance('i-dups')/*:p" class="svFullGroup bordered">
                    <xf:label>Mögl. Doppeleinträge</xf:label>
                    <xf:repeat ref="instance('i-dups')/*:p" appearance="compact" class="svRepeat">
                        <xf:output ref=".">
                            <xf:label class="svRepeatHeader">Name:</xf:label>
                        </xf:output>
                    </xf:repeat>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td colspan="4">
                <xf:group ref="instance('views')/*:Patient1HasObjects" class="svFullGroup bordered">
                    <xf:label class="">Resourcen des Patienten</xf:label>
                    <xf:repeat id="r-resources-id" ref="instance('i-resources')/*:meta[@type!='EpisodeOfCare'][@type!='CareTeam']" appearance="compact" class="svRepeat">
                        <xf:output ref="./@type">
                            <xf:label class="svRepeatHeader">Resource</xf:label>
                        </xf:output>
                        <xf:output ref="./*:lastModified/@value">
                            <xf:label class="svRepeatHeader">lastMod</xf:label>
                        </xf:output>
                        <xf:output ref="./*:info">
                            <xf:label class="svRepeatHeader">Info</xf:label>
                        </xf:output>
                        <xf:input ref="./@tdt" class="">
                            <xf:label>Select</xf:label>
                        </xf:input>
                    </xf:repeat>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td>
                <xf:group  ref="bf:instanceOfModel('m-patient','views')/*:Patient1Stored">
                    <xf:trigger ref="bf:instanceOfModel('m-patient','views')/*:Patient1NoObjects" class="svDelTrigger">
                        <xf:label>Patienten löschen?</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-patient1')/*:Patient/*:active/@value" value="'false'"/>
                            <xf:send submission="s-submit-subject1"/>
                            <xf:action if="xs:int(instance('i-control-center')/*:eocs-id)&gt;0">
                                <xf:setvalue 
                                    ref="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]/*:status/@value" 
                                    value="'finished'"/>
                                <xf:send submission="s-submit-active-EoC"/>
                            </xf:action>
                            <xf:action if="xs:int(instance('i-control-center')/*:cts-id)&gt;0">
                                <xf:setvalue 
                                    ref="instance('i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]/*:status/@value" 
                                    value="'inactive'"/>
                                <xf:send submission="s-submit-active-CT"/>
                            </xf:action>
                            <xf:dispatch name="cleanup" targetid="m-patient"/>
                        </xf:action>
                    </xf:trigger>
                </xf:group>
                <xf:group  ref="bf:instanceOfModel('m-patient','views')/*:Patient1HasObjects">
                    <table>
                        <tr><td>
                    <xf:trigger class="svAddTrigger">
                        <xf:label>Select all</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:setvalue ref="instance('iiter')" value="'1'"/>
                            <xf:action while="instance('iiter') &lt;= count(instance('i-resources')/*:meta)">
                                <xf:setvalue ref="instance('i-resources')/*:meta[xs:int(instance('iiter'))]/@tdt" value="'true'"/>
                                <xf:setvalue ref="instance('iiter')" value="instance('iiter') + 1"/>
                            </xf:action>
                        </xf:action>
                    </xf:trigger>
                        </td><td>
                    <xf:trigger ref="bf:instanceOfModel('m-patient','views')/*:TransferMode" class="svDelTrigger">
                        <xf:label>Move selected</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-submit-resources"/>
                        </xf:action>
                    </xf:trigger>
                            </td>
                        </tr>
                    </table>
                </xf:group>
            </td>
        </tr>
    </table>
</div>
)
};

