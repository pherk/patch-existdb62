xquery version "3.0";
(:~
 : functionality and XFORMS for Appointments
 : 
 : @author Peter Herkenrath
 : @version 0.6
 : 2014-11-16
 :)
module namespace appointment="http://enahar.org/exist/apps/nabu/appointment";

import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";

import module namespace user   = "http://enahar.org/exist/apps/metis/user"      at "/db/apps/metis/FHIR/user/user.xqm";
import module namespace r-user = "http://enahar.org/exist/restxq/metis/users"   at "/db/apps/metis/FHIR/user/user-routes.xqm";

import module namespace r-appointment = "http://enahar.org/exist/restxq/nabu/appointments"   at "../Appointment/appointment-routes.xqm";

declare namespace ev  = "http://www.w3.org/2001/xml-events";
declare namespace xf  = "http://www.w3.org/2002/xforms";
declare namespace xmldb = "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

(:~
 : show appointment functionality for dashboard
 : 
 : @param $uid user id
 : @return html
 :)
declare function appointment:showFunctions()
{
    let $date := adjust-date-to-timezone(current-date(), ())
    return
    <ul>
        <li>
            <a href="index.html?action=listAppointments">Tagesliste</a>, <a href="index.html?action=viewCalendar">Kalender</a>, 
            <a href="index.html?action=acceptAppointments">Anfragen</a>
        </li>
    </ul>
};

declare %private function appointment:appointmentsToRows($appointments)
{
    for $a in $appointments/fhir:Appointment
    let $aid   := $a/fhir:id/@value/string()
    let $start := format-dateTime(xs:dateTime($a/fhir:start/@value), "[H1]:[m01]")
    let $end   := format-dateTime(xs:dateTime($a/fhir:end/@value), "[H1]:[m01]")
    let $subject := $a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value ='patient']/fhir:actor/fhir:display/@value/string()
    let $service := $a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value!='patient']/fhir:type/fhir:coding/fhir:code/@value/string()
    let $provider:= $a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value!='patient']/fhir:actor/fhir:display/@value/string()
    let $status  := $a/fhir:status/@value/string()
    order by $a/fhir:start/@value/string()
    return
         <tr id="{$aid}">
            <td>{format-date(xs:date(tokenize($a/fhir:start/@value/string(),'T')[1]),"[D01]-[M01]-[Y01]")}</td>
            <td>{$status}</td>
            <td>{$start}</td>
            <td>{$end}</td>
            <td>{$subject}</td>
            <td>{$a/fhir:description/@value/string()}</td>
            <td>{$service}</td>
            <td>{$provider}</td>
         </tr> 
};

(:~
 : show appointments
 : 
 : @param $status (pending, all, extra)
 : @return html
 :)
declare function appointment:listAppointmentsJQuery($status as xs:string?, $filter as xs:string?)
{
    let $status := ($status, 'booked')[1]
    let $filter := adjust-date-to-timezone(($filter, current-date())[1], ())
    let $logu   := r-user:userByAlias(xmldb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $group  := 'spz-arzt'
    let $myAppointments := r-appointment:appointmentsXML(
                            'kikl-spz', $loguid,
                            '1', '*',
                            $loguid, $group, '',
                            '',
                            $filter, $filter,
                            $status,
                            'date:asc')
    let $head  := switch ($status) 
        case "booked"  return 'Termine' 
        case "tentative" return "Terminanfragen"
        case "extra"   return "Sondertermine"
        default return '??? Fehler'
    let $count := xs:integer($myAppointments/count/string())
    let $date := $filter
return
<div>
    { if ($count>0)
        then 
        (

        <div class="container">
            <div class="row">
                <div class="col-sm-1">{concat('#', $count)}</div>
                <div class='col-sm-2'>
                    <div class="form-group">
                        <div class="input-group date" id="dp3">
                            <input type="text" class="form-control" value="{$date}"/>
                            <div class="input-group-addon">
                                <span class="glyphicon glyphicon-th"></span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    ,   <table id="openappointments" class="tablesorter">
                <thead>
                    <tr id="0">
                        <th data-value="{format-date($filter,"[D01]-[M01]-[Y01]")}">Datum</th>
                        <th>Status</th>
                        <th>Von</th>
                        <th>Bis</th>
                        <th>Subject</th>
                        <th>Anlass</th>
                        <th>Service</th>
                        <th>Erbringer</th>
                    </tr>
                </thead>
                <tbody>
                {
                    appointment:appointmentsToRows($myAppointments)
                }
                </tbody>
            </table>
        )
        else <h2>Keine {$head} am {$date}</h2>
    }
    <script type="text/javascript" defer="defer" src="FHIR/Appointment/listAppointments.js"/>
</div>
};


declare variable $appointment:restxq-metis-users  := "/exist/restxq/metis/users";
declare variable $appointment:restxq-metis-users-ref  := "/exist/restxq/metis/users?_format=ref";
declare variable $appointment:restxq-metis-roles  := "/exist/restxq/metis/roles";
declare variable $appointment:restxq-metis-orgas  := "/exist/restxq/metis/organizations";
declare variable $appointment:restxq-metis-realms := "/exist/restxq/metis/realms";

declare variable $appointment:restxq-appointments          := "/exist/restxq/nabu/appointments";
declare variable $appointment:restxq-encounters            := "/exist/restxq/nabu/encounters";
declare variable $appointment:restxq-orders                := "/exist/restxq/nabu/app2order";
declare variable $appointment:restxq-appslist              := "/exist/restxq/nabu/apps2pdf";
declare variable $appointment:restxq-appointment-template  := "/exist/restxq/nabu/appointments/templates/new";
declare variable $appointment:restxq-schedules             := "/exist/restxq/enahar/schedules";
declare variable $appointment:restxq-orphans               := "/exist/restxq/nabu/orphans";

declare variable $appointment:appointment-infos-uri        := "/exist/apps/nabu/FHIR/Appointment/appointment-infos.xml";

declare %private function appointment:formatFHIRName($logu)
{
    string-join(
        (
              string-join($logu/fhir:name[fhir:use/@value='official']/fhir:family/@value, '')
            , $logu/fhir:name[fhir:use/@value='official']/fhir:given/@value
        ), ', ')
};

(:~
 : show appointments in fullcalendar
 : 
 : @return html
 :)
declare function appointment:view()
{
    let $status := 
        (
            <status>booked</status>
        ,   <status>arrived</status>
        ,   <status>registered</status>
(:      ,   <status>cancelled</status> :)
        ,   <status>noshow</status>
        )
    let $date   := adjust-date-to-timezone(current-date(),())
    let $logu   := r-user:userByAlias(xmldb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $lognam:= appointment:formatFHIRName($logu)
    let $group  := 'spz-arzt'
    let $realm := "kikl-spz"
    let $head  := 'Termine' 
return
<div>
   <h2>Termin-Kalender</h2>
    <table class="svTriggerGroup">
        <tr>
            <td colspan="2">
                <label for="service-hack" class="">Service:</label>
                <select class="app-select" name="service-hack">
                    <option></option>
                </select>
            </td><td colspan="2">
                <label for="actor-hack" class="">Erbringer:</label>
                <select class="app-select" name="actor-hack">
                    <option value="{$loguid}">{$lognam}</option>
                </select>
            </td>
        </tr>
        <tr>
            <td colspan="7"><div class="divider"></div></td>
        </tr>
    </table>
    <div id="calendar"></div>
    <script type="text/javascript" defer="defer" src="FHIR/Appointment/viewapps.js"/>
</div>
};

(:~
 : show appointments
 : 
 : @return html
 :)
declare function appointment:list()
{
    let $status := 
        (
            <status>booked</status>
        ,   <status>arrived</status>
        ,   <status>registered</status>
(:      ,   <status>cancelled</status> :)
        ,   <status>noshow</status>
        )
    let $date   := adjust-date-to-timezone(current-date(),())
    let $logu   := r-user:userByAlias(xmldb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $lognam:= appointment:formatFHIRName($logu)
    let $group  := 'spz-arzt'
    let $realm := "kikl-spz"
    let $head  := 'Termine' 
return
(<div style="display:none;">
    <xf:model id="m-appointment" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance  xmlns="" id="i-apps">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-appointments"
                    ref="instance('i-search')"
                	instance="i-apps"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$appointment:restxq-appointments}','?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">error get-appointments</xf:message>
        </xf:submission>
        <xf:submission id="s-get-appslist"
                    ref="instance('i-search')"
                	instance="i-apps"
					method="get"
					replace="none">
			<xf:resource value="concat('{$appointment:restxq-appslist}','?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:setvalue ref="instance('i-search')/*:_sort" value="'date:asc'"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">error get-archiv</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-appointment"
                				   ref="instance('i-apps')/*:Appointment[index('r-apps-id')]"
								   method="put"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/appointments?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit appointment!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-encounter"
                				   ref="instance('i-apps')/*:Appointment[index('r-apps-id')]"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/encounters?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot post appointment (submit encounter)!</xf:message>
        </xf:submission>
        <xf:submission id="s-submit-order"
                				   ref="instance('i-apps')/*:Appointment[index('r-apps-id')]"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/orders?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot post appointment!</xf:message>
        </xf:submission>

        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>15</length>
                <uid>{$loguid}</uid>
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
			<xf:resource value="concat('{$appointment:restxq-metis-roles}','?filter=service&amp;loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
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
					resource="{$appointment:restxq-metis-users-ref}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{$loguid}</xf:value>
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
			<xf:resource value="concat('{$appointment:restxq-schedules}','?length=*&amp;loguid=',encode-for-uri('{$loguid}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get schedules!</xf:message>
        </xf:submission>
        
        <xf:instance id="i-ainfos" xmlns="" src="{$appointment:appointment-infos-uri}"/>
        
        <xf:instance id="views">
            <data xmlns="">
                <ListNotEmpty/>
                <ListTooLong/>
                <TriggerPrevActive/>
                <TriggerNextActive/>
                <TriggerSaveActive/>
                <AppointmentsToSelect/>
                <AppointmentNew/>
                <today/>
            </data>
        </xf:instance>

        <xf:bind id="ListNotEmpty"
            ref="instance('views')/*:ListNotEmpty"
            readonly="count(instance('i-apps')/*:Appointment) &lt; 1"/>
        <xf:bind id="ListTooLong"
            ref="instance('views')/*:ListTooLong"
            readonly="instance('i-apps')/length &gt; instance('i-apps')/count"/>
        <xf:bind id="TriggerPrevActive"
            ref="instance('views')/*:TriggerPrevActive"
            readonly="(instance('i-apps')/start &lt; 2) or (instance('i-apps')/length &gt; instance('i-apps')/start)"/>
        <xf:bind id="TriggerNextActive"
            ref="instance('views')/*:TriggerNextActive"
            readonly="instance('i-apps')/*:start &gt; (instance('i-apps')/*:count - instance('i-apps')/*:length)"/>
        <xf:bind id="AppointmentsToSelect"
            ref="instance('views')/*:AppointmentsToSelect"
            relevant="count(instance('i-apps')/*:Appointment) &gt; 0"/>
        <xf:bind id="AppointmentNew"
            ref="instance('views')/*:AppointmentNew"
            relevant="count(instance('i-apps')/*:Appointment) = 0"/>
        <xf:bind id="today"
            ref="instance('views')/*:today"
            relevant="instance('i-search')/*:date = adjust-date-to-timezone(current-date(),())"/>

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
            
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-appointments"/>
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
                <xf:setvalue ref="instance('i-search')/*:rangeStart" value="adjust-date-to-timezone(current-date(),())"/>
                <xf:setvalue ref="instance('i-search')/*:rangeEnd" value="'2021-04-01'"/>
                <xf:send submission="s-get-appointments"/>
            </xf:action>
        </xf:input>
        <xf:input id="app-group" ref="instance('i-search')/*:group" class="">
            <xf:label>Service:</xf:label>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                <xf:send submission="s-get-appointments"/>
            </xf:action>
        </xf:input>           
        <xf:input id="actor-id" ref="instance('i-search')/*:uid" class="">
            <xf:label>Erbringer:</xf:label>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                <xf:send submission="s-get-appointments"/>
            </xf:action>
        </xf:input>
</div>,
<div>
    <xf:switch>
        <xf:case id="app-main">
            { appointment:daylist($lognam) }
        </xf:case>
        <xf:case id="app-details">
            { appointment:details() }
        </xf:case>
    </xf:switch>
</div>
)
};

declare %private function appointment:daylist($lognam as xs:string)
{
<span>
    <h2><xf:output value="choose(instance('i-search')/*:date = adjust-date-to-timezone(current-date(),()),'Heute','Termine')"/></h2>
    <table class="svTriggerGroup">
        <tr>
            <td colspan="1">
                <xf:input id="app-date" ref="instance('i-search')/*:date" class="" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'" incremental="true">
                    <xf:label>Datum:</xf:label>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-search')/*:rangeStart" value="instance('i-search')/*:date"/>
                        <xf:setvalue ref="instance('i-search')/*:rangeEnd" value="instance('i-search')/*:date"/>
                        <xf:setvalue ref="instance('i-search')/*:start" value="'1'"/>
                        <xf:send submission="s-get-appointments"/>
                    </xf:action>
                </xf:input>
            </td><td>
                <xf:select1 ref="instance('i-search')/*:status" class="medium-input" incremental="true">
                    <xf:label>Status</xf:label>
                    <xf:itemset ref="instance('i-ainfos')/status/code">
                        <xf:label ref="./@label"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:send submission="s-get-appointments"/>
                    </xf:action>
                </xf:select1>
<!--
            </td><td>
                <label for="subject-hack" class="xfLabel aDefault xfEnabled">Patient:</label>
                <select class="app-select" name="subject-hack">
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="FHIR/Appointment/subject.js"/>
-->
            </td><td>
                <xf:select1 ref="instance('i-search')/*:_sort" class="medium-input" incremental="true">
                    <xf:label>Sortiert nach</xf:label>
                    <xf:itemset ref="instance('i-ainfos')/sort/code">
                        <xf:label ref="./@label"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:send submission="s-get-appointments"/>
                    </xf:action>
                </xf:select1>
            </td><td colspan="2">
                <label for="service-hack" class="xfLabel aDefault xfEnabled">Service:</label>
                <select class="app-select" name="service-hack">
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="FHIR/Appointment/service.js"/>
            </td><td colspan="2">
                <label for="actor-hack" class="xfLabel aDefault xfEnabled">Erbringer:</label>
                <select class="app-select" name="actor-hack">
                    <option id="-1">{$lognam}</option>
                    <option></option>
                </select>
                <script type="text/javascript" defer="defer" src="FHIR/Appointment/actor.js"/>
            </td>
        </tr>
        <tr>
            <td colspan="7"><div class="divider"></div></td>
        </tr>
    </table>
    <xf:group id="appointments" class="svFullGroup">
        <xf:repeat id="r-apps-id" ref="instance('i-apps')/*:Appointment" appearance="compact" class="svRepeat">
            <xf:output value="concat(format-dateTime(./*:start/@value, '[H1]:[m01]'),'-',format-dateTime(./*:end/@value, '[H1]:[m01]'))">
                <xf:label class="svListHeader">Von-Bis:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant[*:type//*:code/@value='patient']/*:actor/*:display/@value">
                <xf:label class="svListHeader">Patient:</xf:label>
            </xf:output>
            <xf:output ref="./*:reason/*:text/@value">
                <xf:label class="svListHeader">Anlass</xf:label>                        
            </xf:output>
            <xf:output ref="./*:description/@value">
                <xf:label class="svListHeader">Info</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant[*:type//*:code/@value!='patient']/*:type/*:coding/*:code/@value">
                <xf:label class="svListHeader">Service:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant[*:type//*:code/@value!='patient']/*:actor/*:display/@value">
                <xf:label class="svListHeader">Erbringer:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:status/@value">
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
                    <xf:send submission="s-get-appointments"/>
                </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance('i-apps')/*:start &gt; instance()/*:count),instance()/*:count,instance()/*:start)"/>-
                <xf:output value="choose((instance('i-apps')/*:start + instance()/*:length &gt; instance()/*:count),instance()/*:count,instance()/*:start + instance()/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance('i-apps')/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/*:TriggerNextActive">
                <xf:label>&gt;&gt;</xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start + instance('i-search')/*:length"/>
                    <xf:send submission="s-get-appointments"/>
                </xf:action>
                </xf:trigger>
            </xf:group>
            </td><td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:AppointmentsToSelect" class="svSaveTrigger">
                    <xf:label>Bearbeiten</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:setvalue ref="instance('i-dateTime')/*:date"
                            value="tokenize(instance('i-apps')/*:Appointment[index('r-apps-id')]/*:start/@value,'T')[1]"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:starttime"
                            value="tokenize(instance('i-apps')/*:Appointment[index('r-apps-id')]/*:start/@value,'T')[2]"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:endtime"
                            value="tokenize(instance('i-apps')/*:Appointment[index('r-apps-id')]/*:end/@value,'T')[2]"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:duration"
                            value="(xs:time(instance('i-dateTime')/*:endtime) - xs:time(instance('i-dateTime')/*:starttime)) div xs:dayTimeDuration('PT1M')"/>
                        <xf:toggle case="app-details"/>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td><td>
                <xf:group>
                    <xf:group ref="instance('views')/*:AppointmentsToSelect">
                    <xf:select1 id="app-status" ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value"
                            class="">
                        <xf:label>Status:</xf:label>
                        <xf:itemset ref="instance('i-ainfos')/*:status/*:code">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                        </xf:itemset>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:action if="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value='fulfilled'">
                                <xf:message level="ephemeral">Besuch beendet</xf:message>
                                <xf:send submission="s-submit-encounter"/>
                            </xf:action>
                            <xf:action if="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value='reorder'">
                                <xf:message level="ephemeral">Neue Anforderung</xf:message>
                                <xf:setvalue ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value"
                                    value="'cancelled'"/>
                                <xf:send submission="s-submit-order"/>
                            </xf:action>
                            <xf:message level="ephemeral">Status gespeichert</xf:message>
                            <xf:send submission="s-submit-appointment"/>
                        </xf:action>
                    </xf:select1>
                    </xf:group>
                </xf:group>
            </td><td>
                <div> - </div>
            </td><td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:AppointmentsToSelect">
                    <xf:label>Aktualisieren</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-get-appointments"/>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td>
        </tr>
    </table>
</span>
};

declare %private function appointment:details()
{
<span>
    <h2>Termin für <xf:output ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type//*:code/@value='patient']/*:actor/*:display/@value"></xf:output></h2>
    <table>
        <tr>
            <td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:AppointmentsToSelect" class="svUpdateMasterTrigger">
                    <xf:label>./. Tagesliste</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:toggle case="app-main"/>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td><td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:AppointmentsToSelect" class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-appointment"/>
                        <xf:message level="ephemeral">Termin gespeichert</xf:message>
                    </xf:action>
                    <xf:action ev:event="DOMActivate"
                        if="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value='fulfilled'">
                            <xf:message level="ephemeral">Besuch beendet</xf:message>
                            <xf:send submission="s-submit-encounter"/>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td><td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:AppointmentsToSelect" class="svAddTrigger">
                    <xf:label>(Neuer Termin)</xf:label>
                    <xf:action ev:event="DOMActivate">
<!--
                        <xf:send submission="s-submit-order"/>
-->
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td>
        </tr>                    
    </table>
    <div class="divider"></div>
    <xf:group ref="instance('i-apps')/*:Appointment[index('r-apps-id')]">
            <xf:textarea id="app-reason" ref="./*:reason/*:coding/*:display/@value" class="fullareashort">
                <xf:label>Anlass:</xf:label>
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue
                        ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:reason/*:text/@value"
                        value="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:reason/*:coding/*:display/@value"/>
                </xf:action>
            </xf:textarea>
            <xf:textarea id="app-desc" ref="./*:description/@value" class="fullareashort">
                <xf:label>Beschreibung:</xf:label>
            </xf:textarea>
            <xf:textarea id="app-comment" ref="./*:comment/@value" class="fullareashort">
                <xf:label>TerminInfo:</xf:label>
            </xf:textarea>
            <div><h4>Bereich - Rolle - Erbringer</h4>
            <xf:repeat id="r-actors-id" ref="." appearance="compact" class="svRepeat">
                <xf:output ref="./*:type/*:text/@value">
                    <xf:label class="svRepeatHeader">Bereich</xf:label>
                </xf:output>
                <xf:output ref="./*:participant[*:type/*:coding/*:code/@value!='patient']/*:type/*:coding/*:code/@value">
                    <xf:label class="svRepeatHeader">Rolle</xf:label>
                </xf:output>
                <xf:output ref="./*:participant[*:type/*:coding/*:code/@value!='patient']/*:actor/*:display/@value">
                    <xf:label class="svRepeatHeader">Name</xf:label>
                </xf:output>
            </xf:repeat>
            </div>
    </xf:group>
    <table>
        <tr>
            <td>
                <xf:select1 ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:type/*:coding/*:code/@value" class="" incremental="true">
                    <xf:label class="svListHeader">Anlass:</xf:label> 
                    <xf:itemset nodeset="instance('i-schedules')/*:schedule">
                        <xf:label ref="./*:name/@value"/>
                        <xf:value ref="./*:id/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue
                            ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:type/*:coding/*:display/@value"
                            value="instance('i-schedules')/*:schedule[./*:id/@value=instance('i-apps')/*:Appointment[index('r-apps-id')]/*:type/*:coding/*:code/@value]/*:name/@value"/>
                        <xf:setvalue
                            ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:type/*:text/@value"
                            value="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:type/*:coding/*:display/@value"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr>
        <tr>
            <td>
                <xf:select1 ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type/*:coding/*:code/@value!='patient'][index('r-actors-id')]/*:type/*:coding/*:code/@value" class="" incremental="true">
                    <xf:label class="svListHeader">Rolle:</xf:label> 
                    <xf:itemset nodeset="instance('i-services')/*:Group">
                        <xf:label ref="./*:name/@value"/>
                        <xf:value ref="./*:code/*:text/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue
                            ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type/*:coding/*:code/@value!='patient'][index('r-actors-id')]/*:type/*:coding/*:display/@value"
                            value="instance('i-services')/*:Group[./*:code/*:text/@value=instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type/*:coding/*:code/@value!='patient'][index('r-actors-id')]/*:type/*:coding/*:code/@value]/*:name/@value"/>
                        <xf:setvalue
                            ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type/*:coding/*:code/@value!='patient'][index('r-actors-id')]/*:type/*:text/@value"
                            value="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type/*:coding/*:code/@value!='patient'][index('r-actors-id')]/*:type/*:coding/*:display/@value"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr>
        <tr>
            <td>
                <xf:select1 ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type/*:coding/*:code/@value!='patient'][index('r-actors-id')]/*:actor/*:reference/@value" class="" incremental="true">
                    <xf:label class="svListHeader">Erbringer:</xf:label> 
                    <xf:itemset nodeset="instance('i-users')/*:user">
                        <xf:label ref="./*:display/@value"/>
                        <xf:value ref="./*:reference/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue
                            ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type/*:coding/*:code/@value!='patient'][index('r-actors-id')]/*:actor/*:display/@value"
                            value="instance('i-users')/*:user[./*:reference/@value=instance('i-apps')/*:Appointment[index('r-apps-id')]/*:participant[*:type/*:coding/*:code/@value!='patient'][index('r-actors-id')]/*:actor/*:reference/@value]/*:display/@value"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr><tr>
            <td>
                <xf:output ref="instance('i-dateTime')/*:date">
                    <xf:label class="svListHeader">Datum:</xf:label>
                </xf:output>
                <xf:input ref="instance('i-dateTime')/*:duration" class="medium-input">
                    <xf:label class="svListHeader">Dauer (min):</xf:label>
                </xf:input>
            </td>
        </tr><tr>
            <td>
                <xf:select1 ref="instance('i-dateTime')/*:starttime" class="medium-input">
                    <xf:label class="svListHeader">Von:</xf:label>
                    <xf:itemset ref="instance('i-ainfos')/*:time/*:code">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                    </xf:itemset>  
                    <xf:action ev:event="xforms-value-changed">
                        <xf:action if="instance('i-dateTime')/*:startTime =''">
                            <xf:setvalue ref="instance('i-dateTime')/*:startTime" value="'08:00:00'"/>
                        </xf:action>
                        <xf:setvalue ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:start/@value"
                            value="concat(instance('i-dateTime')/*:date,'T',instance('i-dateTime')/*:starttime)"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:duration"
                            value="(xs:time(instance('i-dateTime')/*:endtime) - xs:time(instance('i-dateTime')/*:starttime)) div xs:dayTimeDuration('PT1M')"/>
                    </xf:action>
                </xf:select1>
                <xf:select1 ref="instance('i-dateTime')/*:endtime" class="medium-input">
                    <xf:label class="svListHeader">Bis:</xf:label>
                    <xf:itemset ref="instance('i-ainfos')/*:time/*:code">
                            <xf:label ref="./@label"/>
                            <xf:value ref="./@value"/>
                    </xf:itemset>      
                    <xf:action ev:event="xforms-value-changed">
                        <xf:action if="instance('i-dateTime')/*:endTime =''">
                            <xf:setvalue ref="instance('i-dateTime')/*:endTime" value="'17:00:00'"/>
                        </xf:action>
                        <xf:setvalue ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:end/@value"
                            value="concat(instance('i-dateTime')/*:date,'T',instance('i-dateTime')/*:endtime)"/>
                        <xf:setvalue ref="instance('i-dateTime')/*:duration"
                            value="(xs:time(instance('i-dateTime')/*:endtime) - xs:time(instance('i-dateTime')/*:starttime)) div xs:dayTimeDuration('PT1M')"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr><tr>
            <td>
                <xf:select1 id="detail-status" ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value"
                        class="medium-input">
                    <xf:label>Status:</xf:label>
                    <xf:itemset ref="instance('i-ainfos')/*:status/*:code">
                        <xf:label ref="./@label"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                </xf:select1>
            </td>
        </tr>
    </table>
</span>
};
(:~
 : show tentative appointments
 : 
 : @return html
 :)
declare function appointment:accept()
{
    let $status := <status>tentative</status>
    let $date   := adjust-date-to-timezone(current-date(),())
    let $start  := dateTime($date,xs:time("08:00:00"))
    let $end    := $start + xs:yearMonthDuration("P1Y")
    let $logu   := r-user:userByAlias(xmldb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $lognam := appointment:formatFHIRName($logu)
    let $group  := 'spz-arzt'
    let $realm  := "kikl-spz"
    let $head   := 'Termin-Anfragen' 
return
(<div style="display:none;">
    <xf:model id="m-appointment" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance  xmlns="" id="i-apps">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-appointments"
                    ref="instance('i-search')"
                	instance="i-apps"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$appointment:restxq-appointments}?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">error get-appointments</xf:message>
        </xf:submission>

        <xf:submission id="s-submit-appointment"
                				   ref="instance('i-apps')/*:Appointment[index('r-apps-id')]"
								   method="put"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/appointments?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit appointment!</xf:message>
        </xf:submission>
        
        <xf:submission id="s-update-app"
                    ref="instance('i-apps')/*:Appointment[index('r-apps-id')]"
					method="post"
					replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/appointments?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update appointment!</xf:message>
        </xf:submission>

        <xf:submission id="s-reopen-order"
                    ref="instance('i-apps')/*:Appointment[index('r-apps-id')]"
					method="post"
					replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/orders?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot clone order!</xf:message>
        </xf:submission>

        
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>15</length>
                <uid>{$loguid}</uid>
                <group></group>
                <sched/>
                <patient/>
                <rangeStart>{$start}</rangeStart>
                <rangeEnd>{$end}</rangeEnd>
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
								   replace="instance"
								   resource="{concat($appointment:restxq-metis-roles,'?filter=service')}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $loguid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot get services!</xf:message>
        </xf:submission>

        <xf:instance id="i-ainfos" xmlns="" src="{$appointment:appointment-infos-uri}"/>
        
        <xf:instance id="views">
            <data xmlns="">
                <ListNotEmpty/>
                <ListTooLong/>
                <TriggerPrevActive/>
                <TriggerNextActive/>
                <TriggerSaveActive/>
                <AppointmentsToSelect/>
                <AppointmentNew/>
                <today/>
            </data>
        </xf:instance>

        <xf:bind id="ListNotEmpty"
            ref="instance('views')/*:ListNotEmpty"
            readonly="count(instance('i-apps')/*:Appointment) &lt; 1"/>
        <xf:bind id="ListTooLong"
            ref="instance('views')/*:ListTooLong"
            readonly="instance('i-apps')/length &gt; instance('i-apps')/count"/>
        <xf:bind id="TriggerPrevActive"
            ref="instance('views')/*:TriggerPrevActive"
            readonly="(instance('i-apps')/start &lt; 2) or (instance('i-apps')/length &gt; instance('i-apps')/start)"/>
        <xf:bind id="TriggerNextActive"
            ref="instance('views')/*:TriggerNextActive"
            readonly="instance('i-apps')/*:start &gt; (instance('i-apps')/*:count - instance('i-apps')/*:length)"/>
        <xf:bind id="AppointmentsToSelect"
            ref="instance('views')/*:AppointmentsToSelect"
            relevant="count(instance('i-apps')/*:Appointment) &gt; 0"/>
        <xf:bind id="AppointmentNew"
            ref="instance('views')/*:AppointmentNew"
            relevant="count(instance('i-apps')/*:Appointment) = 0"/>
        <xf:bind id="today"
            ref="instance('views')/*:today"
            relevant="instance('i-search')/*:date = adjust-date-to-timezone(current-date(),())"/>
 
        <xf:action ev:event="xforms-ready">
            <xf:send submission="s-get-appointments"/>

            <xf:send submission="s-get-services"/>

        </xf:action>
    </xf:model>
</div>,
<div>
    <h2>{$head}</h2>
    <table class="svTriggerGroup">
        <tr>
            <td colspan="1">
                <xf:select1 ref="instance('i-search')/*:_sort" class="medium-input" incremental="true">
                    <xf:label>Sortiert nach</xf:label>
                    <xf:itemset ref="instance('i-ainfos')/sort/code">
                        <xf:label ref="./@label"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:send submission="s-get-appointments"/>
                    </xf:action>
                </xf:select1>
            </td>
        </tr>
        <tr>
            <td colspan="7"><div class="divider"></div></td>
        </tr>
    </table>
        <xf:group id="appointments" class="svFullGroup">
                <xf:repeat id="r-apps-id" ref="instance('i-apps')/*:Appointment" appearance="compact" class="svRepeat">
                    <xf:output value="format-dateTime(./*:start/@value, '[Y0001]-[M01]-[D01]')">
                        <xf:label class="svListHeader">Datum/media/:</xf:label>                        
                    </xf:output>
                    <xf:output value="concat(format-dateTime(./*:start/@value, '[H1]:[m01]'),'-',format-dateTime(./*:end/@value, '[H1]:[m01]'))">
                        <xf:label class="svListHeader">Von-Bis:</xf:label>                        
                    </xf:output>
                    <xf:output ref="./*:participant[*:type//*:code/@value='patient']/*:actor/*:display/@value">
                        <xf:label class="svListHeader">Patient:</xf:label>
                    </xf:output>
                    <xf:output ref="./*:description/@value">
                        <xf:label class="svListHeader">Anlass</xf:label>                        
                    </xf:output>
                    <xf:output ref="./*:participant[*:type//*:code/@value!='patient']/*:actor/*:role/@value">
                        <xf:label class="svListHeader">Service:</xf:label>                        
                    </xf:output>
                    <xf:output ref="./*:status/@value">
                        <xf:label class="svListHeader">Status:</xf:label>                        
                    </xf:output>
                    <xf:trigger>
                        <xf:label class="svSubTrigger">Bearbeiten</xf:label>
                        <xf:toggle case="EditOrphan" ev:event="DOMActivate"/>
                    </xf:trigger>
                    <xf:switch>
                        <xf:case id="DoNothing">
                        </xf:case>
                        <xf:case id="EditOrphan">
                        <xf:select1 ref="./*:status/@value">
                            <xf:label>Status</xf:label>
                                <xf:item>
                                    <xf:label>Cancel</xf:label>
                                    <xf:value>cancelled</xf:value>
                                </xf:item>
                        </xf:select1>
                </xf:case>
            </xf:switch>
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
                    <xf:send submission="s-get-appointments"/>
                </xf:action>
                </xf:trigger>
                <xf:output value="choose((instance('i-apps')/*:start &gt; instance()/*:count),instance()/*:count,instance()/*:start)"/>-
                <xf:output value="choose((instance('i-apps')/*:start + instance()/*:length &gt; instance()/*:count),instance()/*:count,instance()/*:start + instance()/*:length - 1)"></xf:output>
                <xf:output value="concat('(',instance('i-apps')/*:count,')')"></xf:output>
                <xf:trigger ref="instance('views')/*:TriggerNextActive">
                <xf:label>&gt;&gt;</xf:label>
                <xf:action ev:event="DOMActivate">
                    <xf:setvalue ref="instance('i-search')/*:start" value="instance('i-search')/*:start + instance('i-search')/*:length"/>
                    <xf:send submission="s-get-appointments"/>
                </xf:action>
                </xf:trigger>
            </xf:group>
            </td><td>
                <xf:group>
                    <xf:group ref="instance('views')/*:AppointmentsToSelect">
                    <xf:input id="app-reason"
                            ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:reason/*:coding[*:system/@value=('#appointment-reason','#encounter-reason')]/*:display/@value"
                            class="">
                        <xf:label>Anlass:</xf:label>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:message level="ephemeral">Anlass gespeichert</xf:message>
                            <xf:setvalue ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:reason/*:text/@value" value="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:reason/*:coding[*:system/@value=('#appointment-reason','#encounter-reason')]/*:display/@value"/>
<!--
                            <xf:send submission="s-submit-appointment"/>
-->
                        </xf:action>
                    </xf:input>
                    </xf:group>
                </xf:group>
            </td><td>
                <xf:group>
                    <xf:group ref="instance('views')/*:AppointmentsToSelect">
                    <xf:select1 id="app-status" ref="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value"
                            class="medium-input" selection="closed">
                        <xf:label>Status:</xf:label>
                        <xf:item>
                            <xf:label>Annehmen, Buchen</xf:label>
                            <xf:value>booked</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>Ablehnen</xf:label>
                            <xf:value>cancelled</xf:value>
                        </xf:item>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:action if="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value='booked'">
                                <xf:message level="ephemeral">Termin gebucht</xf:message>
                                <xf:send submission="s-update-app"/>
                            </xf:action>
                            <xf:action if="instance('i-apps')/*:Appointment[index('r-apps-id')]/*:status/@value='cancelled'">
                                <xf:message level="ephemeral">Termin zurückgewiesen</xf:message>
                                <xf:send submission="s-submit-appointment"/>
                                <xf:send submission="s-reopen-order"/>
                            </xf:action>
                        </xf:action>
                    </xf:select1>
                    </xf:group>
                </xf:group>
            </td><td>
                <xf:group>
                <xf:trigger ref="instance('views')/*:AppointmentsToSelect">
                    <xf:label>Aktualisieren</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-get-appointments"/>
                    </xf:action>
                </xf:trigger>
                </xf:group>
            </td>
        </tr>
    </table>
</div>
)
};

declare function appointment:orphan-view()
{
    let $today := adjust-date-to-timezone(current-date(),())
    let $status := 
        (
          <status>booked</status>
        , <status>tentative</status>
        )
    let $logu   := r-user:userByAlias(xmldb:get-current-user())
    let $loguid := $logu/fhir:id/@value/string()
    let $lognam:= appointment:formatFHIRName($logu)
    let $start := dateTime($today,xs:time("08:00:00"))
    let $end   := $start + xs:dayTimeDuration("P7D")
    let $realm := "kikl-spz"
    let $head  := 'Termine' 
    return
(<div style="display:none;">
    <xf:model id="m-orphans" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance  xmlns="" id="i-apps">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-appointments"
                    ref="instance('i-search')"
                	instance="i-apps"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$appointment:restxq-orphans}/appointments?loguid=',encode-for-uri('{$loguid}'),'&amp;lognam=',encode-for-uri('{$lognam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">error get-orphans</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>*</length>
                <uid></uid>
                <group></group>
                <sched/>
                <patient/>
                <rangeStart>{$start}</rangeStart>
                <rangeEnd>{$end}</rangeEnd>
                { $status }
                <_sort>date:asc</_sort>
            </parameters>
        </xf:instance>

        <xf:instance xmlns="" id="i-dateTime">
            <data>
                <startdate>{$today}</startdate>
                <enddate>{xs:date($end)}</enddate>
                <nofd>30</nofd>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-dateTime')/*:startdate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:enddate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:nofd" type="xs:integer" constraint=". &gt; 0"/>
        
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-appointments"/>
        </xf:action>
    </xf:model>
</div>
,<xf:group class="svFullGroup bordered">
    <xf:label>Verwaiste Termine</xf:label>
    <table>
        <tr>
            <td colspan="4">
                <xf:group class="svFullGroup">
                    <xf:label>Zeitraum</xf:label><br/>
                    <xf:input ref="instance('i-dateTime')/*:startdate" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'">
                        <xf:label class="svListHeader">Start:</xf:label>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue 
                                ref="instance('i-dateTime')/*:nofd"
                                value="(xs:date(instance('i-dateTime')/*:enddate) - xs:date(instance('i-dateTime')/*:startdate)) div xs:dayTimeDuration('P1D') + 1"/>
                            <xf:action>
                                <xf:setvalue
                                    ref="instance('i-search')/*:rangeStart"
                                    value="concat(instance('i-dateTime')/*:startdate,'T08:00:00')"/>
                                <xf:send submission="s-get-appointments"/>
                            </xf:action>
                        </xf:action>
                    </xf:input>
                    <xf:input ref="instance('i-dateTime')/*:enddate" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'">
                        <xf:label class="svListHeader">Ende:</xf:label>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue 
                                ref="instance('i-dateTime')/*:nofd"
                                value="(xs:date(instance('i-dateTime')/*:enddate) - xs:date(instance('i-dateTime')/*:startdate)) div xs:dayTimeDuration('P1D') + 1"/>
                            <xf:action>
                                <xf:setvalue
                                    ref="instance('i-search')/*:rangeEnd"
                                    value="concat(instance('i-dateTime')/*:enddate,'T20:00:00')"/>
                                <xf:send submission="s-get-appointments"/>
                            </xf:action>
                        </xf:action>
                    </xf:input>
                    <xf:output ref="instance('i-dateTime')/*:nofd">
                        <xf:label>Anzahl Tage</xf:label>
                    </xf:output>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td>
                <xf:group class="svFullGroup bordered">
                    <xf:label>Termine</xf:label><br/>
                    <xf:repeat id="r-orphan-ids" ref="instance('i-apps')/*:Appointment" appearance="compact" class="svRepeat">
            <xf:output value="tokenize(./*:start/@value,'T')[1]">
                <xf:label class="svListHeader">Datum:</xf:label>                        
            </xf:output>
            <xf:output value="concat(format-dateTime(./*:start/@value, '[H1]:[m01]'),'-',format-dateTime(./*:end/@value, '[H1]:[m01]'))">
                <xf:label class="svListHeader">Von-Bis:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant[*:type//*:code/@value='patient']/*:actor/*:display/@value">
                <xf:label class="svListHeader">Patient:</xf:label>
            </xf:output>
            <xf:output ref="./*:reason/*:text/@value">
                <xf:label class="svListHeader">Anlass</xf:label>                        
            </xf:output>
            <xf:output ref="./*:description/@value">
                <xf:label class="svListHeader">Info</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant[*:type//*:code/@value!='patient']/*:type/*:coding/*:code/@value">
                <xf:label class="svListHeader">Service:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant[*:type//*:code/@value!='patient']/*:actor/*:display/@value">
                <xf:label class="svListHeader">Erbringer:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:status/@value">
                <xf:label class="svListHeader">Status:</xf:label>                        
            </xf:output>
                    </xf:repeat>
                </xf:group>
            </td>
        </tr>
    </table>
</xf:group>
)
};