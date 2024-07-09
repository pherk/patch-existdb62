xquery version "3.0";

module namespace enc-day = "http://enahar.org/exist/apps/nabu/encounter-day";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";
import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"   at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients"  at "../Patient/patient-routes.xqm";
import module namespace r-encounter = "http://enahar.org/exist/restxq/nabu/encounters" at "/db/apps/nabu/FHIR//Encounter/encounter-routes.xqm";
import module namespace enc-details = "http://enahar.org/exist/restxq/nabu/encounter-details"  at "./encounter-day-details.xqm";
import module namespace enc-open    = "http://enahar.org/exist/restxq/nabu/encounter-open"  at "./encounter-day-open.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

declare variable $enc-day:restxq-metis-users  := "/exist/restxq/metis/PractitionerRole/users";
declare variable $enc-day:restxq-metis-users-ref  := "/exist/restxq/metis/PractitionerRole/users?_format=ref";
declare variable $enc-day:restxq-metis-roles  := "/exist/restxq/metis/roles";
declare variable $enc-day:restxq-metis-orgas  := "/exist/restxq/metis/organizations";
declare variable $enc-day:restxq-metis-realms := "/exist/restxq/metis/realms";

declare variable $enc-day:restxq-encounters   := "/exist/restxq/nabu/encounters";
declare variable $enc-day:restxq-orders       := "/exist/restxq/nabu/enc2order";
declare variable $enc-day:restxq-encslist     := "/exist/restxq/nabu/encs2pdf";

declare variable $enc-day:enahar-schedule-ref := "enahar/schedules/";
declare variable $enc-day:restxq-schedules    := "/exist/restxq/enahar/schedules";
declare variable $enc-day:restxq-orphans      := "/exist/restxq/nabu/orphans";

declare variable $enc-day:encounter-infos-uri := "/exist/apps/nabu/FHIR/Encounter/encounter-infos.xml";
declare variable $enc-day:order-infos-uri     := "/exist/apps/nabu/FHIR/Order/order-infos.xml";
(:~
 : show encounter functionality for dashboard
 : 
 : @param $uid user id
 : @return html
 : $uid as xs:string*,
            $realm as xs:string*, $uid as xs:string*,
            $start as xs:string*, $length as xs:string*,
            $timeMin as xs:string*, $timeMax as xs:string*,
            $status as xs:string*)
 :)
declare function enc-day:showFunctions()
{
    let $now := adjust-dateTime-to-timezone(current-dateTime())
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $group  := 'spz-arzt'
    let $realm := "kikl-spzn"
    let $ets   := r-encounter:encountersByParticipant(
                      $uid
                    , $realm, $uid, $unam
                    , "1", "*"
                    , xs:string($now), xs:string($now + xs:dayTimeDuration("P90D"))
                    , "tentative")
    let $anf := concat("Anfragen (", count($ets/fhir:Encounter),")")
    return
    <ul>
        <li>
            <a href="index.html?action=listEncounters">Terminliste</a>, <a href="index.html?action=viewCalendar">Kalender</a>, 
            <a href="index.html?action=acceptEncounters">{$anf}</a>
        </li>
    </ul>
};

declare %private function enc-day:formatFHIRName($logu)
{
    string-join(
        (
              string-join($logu/fhir:name[fhir:use/@value='official']/fhir:family/@value, '')
            , $logu/fhir:name[fhir:use/@value='official']/fhir:given/@value
        ), ', ')
};


(:~
 : show encounters
 : 
 : @return html
 :)
declare function enc-day:list()
{
    let $status := 
        (
          <status>planned</status>
        , <status>arrived</status>
(: 
        , <status>triaged</status>
        , <status>in-progress</status>
:)
        , <status>tentative</status>
        )
    let $date   := adjust-date-to-timezone(current-date())
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $group  := 'spz-arzt'
    let $realm := "kikl-spzn"
    let $head  := 'Termine' 
return
(<div style="display:none;">
    <xf:model id="m-encounter" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance  xmlns="" id="i-encs">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-encounters"
                    ref="instance('i-search')"
                	instance="i-encs"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$enc-day:restxq-encounters}','?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">error get-encounters</xf:message>
        </xf:submission>
        <xf:submission id="s-get-encslist-pdf"
                    ref="instance('i-search')"
                	instance="i-encs"
					method="get"
					replace="none">
			<xf:resource value="concat('{$enc-day:restxq-encslist}','?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('i-search')/*:_sort" value="'date:asc'"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">error: get archiv list</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-encounter"
                				   ref="instance('i-encs')/*:Encounter[index('r-encs-id')]"
								   method="put"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/encounters?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:action if="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value='finished'">
                    <xf:send submission="s-update-careteam"/>
                </xf:action>
                <xf:action if="string-length(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:basedOn/*:reference/@value)>0">
                    <xf:send submission="s-update-careplan-outcome"/>
                </xf:action>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit encounter!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-encounter-only"
                				   ref="instance('i-encs')/*:Encounter[index('r-encs-id')]"
								   method="put"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/encounters?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit encounter!</xf:message>
        </xf:submission>
        <xf:submission id="s-update-encounter-status"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/encounters/',instance('i-encs')/*:Encounter[index('r-encs-id')]/*:id/@value,'/status/',instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value,'?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update encounter status!</xf:message>
        </xf:submission>
        <xf:submission id="s-update-careteam"
					method="post"
					ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:participant"
					replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/careteams?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;subject=',substring-after(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update careteam!</xf:message>
        </xf:submission>
        <xf:submission id="s-update-order-status"
				   method="post"
				   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/orders/',tokenize(tokenize(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:appointment/*:reference/@value,'\?')[1],'/')[3],'/details/',substring-after(tokenize(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:appointment/*:reference/@value,'\?')[2],'detail='),'?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;status=',instance('i-e-infos')/*:status-e2order/*:code[@e=instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value]/@o)"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update order status!</xf:message>
        </xf:submission>
        <xf:submission id="s-update-careplan-outcome"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/careplans/',substring-after(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:basedOn/*:reference/@value,'nabu/careplans/'),'/actions/',tokenize(tokenize(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:appointment/*:reference/@value,'\?')[1],'/')[3],'?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;outcome=',encode-for-uri(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:text/@value),'&amp;eid=',encode-for-uri(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:id/@value),'&amp;edisp=',encode-for-uri(concat(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:start/@value,': ',instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value)))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update careplan status!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-encs-order"
                				   ref="instance('i-encs')/*:Encounter[index('r-encs-id')]"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/orders?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;reason=',instance('i-wf')/*:event,'&amp;prio=',instance('i-wf')/*:prio,'&amp;prio-display=',instance('i-wf')/*:prio-display,'&amp;deadline=',instance('i-wf')/*:date)"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot reorder!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-openencs-order"
                				   ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/orders?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;reason=',instance('i-wf')/*:event)"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot reorder!</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>15</length>
                <uid>{$uid}</uid>
                <group></group>
                <sched/>
                <patient/>
                <rangeStart>{$date}</rangeStart>
                <rangeEnd>{$date}</rangeEnd>
                { $status }
                <_sort>date:asc</_sort>
                <date>{$date}</date>
            </parameters>
        </xf:instance>
        <xf:bind ref="instance('i-search')/*:date" type="xs:date"/>

        <xf:instance xmlns="" id="i-services">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-services"
                				   instance="i-services"
								   method="get"
								   replace="instance">
			<xf:resource value="concat('{$enc-day:restxq-metis-roles}','?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;type=service')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get services!</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-users">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-users"
                	instance="i-users"
					method="get"
					replace="instance"
					resource="{$enc-day:restxq-metis-users-ref}">
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
        
        <xf:instance xmlns="" id="i-schedules">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-schedules"
                	instance="i-schedules"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$enc-day:restxq-schedules}','?loguid=',encode-for-uri('{$uid}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get schedules!</xf:message>
        </xf:submission>
        
        <xf:instance id="i-e-infos" xmlns="" src="{$enc-day:encounter-infos-uri}"/>
        <xf:instance id="i-o-infos"  xmlns="" src="{$enc-day:order-infos-uri}"/>        
        <xf:instance id="views">
            <data xmlns="">
                <ListNotEmpty/>
                <ListTooLong/>
                <TriggerPrevActive/>
                <TriggerNextActive/>
                <TriggerSaveActive/>
                <EncountersToSelect/>
                <EncounterNew/>
                <EncounterRefresh/>
                <today/>
            </data>
        </xf:instance>

        <xf:bind id="ListNotEmpty"
            ref="instance('views')/*:ListNotEmpty"
            readonly="count(instance('i-encs')/*:Encounter) &lt; 1"/>
        <xf:bind id="ListTooLong"
            ref="instance('views')/*:ListTooLong"
            readonly="instance('i-encs')/length &gt; instance('i-encs')/count"/>
        <xf:bind id="TriggerPrevActive"
            ref="instance('views')/*:TriggerPrevActive"
            readonly="(instance('i-encs')/start &lt; 2) or (instance('i-encs')/length &gt; instance('i-encs')/start)"/>
        <xf:bind id="TriggerNextActive"
            ref="instance('views')/*:TriggerNextActive"
            readonly="instance('i-encs')/*:start &gt; (instance('i-encs')/*:count - instance('i-encs')/*:length)"/>
        <xf:bind id="EncountersToSelect"
            ref="instance('views')/*:EncountersToSelect"
            relevant="count(instance('i-encs')/*:Encounter) &gt; 0"/>
        <xf:bind id="EncounterNew"
            ref="instance('views')/*:EncounterNew"
            relevant="count(instance('i-encs')/*:Encounter) = 0"/>
        <xf:bind id="EncountersRefresh"
            ref="instance('views')/*:EncountersRefresh"
            relevant="instance('i-wf')/*:dirty = 'false'"/>
        <xf:bind id="today"
            ref="instance('views')/*:today"
            relevant="instance('i-search')/*:date = adjust-date-to-timezone(current-date())"/>

        <xf:instance xmlns="" id="i-dateTime">
            <data>
                <date></date>
                <starttime></starttime>
                <endtime></endtime>
                <duration></duration>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-dateTime')/*:date" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:starttime" type="xs:time"/>
        <xf:bind ref="instance('i-dateTime')/*:endtime" type="xs:time"/>
        <xf:bind id="dur"   ref="instance('i-dateTime')/*:duration" constraint=". &gt; 0"/>
        
        <xf:instance id="i-wf">
            <data xmlns="">
                <event></event>
                <reorder>true</reorder>
                <dirty>false</dirty>
                <prio>high</prio>
                <prio-display>dringend</prio-display>
                <date>{adjust-date-to-timezone(current-date())}</date>
            </data>
        </xf:instance>
        
        <xf:instance id="i-openencs">
            <data xmlns=""/>
        </xf:instance>
        <xf:submission id="s-get-openencs"
                	instance="i-openencs"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$enc-day:restxq-encounters}','?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;length=15&amp;uid=',encode-for-uri('{$uid}'),'&amp;rangeStart=2017-01-01&amp;rangeEnd=',adjust-date-to-timezone(current-date()-xs:dayTimeDuration('P1D'),()),'&amp;status=planned&amp;status=arrived&amp;status=triaged&amp;status=in-progress&amp;status=tentative')"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:action if="count(instance('i-openencs')/*:Encounter)=0">
                    <xf:toggle case="enc-main"/>
                </xf:action>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">error get-openencs</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-openenc"
                				   ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]"
								   method="put"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/encounters?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:action if="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:status/@value='finished'">
                    <xf:send submission="s-update-careteam-from-openenc"/>
                </xf:action>
                <xf:action if="string-length(instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:basedOn/*:reference/@value)>0">
                    <xf:send submission="s-update-careplan-outcome-from-openenc"/>
                </xf:action>
                <xf:action if="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:status/@value=('finished','cancelled')">
                    <xf:delete ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]"/>
                </xf:action>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit encounter!</xf:message>
        </xf:submission>
        <xf:submission id="s-update-careteam-from-openenc"
					method="post"
					ref="instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:participant"
					replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/careteams?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;subject=',substring-after(instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update careteam (oe)!</xf:message>
        </xf:submission>
        <xf:submission id="s-update-careplan-outcome-from-openenc"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/careplans/',substring-after(instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:basedOn/*:reference/@value,'nabu/careplans/'),'/actions/',tokenize(tokenize(instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:appointment/*:reference/@value,'\?')[1],'/')[3],'?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;outcome=',encode-for-uri(instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:statusHistory[last()]//*:text/@value),'&amp;eid=',encode-for-uri(instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:id/@value),'&amp;edisp=',encode-for-uri(concat(instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:period/*:start/@value,': ',instance('i-openencs')/*:Encounter[index('r-openencs-id')]/*:status/@value)))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update careplan status!</xf:message>
        </xf:submission>
        
        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-openencs"/>            
            <xf:send submission="s-get-encounters"/>
            <xf:send submission="s-get-services"/>
            <xf:send submission="s-get-users"/>
            <xf:send submission="s-get-schedules"/>
        </xf:action>
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
        <xf:input id="subject-id" ref="instance('i-search')/*:patient" class="">
            <xf:label>Patient-ID:</xf:label>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                <xf:setvalue ref="instance('i-search')/*:rangeStart" value="adjust-date-to-timezone(current-date())"/>
                <xf:setvalue ref="instance('i-search')/*:rangeEnd" value="'2021-04-01'"/>
                <xf:send submission="s-get-encounters"/>
            </xf:action>
        </xf:input>
        <xf:input id="app-group" ref="instance('i-search')/*:group" class="">
            <xf:label>Service:</xf:label>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                <xf:send submission="s-get-encounters"/>
            </xf:action>
        </xf:input>           
        <xf:input id="actor-id" ref="instance('i-search')/*:uid" class="">
            <xf:label>Erbringer:</xf:label>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                <xf:send submission="s-get-encounters"/>
            </xf:action>
        </xf:input>
</div>,
<div>
    <xf:switch>
        <xf:case id="enc-open">
            { enc-open:list()}
        </xf:case>
        <xf:case id="enc-main">
            { enc-day:daylist($uid) }
        </xf:case>
        <xf:case id="enc-details">
            { enc-details:details() }
        </xf:case>
    </xf:switch>
</div>
)
};

declare %private function enc-day:daylist($uid as xs:string)
{
<span>
    <h2><xf:output value="choose(instance('i-search')/*:date = adjust-date-to-timezone(current-date()),'Heute','Termine')"/></h2>
    <table class="svTriggerGroup">
        <tr>
            <td colspan="1">
                <xf:input id="enc-date" ref="instance('i-search')/*:date" class="" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'" incremental="true">
                    <xf:label>Datum:</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/*:rangeStart" value="instance('i-search')/*:date"/>
                        <xf:setvalue ref="instance('i-search')/*:rangeEnd" value="instance('i-search')/*:date"/>
                        <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                        <xf:send submission="s-get-encounters"/>
                    </xf:action>
                </xf:input>
            </td><td>
                <xf:select1 ref="instance('i-search')/*:status" class="medium-input" incremental="true">
                    <xf:label>Status</xf:label>
                    <xf:itemset ref="instance('i-e-infos')/*:status-daylist/*:code">
                        <xf:label ref="./@label-ger"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:send submission="s-get-encounters"/>
                    </xf:action>
                </xf:select1>
<!--
            </td><td>
                <label for="subject-hack" class="xfLabel aDefault xfEnabled">Patient:</label>
                <select class="app-select" name="subject-hack">
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="FHIR/Encounter/subject.js"/>
-->
            </td><td>
                <xf:select1 ref="instance('i-search')/*:_sort" class="medium-input" incremental="true">
                    <xf:label>Sortiert nach</xf:label>
                    <xf:itemset ref="instance('i-e-infos')/*:sort/*:code">
                        <xf:label ref="./@label"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:send submission="s-get-encounters"/>
                    </xf:action>
                </xf:select1>
            </td><td colspan="2">
                <label for="service-hack" class="xfLabel aDefault xfEnabled">Service:</label>
                <select class="app-select" name="service-hack">
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="FHIR/Encounter/service.js"/>
            </td><td colspan="2">
                <label for="actor-hack" class="xfLabel aDefault xfEnabled">Erbringer:</label>
                <select class="app-select" name="actor-hack">
                    <option id="-1">{$uid}</option>
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="FHIR/Encounter/actor.js"/>
            </td>
        </tr>
        <tr>
            <td colspan="7"><hr/></td>
        </tr>
    </table>
    <xf:group id="encounters" class="svFullGroup">
        <xf:repeat id="r-encs-id" ref="instance('i-encs')/*:Encounter" appearance="compact" class="svRepeat">
            <xf:output value="concat(format-dateTime(./*:period/*:start/@value, '[H1]:[m01]'),'-',format-dateTime(./*:period/*:end/@value, '[H1]:[m01]'))">
                <xf:label class="svListHeader">Von-Bis:</xf:label>                        
            </xf:output>
            <xf:output value="choose(string-length(./*:partOf/*:display/@value)&gt;0,'*','')" class="xsdBoolean svRepeatBool">
                <xf:label class="svListHeader"><img src="../nabu/resources/images/link.png" alt="Ko?"/></xf:label>
            </xf:output>
            <xf:output value="choose((./*:type/*:coding[*:system/@value='http://hl7.org/fhir/v2/0276']/*:code/@value='NOCM'),'N','')" class="xsdBoolean svRepeatBool">
                <xf:label class="svListHeader"><img src="../nabu/resources/images/link.png" alt="FF?"/></xf:label>
            </xf:output>
            <xf:output ref="./*:subject/*:display/@value">
                <xf:label class="svListHeader">Patient:</xf:label>
            </xf:output>
            <xf:output ref="./*:reasonCode/*:text/@value">
                <xf:label class="svListHeader">Anlass</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant/*:type/*:coding/*:code/@value">
                <xf:label class="svListHeader">Service:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant/*:individual/*:display/@value">
                <xf:label class="svListHeader">Erbringer:</xf:label>                        
            </xf:output>
            <xf:output value="./*:status/@value">
                <xf:label class="svListHeader">Status:</xf:label>                        
            </xf:output>
        </xf:repeat>
    </xf:group>
    <table>
        <tr>
            <td colspan="2">
            <xf:group ref="instance('views')/*:ListTooLong">
                <xf:trigger ref="instance('views')/*:TriggerPrevActive">
                <xf:label>&lt;&lt;</xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start - instance('i-search')/*:length"/>
                    <xf:send submission="s-get-encounters"/>
                </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance('i-encs')/*:start &gt; instance()/*:count),instance()/*:count,instance()/*:start)"/>-
                <xf:output value="choose((instance('i-encs')/*:start + instance()/*:length &gt; instance()/*:count),instance()/*:count,instance()/*:start + instance()/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance('i-encs')/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/*:TriggerNextActive">
                <xf:label>&gt;&gt;</xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start + instance('i-search')/*:length"/>
                    <xf:send submission="s-get-encounters"/>
                </xf:action>
                </xf:trigger>
            </xf:group>
            </td>
            <td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:EncountersToSelect" class="svSaveTrigger">
                    <xf:label>Details</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-dateTime')/*:date"
                            value="tokenize(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:start/@value,'T')[1]"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:starttime"
                            value="tokenize(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:start/@value,'T')[2]"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:endtime"
                            value="tokenize(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:period/*:end/@value,'T')[2]"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:duration"
                            value="(xs:time(instance('i-dateTime')/*:endtime) - xs:time(instance('i-dateTime')/*:starttime)) div xs:dayTimeDuration('PT1M')"/>
                        <xf:toggle case="enc-details"/>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td>
            <td colspan="2">
                <xf:group ref="instance('views')/*:EncountersToSelect">
                    <xf:select1 id="enc-event" ref="instance('i-wf')/*:event" class="" incremental="true">
                        <xf:label>Aktion:</xf:label>
                        <xf:itemset ref="instance('i-e-infos')/*:event-planned/*:code">
                            <xf:label ref="./@label-ger"/>
                            <xf:value ref="./@value"/>
                        </xf:itemset>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:action if="instance('i-wf')/*:event='finished'">
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'true'"/>
                                <xf:insert at="last()"
                                    ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory"
                                    context="instance('i-encs')/*:Encounter[index('r-encs-id')]"
                                    origin="instance('i-e-infos')/*:bricks/*:statusHistory"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]/*:status/@value"
                                    value="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:code/@value"
                                    value="instance('i-wf')/*:event"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]/*:period/*:start/@value"
                                    value="adjust-dateTime-to-timezone(current-dateTime())"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"
                                    value="'finished'"/>
                                <xf:message level="modal">Besuch beendet. Bitte noch Kommentar eingeben (CarePlan Ergebnis!).</xf:message>
                            </xf:action>
                            <xf:action if="instance('i-wf')/*:event=('noshow','cancelled-pat','cancelled-spz')">
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'true'"/>
                                <xf:insert at="last()"
                                    ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory"
                                    context="instance('i-encs')/*:Encounter[index('r-encs-id')]"
                                    origin="instance('i-e-infos')/*:bricks/*:statusHistory"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]/*:status/@value"
                                    value="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:code/@value"
                                    value="instance('i-wf')/*:event"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:text/@value"
                                    value="instance('i-e-infos')/*:event-planned/*:code[@value=instance('i-wf')/*:event]/@label-ger"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]/*:period/*:start/@value"
                                    value="adjust-dateTime-to-timezone(current-dateTime())"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"
                                    value="'cancelled'"/>
                                <xf:message level="modal">Termin cancelled. Bitte noch Kommentar ergänzen (CarePlan Ergebnis!) und gfls. neuen Termin veranlassen.</xf:message>
                            </xf:action>
                            <xf:action if="instance('i-wf')/*:event=('arrived','triaged','in-progress','onleave')">
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"
                                    value="instance('i-wf')/*:event"/>
                                <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                                <xf:send submission="s-update-encounter-status"/>
                                <xf:message level="ephemeral">Status gespeichert</xf:message>
                            </xf:action>
                        </xf:action>
                    </xf:select1>
                </xf:group>
            </td>
            <td colspan="3">
                <xf:trigger ref="instance('i-wf')/*:dirty[.='false']">
                    <xf:label>Liste akt.</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                        <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                        <xf:send submission="s-get-encounters"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td>
                <xf:trigger ref="instance('i-encs')/*:Encounter[index('r-encs-id')]" class="svSaveTrigger">
                    <xf:label>./. Patient</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:load show="new">
                            <xf:resource value="concat('/exist/apps/nabu/index.html?action=listPatients&amp;id=',substring-after(instance('i-encs')/*:Encounter[index('r-encs-id')]/*:subject/*:reference/@value,'nabu/patients/'))"/>
                        </xf:load>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
    <table>
        <tr>
            <td colspan="1">
                <xf:group ref="instance('i-wf')/*:event[.=('finished','noshow','cancelled-pat','cancelled-spz')]">
                <strong>Kommentar:</strong>
                </xf:group>
            </td>
            <td colspan="2">
                <xf:group ref="instance('i-wf')/*:event[.=('finished','noshow','cancelled-pat','cancelled-spz')]">
                        <xf:input ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:text/@value" class="long-input">

                        </xf:input>
                </xf:group>
            </td>
            <td colspan="2">
                <xf:trigger class="svUpdateMasterTrigger" ref="instance('i-wf')/*:event[.='finished']">
                            <xf:label>Fertig</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                                <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                                <xf:send submission="s-submit-encounter"/>
                                <xf:send submission="s-get-encounters"/>
                            </xf:action>
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svUpdateMasterTrigger" ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                            <xf:label>Canceln oWV</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                                <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                                <xf:send submission="s-submit-encounter"/>
                                <xf:send submission="s-get-encounters"/>
                            </xf:action>
                </xf:trigger>
<!--
                <xf:trigger class="svUpdateMasterTrigger" ref="instance('i-wf')/*:event[.='finished']">
                            <xf:label>Abbrechen</xf:label>
                            <xf:action ev:event="DOMActivate">
                                <xf:delete ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]"/>
                            </xf:action>
                </xf:trigger>
-->
            </td>
        </tr>
        <tr>
            <td>
                <xf:group ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                <strong>ReOrder</strong>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                    <xf:select1 ref="instance('i-wf')/*:prio">
                        <xf:itemset nodeset="instance('i-o-infos')/*:when/*:code">
                            <xf:label ref="./@label-de"/>
                            <xf:value ref="./@value"/>
                        </xf:itemset>
                        <xf:action if="instance('i-wf')/*:prio = ''">
                                <xf:setvalue ref="instance('i-wf')/*:prio-display" value="'urgent'"/>
                        </xf:action>
                        <xf:action>
                                <xf:setvalue ref="instance('i-wf')/*:prio-display" 
                                  value="instance('i-o-infos')/*:when/*:code[@value=instance('i-wf')/*prio]/@label-de"/>
                            </xf:action>
                    </xf:select1>
                </xf:group>
            </td>
            <td>
                <xf:group ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                    <xf:input ref="instance('i-wf')/*:date" class="medium-input"></xf:input>
                </xf:group>
            </td>
            <td>
                <xf:trigger class="svUpdateMasterTrigger" ref="instance('i-wf')/*:event[.=('noshow','cancelled-pat','cancelled-spz')]">
                    <xf:label>ReOrder</xf:label>
                    <xf:action ev:event="DOMActivate">
                            <xf:send submission="s-submit-encs-order"/>
                                <xf:insert at="last()"
                                    ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory"
                                    context="instance('i-encs')/*:Encounter[index('r-encs-id')]"
                                    origin="instance('i-e-infos')/*:bricks/*:statusHistory"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]/*:status/@value"
                                    value="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:status/@value"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:code/@value"
                                    value="instance('i-wf')/*:event"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]//*:text/@value"
                                    value="'Termin reordered'"/>
                                <xf:setvalue ref="instance('i-encs')/*:Encounter[index('r-encs-id')]/*:statusHistory[last()]/*:period/*:start/@value"
                                    value="adjust-dateTime-to-timezone(current-dateTime())"/>
                                <xf:setvalue ref="instance('i-wf')/*:dirty" value="'false'"/>
                                <xf:setvalue ref="instance('i-wf')/*:event" value="''"/>
                                <xf:send submission="s-submit-encounter"/>
                                <xf:send submission="s-get-encounters"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</span>
};
