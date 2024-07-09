xquery version "3.0";

module namespace pat ="http://enahar.org/exist/apps/nabu/patient";

import module namespace templates="http://exist-db.org/xquery/templates";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"
               at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients"  at "patient-routes.xqm";
(: 
 : import module namespace r-app     = "http://enahar.org/exist/restxq/nabu/appointments"  at "../Appointment/appointment-routes.xqm";
:)
import module namespace r-visit   = "http://enahar.org/exist/restxq/nabu/encounters"  at "../Encounter/encounter-routes.xqm";
import module namespace r-order   = "http://enahar.org/exist/restxq/nabu/orders"  at "../Order/order-routes.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

declare variable $pat:restxq-patients := "/exist/restxq/nabu/patients";
declare variable $pat:pinfo-path := 'exist/apps/nabu/FHIR/Patient/patient/patient-infos.xml';
declare variable $pat:restxq-search-docs := "/exist/restxq/nabu/search-docs";

declare function pat:showFunctions($uid)
{
    <div>
        <h3>Patienten:</h3>
        <ul>
            <li>
                <a href="index.html?action=listPatients">Finden - Dokumentieren</a>
            </li>
        </ul>
    </div>
};


declare function local:lookup($tableName, $name as xs:string)
{
    let $pinfos := doc($pat:pinfo-path)/minfos
    return
        if ($tableName='name')
        then $pinfos/meeting[@value=$name]/name
        else if ($tableName='loc')
        then $pinfos/mlocs/loc[@value=$name]
        else if ($tableName='perm')
        then $pinfos/mperms/perm[@value=$name]
        else ''
};

declare function pat:listPatients($pid as xs:string?)
{
    let $realm  := "metis/organizations/kikl-spzn"
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid   := $logu/fhir:id/@value/string()
    let $uref   := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid    := substring-after($uref,'metis/practitioners/')
    let $unam   := $logu/fhir:practitioner/fhir:display/@value/string()
    let $roles  := r-practrole:rolesByID($prid,$realm,$uid,$unam)
    let $org    := $realm
    let $perms  := r-practrole:perms($prid)/fhir:perm
    let $loggrp := tokenize($logu/fhir:specialty//fhir:code/@value,'-')[1]

    let $isGuest := 'perm_get-patient-only' = $perms
    let $isAdmin := 'perm_admin' = $perms or $uid = ('u-admin','u-pmh')
return
(<div style="display:none;">
    <xf:model id="m-patient">
        <xf:instance xmlns="" id="i-patient">
            <data>
                <Patient/>
            </data>
        </xf:instance>
        <xf:bind ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient">
            <xf:bind ref="*:name[*:use/@value='official']/*:given/@value"        type="xs:string"  required="true()"/>
            <xf:bind ref="*:name[*:use/@value='official']/*:family/@value"       type="xs:string"  required="true()"/>
<!--
            <xf:bind ref="*:birthDate/@value"           type="xs:date"    required="true()"/>
-->
            <xf:bind ref="*:telecom/*:rank/@value" type="xs:int" required="true()"/>
            <xf:bind ref="*:contact/*:extension[@url='#patient-contact-preferred']/*:valueBoolean/@value" type="xs:boolean"/>
        </xf:bind>
        <xf:submission id="s-get-subject"
        			instance="i-patient"
					method="get"
					targetref="bf:instanceOfModel('m-patient','i-patient')/*:Patient"
				    replace="instance">
			<xf:resource value="concat('/exist/restxq/nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid,'?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:action if="string-length(bf:instanceOfModel('m-patient','i-control-center')/*:subject-display)=0">
                    <xf:message level="ephemeral">Patient per cmdln</xf:message>
                    <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:loaded-via-cmdln" value="'true'"/>
                    <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject-display" value="string-join((bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:name[*:use/@value='official']/*:family/@value, bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:name[*:use/@value='official']/*:given/@value, concat('*',bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:birthDate/@value)), ', ')"/>
                </xf:action>
                <xf:send submission="s-get-EoCs"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get patient</xf:message>
        </xf:submission>       
        <!-- store patient instance and replace retour for new patient (id/@value) -->
        <xf:submission id="s-submit-subject"
        			ref="bf:instanceOfModel('m-patient','i-patient')"
					method="put"
					replace="instance"
					targetref="bf:instanceOfModel('m-patient','i-patient')/*:Patient">
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
                <!-- has to be set for new patient -->
                <xf:action if="string-length(bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid)=0">
                    <xf:setvalue 
                        ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid"
                        value="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:id/@value"/>
                    <xf:setvalue 
                        ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject-display"
                        value="string-join((bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:name[*:use/@value='official']/*:family/@value, bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:name[*:use/@value='official']/*:given/@value, concat('*',bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:birthDate/@value)), ', ')"/>
                    <xf:setvalue 
                        ref="bf:instanceOfModel('m-patient','i-goal')/*:Goal/*:subject/*:reference/@value"
                        value="concat('nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid)"/>
                    <xf:setvalue 
                        ref="bf:instanceOfModel('m-patient','i-goal')/*:Goal/*:subject/*:display/@value"
                        value="bf:instanceOfModel('m-patient','i-control-center')/*:subject-display"/>  
                    <xf:send submission="s-submit-registration"/>
                    <xf:setvalue 
                        ref="bf:instanceOfModel('m-patient','i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]/*:patient/*:reference/@value"
                        value="concat('nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid)"/>
                    <xf:setvalue 
                        ref="bf:instanceOfModel('m-patient','i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]/*:patient/*:display/@value"
                        value="bf:instanceOfModel('m-patient','i-control-center')/*:subject-display"/>
                    <xf:setvalue 
                        ref="bf:instanceOfModel('m-patient','i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]/*:subject/*:reference/@value"
                        value="concat('nabu/patients/',bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid)"/>
                    <xf:setvalue 
                        ref="bf:instanceOfModel('m-patient','i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]/*:subject/*:display/@value"
                        value="bf:instanceOfModel('m-patient','i-control-center')/*:subject-display"/>
                    <xf:send submission="s-submit-active-EoC"/>
                    <xf:send submission="s-submit-active-CT"/>

                    <xf:dispatch name="updateEoCCTlinks" targetid="m-patient"/>
                </xf:action>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit! Validation? Other error?</xf:message>
        </xf:submission>
<!--        
        <xf:submission id="s-new-patient-tag"
					method="post"
					replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/conditions?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;tag=NP&amp;text=',encode-for-uri('Neuer Patient'),'&amp;pid=',bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid,'&amp;pnam=',encode-for-uri(bf:instanceOfModel('m-patient','i-control-center')/*:subject-display))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">new patient tag submitted</xf:message>
            </xf:action>
           <xf:message ev:event="xforms-submit-error" level="modal">cannot submit tag!</xf:message>
        </xf:submission>
-->
        <xf:instance id="i-eocs">
            <data xmlns=""/>
        </xf:instance>
        <xf:submission id="s-get-EoCs"
					method="get"
					instance="i-eocs"
					replace="instance">
                <xf:resource value="concat('/exist/restxq/nabu/eocs?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm),'&amp;patient=',bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid,'&amp;status=planned&amp;status=active&amp;status=finished&amp;status=cancelled')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                    <xf:setvalue ref="instance('i-control-center')/*:eocs-id" value="count(instance('i-eocs')/*:EpisodeOfCare[*:status/@value=('planned','active','completed','cancelled')]/preceding-sibling::EpisodeOfCare)+1"/>
                <xf:message level="ephemeral">EoCs loaded</xf:message>
            </xf:action>
           <xf:message ev:event="xforms-submit-error" level="modal">cannot load EoCs!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-active-EoC"
					method="put"
					ref="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]"
					replace="instance"
					targetref="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]">
                <xf:resource value="concat('/exist/restxq/nabu/eocs?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">EoC submitted</xf:message>
            </xf:action>
           <xf:message ev:event="xforms-submit-error" level="modal">cannot submit EoC!</xf:message>
        </xf:submission>
        <xf:instance id="i-careteams">
            <data xmlns=""/>
        </xf:instance>        
        <xf:submission id="s-submit-active-CT"
					method="put"
					ref="instance('i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]"
					replace="instance"
					targetref="instance('i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]">
                <xf:resource value="concat('/exist/restxq/nabu/careteams?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">CT submitted</xf:message>
            </xf:action>
           <xf:message ev:event="xforms-submit-error" level="modal">cannot submit CT!</xf:message>
        </xf:submission>
        <xf:instance id="i-goal">
            <data xmlns=""/>
        </xf:instance>        
        <xf:submission id="s-submit-registration"
					method="put"
					ref="instance('i-goal')/*:Goal[1]"
					replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/goals?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:message level="ephemeral">Goal submitted</xf:message>
            </xf:action>
           <xf:message ev:event="xforms-submit-error" level="modal">cannot submit Goal!</xf:message>
        </xf:submission> 
        <xf:instance id="i-login">
            <data xmlns="">
                <loguid>{$uid}</loguid>
                <lognam>{$unam}</lognam>
                <loggrp>{$loggrp}</loggrp>
                <realm>{$realm}</realm>
                <today>{tokenize(current-date(),'\+')[1]}</today>
            </data>
        </xf:instance>
        <xf:instance id="i-control-center">
            <data xmlns="">
                <currentForm/>
                <changed>false</changed>
                <language>de</language>
                <subject-uid>{$pid}</subject-uid>
                <subject-display/>
                <loaded-via-cmdln>false</loaded-via-cmdln>
                <header>Patienten</header>
                { if ($isGuest) then <isGuest/> else <isNotGuest/> }
                { if ($isAdmin) then <isAdmin/> else <isNotAdmin/> }
                <eocs-id>1</eocs-id>
                <cts-id>1</cts-id>
            </data>
        </xf:instance>

        <xf:instance id="i-pinfos" src="FHIR/Patient/patient-infos.xml"/>
        <xf:instance id="i-eoc-infos" src="FHIR/EpisodeOfCare/episodeofcare-infos.xml"/>
        <xf:instance id="i-ct-infos" src="FHIR/CareTeam/careteam-infos.xml"/>
        <xf:instance id="i-goal-infos" src="FHIR/Goal/goal-infos.xml"/>
        <xf:instance id="i-iso3166-1" src="resources/iso3166-1.xml"/>
        <xf:instance id="i-iso3166-2" src="resources/iso3166-2.xml"/>
        <xf:instance id="i-bcp47" src="resources/ietf-bcp47.xml"/>

        <xf:instance id="views">
            <data xmlns="">
                <NoPatient/>
                <NewPatient/>
                <PatientStored/>
            </data>
        </xf:instance>
        
        <xf:instance id="bricks">
            <data xmlns="">
                <Patient/>
            </data>
        </xf:instance>
        
        <xf:bind id="NoPatient"
            ref="bf:instanceOfModel('m-patient','views')/*:NoPatient"
            relevant="not(bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:id)"/>
        <xf:bind id="NewPatient"
            ref="bf:instanceOfModel('m-patient','views')/*:NewPatient"
            relevant="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:id=''"/>
        <xf:bind id="PatientStored"
            ref="bf:instanceOfModel('m-patient','views')/*:PatientStored"
            relevant="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:id/@value != ''"/>
            
        <xf:action ev:event="updateEoCCTlinks">
            <xf:setvalue ref="instance('i-control-center')/*:eocs-id" value="count(instance('i-eocs')/*:EpisodeOfCare)"/>
            <xf:action if="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]/*:team/*:reference/@value=''">
                <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]/*:team/*:reference/@value" value="concat('nabu/careteams/',instance('i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]/*:id/@value)"/>
                <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[xs:int(instance('i-control-center')/*:eocs-id)]/*:team/*:display/@value" value="instance('i-careteams')/*:CareTeam[xs:int(instance('i-control-center')/*:cts-id)]/*:name/@value"/>
                <xf:send submission="s-submit-active-EoC"/>
            </xf:action>
        </xf:action>
        
        <xf:action ev:event="xforms-ready">
            <xf:action if="string-length(instance('i-control-center')/*:subject-uid)&gt;0">
                <xf:send submission="s-get-subject"/>
            </xf:action>
            <xf:action if="string-length(instance('i-control-center')/*:subject-uid)=0">
                <script type="text/javascript">
                    setSelectFocus();
                </script>
            </xf:action>
        </xf:action>        
    </xf:model>
    <xf:group id="controlCenter" model="m-patient">
        <xf:action ev:event="unload-subform" model="m-patient" if="string-length(bf:instanceOfModel('m-patient','i-control-center')/*:currentForm) &gt; 0">
            <xf:send submission="s-submit-subject" if="bf:instanceOfModel('m-patient','i-control-center')/*:changed='true'"/>
            <xf:message level="ephemeral">unloading subform...</xf:message>
            <xf:load show="none" targetid="infopane"/>
            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="''"/>
            <xf:action if="instance('i-control-center')/*:header='Neuer Patient'">
                <xf:dispatch name="showNewPatientSynopsis" targetid="controlCenter"/>
            </xf:action>
        </xf:action>
        <xf:action ev:event="clear-currentform" model="m-patient">
            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="''"/>
        </xf:action>
        <xf:action ev:event="showNewPatientSynopsis">
            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:header" value="'Patienten'"/>
            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:loaded-via-cmdln" value="'false'"/>
            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-info'"/>
            <xf:load show="embed" targetid="infopane">
                <xf:resource value="'FHIR/Patient/synopsis-info.xml'"/>
            </xf:load>
            <xf:toggle case="t-SynopsisMenue"/>
        </xf:action>
    </xf:group>
    <xf:input id="subject-uid" ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid"/>
    <xf:input id="subject-display" ref="bf:instanceOfModel('m-patient','i-control-center')/*:subject-display">
        <xf:action ev:event="xforms-value-changed">
            <xf:action if="bf:instanceOfModel('m-patient','i-control-center')/*:subject-uid!=''">
                <xf:action if="bf:instanceOfModel('m-patient','i-control-center')/*:header='Patienten'">
                    <xf:action if="bf:instanceOfModel('m-patient','i-control-center')/*:loaded-via-cmdln = 'false'">
                        <xf:send submission="s-get-subject"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-info'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/synopsis-info.xml'"/>
                        </xf:load>
                        <xf:toggle case="t-SynopsisMenue"/>
                    </xf:action>
                </xf:action>
            </xf:action>
        </xf:action>
    </xf:input>
</div>,
<xf:group id="patient-main">
    <xf:action ev:event="newPatient">
        <xf:insert
            ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient"
            context="bf:instanceOfModel('m-patient','i-patient')"
            origin="bf:instanceOfModel('m-patient','i-pinfos')/*:bricks/*:Patient"/>
        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:address/*:period/*:start/@value" value="current-dateTime()"/>
        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:name[*:use/@value='official']/*:period/*:start/@value" value="current-dateTime()"/>
    </xf:action>
    <xf:action ev:event="newEoC">
        <xf:insert
            ref="instance('i-eocs')/*:EpisodeOfCare"
            context="instance('i-eocs')"
            origin="instance('i-eoc-infos')/*:bricks/*:EpisodeOfCare"/>
        <xf:insert
            ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:statusHistory"
            context="instance('i-eocs')/*:EpisodeOfCare[last()]"
            origin="instance('i-eoc-infos')/*:bricks/*:statusHistory"/>
        <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:statusHistory[last()]/*:status/@value" value="'planned'"/>
        <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:statusHistory[last()]/*:extension[@url='#eoc-workflow-change']/*:valueCodeableConcept/*:coding/*:code/@value" value="'first-contact'"/>
        <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:statusHistory[last()]/*:extension[@url='#eoc-workflow-change']/*:valueCodeableConcept/*:coding/*:display/@value" value="'Erstkontakt'"/>
        <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:statusHistory[last()]/*:extension[@url='#eoc-workflow-change']/*:valueCodeableConcept/*:text/@value" value="''"/>
        <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:statusHistory[last()]/*:extension[@url='#eoc-workflow-change-author']/*:valueReference/*:reference/@value" value="instance('i-login')/*:loguid"/>
        <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:statusHistory[last()]/*:extension[@url='#eoc-workflow-change-author']/*:valueReference/*:display/@value" value="instance('i-login')/*:lognam"/>
        <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:period/*:start/@value" value="current-dateTime()"/>
        <xf:setvalue ref="instance('i-eocs')/*:EpisodeOfCare[last()]/*:statusHistory[last()]/*:period/*:start/@value" value="current-dateTime()"/>
        <xf:setvalue ref="instance('i-control-center')/*:eocs-id" value="count(instance('i-eocs')/*:EpisodeOfCare[*:status/@value=('planned','active')]/preceding-sibling::EpisodeOfCare)+1"/>
    </xf:action>
    <xf:action ev:event="newCareTeam">
        <xf:insert at="last()" 
            nodeset="instance('i-careteams')/*:CareTeam"
            context="instance('i-careteams')"
            origin="instance('i-ct-infos')/*:bricks/*:CareTeam"/>
        <xf:setvalue ref="instance('i-careteams')/*:CareTeam[last()]/*:period/*:start/@value" value="adjust-dateTime-to-timezone(current-dateTime())"/>
    </xf:action>
    <xf:action ev:event="newGoal">
        <xf:insert 
            nodeset="instance('i-goal')/*:Goal"
            context="instance('i-goal')"
            origin="instance('i-goal-infos')/*:bricks/*:Goal"/>
        <xf:setvalue ref="instance('i-goal')/*:Goal/*:startDate/@value" value="adjust-dateTime-to-timezone(current-dateTime())"/>
        <xf:setvalue ref="instance('i-goal')/*:Goal/*:statusDate/@value" value="adjust-dateTime-to-timezone(current-dateTime())"/>
        <xf:setvalue ref="instance('i-goal')/*:Goal/*:statusReason/@value" value="'neu angemeldet'"/>
        <xf:setvalue ref="instance('i-goal')/*:Goal/*:category/*:coding[*:system/@value='http://hl7.org/fhir/ValueSet/goal-category']/*:code/@value" value="'registration'"/>
        <xf:setvalue ref="instance('i-goal')/*:Goal/*:category/*:coding[*:system/@value='http://hl7.org/fhir/ValueSet/goal-category']/*:display/@value" value="'Anmeldung'"/>
        <xf:setvalue ref="instance('i-goal')/*:Goal/*:category/*:coding/*:text/@value" value="'Anmeldung'"/>
    </xf:action>
    <table>
        <tr>
            <td colspan="4">
                <h3>
                    <xf:output value="choose(bf:instanceOfModel('m-patient','i-control-center')/*:subject-display='',bf:instanceOfModel('m-patient','i-control-center')/*:header,bf:instanceOfModel('m-patient','i-control-center')/*:subject-display)"/>
                    </h3>
            </td>
            <td>
                <xf:trigger  ref="bf:instanceOfModel('m-patient','views')/*:PatientStored" class="svUpdateMasterTrigger">
                    <xf:label>./. Patienten</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <script type="text/javascript">
                                $('.patient-select[name="subject-hack"]').val('').trigger('change');
                        </script>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:delete ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient"/>
                        <xf:insert 
                            ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient"
                            context="bf:instanceOfModel('m-patient','i-patient')"
                            origin="bf:instanceOfModel('m-patient','bricks')/*:Patient"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:header" value="'Patienten'"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:loaded-via-cmdln" value="'false'"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
        <tr>
            <td colspan="4">
                <xf:group ref="bf:instanceOfModel('m-patient','views')/*:NoPatient">
                    <label for="subject-hack" class="xfLabel aDefault xfEnabled">Suche:</label>
                    <select class="patient-select long-input" name="subject-hack">
                        <option></option>
                    </select>
                </xf:group>
                <script type="text/javascript" defer="defer" src="FHIR/Patient/subject.js"/>
            </td>
            <td>
                <xf:group ref="bf:instanceOfModel('m-patient','views')/*:NoPatient">
                    <xf:trigger ref="bf:instanceOfModel('m-patient','i-control-center')/*:isNotGuest" class="svAddTrigger">
                        <xf:label>Neuer Patient</xf:label>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:header" value="'Neuer Patient'"/>
                        <xf:delete ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient"/>
                        <xf:delete ref="bf:instanceOfModel('m-patient','i-eocs')/*:EpisodeOfCare"/>
                        <xf:delete ref="bf:instanceOfModel('m-patient','i-careteams')/*:CareTeam"/>
                        <xf:delete ref="bf:instanceOfModel('m-patient','i-goal')/*:Goal"/>
                        <xf:action ev:event="DOMActivate">
                            <xf:dispatch name="newPatient" targetid="patient-main"/>
                            <xf:dispatch name="newEoC" targetid="patient-main"/>
                            <xf:dispatch name="newCareTeam" targetid="patient-main"/>
                            <xf:dispatch name="newGoal" targetid="patient-main"/>
                            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'demo-name'"/>
                            <xf:load show="embed" targetid="infopane">
                                <xf:resource value="'FHIR/Patient/demo-name.xml'"/>
                            </xf:load>
                            <xf:toggle case="t-DemographicsMenue"/>
                        </xf:action>
                    </xf:trigger>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td colspan="6"><hr style="border: none; height: 1px; color: blue; background: blue;"/></td>
        </tr>
        <tr>
            <td colspan="1">
                <xf:trigger ref="bf:instanceOfModel('m-patient','views')/*:PatientStored" class="svAddTrigger">
                    <xf:label>Synopsis</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-info'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/synopsis-info.xml'"/>
                        </xf:load>
                        <xf:toggle case="t-SynopsisMenue"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td colspan="1">
                <xf:trigger ref="bf:instanceOfModel('m-patient','views')/*:PatientStored" class="svAddTrigger">
                    <xf:label>Demographie</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:action if="'{$isGuest}'='false'">
                            <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'demo-name'"/>
                            <xf:load show="embed" targetid="infopane">
                                <xf:resource value="'FHIR/Patient/demo-name.xml'"/>
                            </xf:load>
                            <xf:toggle case="t-DemographicsMenue"/>
                        </xf:action>
                        <xf:action if="'{$isGuest}'='true'">
                            <xf:toggle case="t-NotAuthorized"/>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
            </td>
            <td colspan="1">
                <xf:trigger ref="bf:instanceOfModel('m-patient','views')/*:PatientStored" class="svAddTrigger">
                    <xf:label>Workflow</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:action if="'{$isGuest}'='false'">
                            <xf:toggle case="t-WorkflowMenue"/>
                        </xf:action>
                        <xf:action if="'{$isGuest}'='true'">
                            <xf:toggle case="t-NotAuthorized"/>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
            </td>
            <td colspan="1">
                <xf:trigger ref="bf:instanceOfModel('m-patient','views')/*:PatientStored" class="svAddTrigger">
                    <xf:label>Dokument</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                    </xf:action>
                    <xf:toggle case="t-DocumentMenue"/>
                </xf:trigger>
            </td>
        </tr>
        <tr>
            <td>
                <xf:switch>
                    <xf:case id="t-SynopsisMenue">
                        { pat:synopsisMenue() }
                    </xf:case>
                    <xf:case id="t-DemographicsMenue">
                        { pat:demographicsMenue() }
                    </xf:case>
                    <xf:case id="t-WorkflowMenue">
                        { pat:workflowMenue() }
                    </xf:case>
                    <xf:case id="t-DocumentMenue">
                        { pat:documentMenue() }
                    </xf:case>
                    <xf:case id="t-NotAuthorized">
                        { pat:notAuthorized() }
                    </xf:case>
                </xf:switch>
            </td>
            <td colspan="5" rowspan="5">
                <br/>
                <xf:group id="infopane" class="svSubForm bordered"></xf:group>
            </td>
        </tr>
    </table>
</xf:group>
)
};


declare %private function pat:notAuthorized() as item()
{
    <xf:group>
        <xf:label>Für diese Aktivität sind Sie leider nicht authorisiert ('Gast-Status').</xf:label>
    </xf:group>
};

declare %private function pat:synopsisMenue() as item()
{
    <xf:group ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:id">
        <table>
                <thead>
                    <th>Synopsis</th>
                </thead>
                <tbody>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Allg. Info</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-info'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Patient/synopsis-info.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Diagnosen</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-conditions'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Patient/synopsis-conditions.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Termine/Besuche</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-encounters'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Patient/synopsis-encounters.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Anforderungen</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-orders'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Patient/synopsis-orders.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Ziele</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-goals'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Patient/synopsis-goals.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Tickets</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'synopsis-tickets'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Patient/synopsis-tickets.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                </tbody>
            </table>
    </xf:group>
};

declare %private function pat:workflowMenue() as item()
{
    <xf:group ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:id">
        <table>
                <thead>
                    <th>Workflow</th>
                </thead>
                <tbody>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>CarePlans</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'wf-careplan'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/CarePlan/careplans.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Ziele</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'wf-goals'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Goal/goals.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Conditions</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'wf-conditions'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Condition/conditions.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Befunde</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'wf-questionnaires'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/QuestionnaireResponse/questionnaireresponses.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>Besuch</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'wf-encounter'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/Encounter/newencounter.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            <xf:trigger class="svSaveTrigger">
                                <xf:label>CareTeam</xf:label>
                                <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'wf-careteam'"/>
                                <xf:load show="embed" targetid="infopane">
                                    <xf:resource value="'FHIR/CareTeam/careteam.xml'"/>
                                </xf:load>
                            </xf:trigger>
                        </td>
                    </tr>
                </tbody>
            </table>
    </xf:group>
};


declare function pat:demographicsMenue()
{
    <xf:group ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:id" model="m-patient" class="svTriggerGroup">
        <table>
            <thead>
                <th>Demographie</th>
            </thead>
            <tbody>
<!--
            <tr>
                <td>
                    <xf:trigger class="svUpdateMasterTrigger">
                        <xf:label>./.</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        </xf:action>
                    </xf:trigger>
                </td>
            </tr>
-->
            <tr>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Name</xf:label>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'demo-name'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/demo-name.xml'"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
            <tr>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Infos</xf:label>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'demo-infos'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/demo-infos.xml'"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
            <tr>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Adresse</xf:label>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'demo-address'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/demo-address.xml'"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
            <tr>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>SozNet</xf:label>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'demo-soznet'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/demo-soznet.xml'"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
            <tr>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>HCPs</xf:label>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'demo-hcps'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/demo-hcps.xml'"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
            </tbody>
        </table>
    </xf:group>
};

declare function pat:documentMenue()
{
    <xf:group ref="bf:instanceOfModel('m-patient','i-patient')/*:Patient/*:id" model="m-patient" class="svTriggerGroup">
        <table>
            <thead>
                <th>Dokument</th>
            </thead>
            <tbody>
            <tr>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Briefe</xf:label>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'doc-letter'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/doc-letter.xml'"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
            <tr>
                <td>
                    <xf:trigger ref="bf:instanceOfModel('m-patient','views')/*:PatientStored" class="svSaveTrigger">
                        <xf:label>Terminbriefe</xf:label>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'doc-appletter'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/doc-appletter.xml'"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
<!--
            <tr>
                <td>
                    <xf:trigger class="svSaveTrigger">
                        <xf:label>Phänotyp</xf:label>
                        <xf:dispatch name="unload-subform" targetid="controlCenter"/>
                        <xf:setvalue ref="bf:instanceOfModel('m-patient','i-control-center')/*:currentForm" value="'doc-pheno'"/>
                        <xf:load show="embed" targetid="infopane">
                            <xf:resource value="'FHIR/Patient/doc-pheno.xml'"/>
                        </xf:load>
                    </xf:trigger>
                </td>
            </tr>
-->
            </tbody>
        </table>
    </xf:group>
};