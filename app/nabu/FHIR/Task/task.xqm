xquery version "3.0";
module namespace task = "http://enahar.org/exist/apps/nabu/task";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";

import module namespace r-task    = "http://enahar.org/exist/restxq/nabu/tasks"    at "/db/apps/nabu/FHIR/Task/task-routes.xqm";
import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients" at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";

import module namespace r-practrole    = "http://enahar.org/exist/restxq/metis/practrole"  
               at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

import module namespace r-group = "http://enahar.org/exist/restxq/metis/groups"  at "/db/apps/metis/FHIR/Group/group-routes.xqm";


declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";


declare variable $task:restxq-base   := "/exist/restxq";
declare variable $task:practitioners := "metis/practitioners";
declare variable $task:organizations := "metis/organizations";
(:  
    declare variable $task:restxq-metis-users  := concat($task:restxq-base, $task:practitioners);
    declare variable $task:restxq-metis-roles  := "/exist/restxq/metis/roles";
:)
declare variable $task:restxq-metis-orgas  := concat($task:restxq-base, $task:organizations);
declare variable $task:restxq-metis-realms := "/exist/restxq/metis/realms";
declare variable $task:restxq-tasks        := "/exist/restxq/nabu/tasks";
declare variable $task:task-infos-uri      := "../nabu/FHIR/Task/task-infos.xml";

(:~
<Task xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionId value="0"/>
    </meta>
    <identifier><!-- 0..* Identifier Task Instance Identifier --></identifier>
    <basedOn><!-- 0..* Reference(Any) Request fulfilled by this task --></basedOn>
    <intent value="plan"/>
    <priority value="normal"/>
    <code>
        <coding>
            <system value="http://eNahar.org/ValueSet/task-reason"/>
            <code value="task"/>
            <display value="ToDo"/>
        </coding>
        <text value="ToDo"/>
    </code>
    <description value="Abklärung postoperative Belastung"/><!-- 0..1 Human-readable explanation of task -->
    <for>
        <reference value="nabu/patients/p-23124"/>
        <display value="Becker, Julian Alexander, *2013-07-16"/>
    </for>
    <executionPeriod>
        <start value=""/>
        <end value=""/>
    </executionPeriod>
    <authoredOn value="2017-02-21T16:13:43"/><!-- ?? 0..1 Task Creation Date -->
    <requester>  <!-- 0..1 Who is asking for task to be done -->
        <reference value="metis/practitioners/u-duechtingc"/>
        <display value="Düchting, Christoph"/>
        <extension url="http://eNahar.org/nabu/extension#onBehalfOf>
            <reference value="metis/organizations/kikl-spz"/>
            <display value="SPZ Kinderklinik"/>
        </extension>
    </requester>
    <performerType>    
        <coding>
            <system value="http://hl7.org/fhir/task-performer-type"/>
            <code value="performer"/>
            <display value="Erbringer"/>
        </coding>
        <text value="Erbringer"/>
    </performerType>
    <owner>
        <reference value="metis/practitioners/u-duechtingc"/>
        <display value="Düchting, Christoph"/>
    </owner>
    <reasonCode>
        <text value="spz"/>
    </reasonCode>
    <note>
        <authorReference>
            <reference value="metis/practitioners/u-duechtingc"/>
            <display value="Düchting, Christoph"/>
        </authorReference>
        <time value="2017-02-21T16:13:43"/><!-- 0..1 When the annotation was made -->
        <text value="kardio Kind, nach OP, traumatisch belastet, Vorstellung zur psychologischen Abklärung erbeten. Kind ist bereits wieder zuhause. Kommen aus Herne, mgl. nachmittags. Kann das jemand in den nächsten 2 Wochen machen? Danke, LG; C."/>
    </note>
    <relevantHistory><!-- 0..* Reference(Provenance) Key events in history of the Task -->
        
    </relevantHistory>
    <restriction>
        <period>
            <start value=""/>
            <end value="2017-02-21"/>
        </period>
        <recipient>
            <extension url="http:/eNahar.org/nabu/extension#task-recipient-role">
                <valueString value="spz-psych"/>
            </extension>
            <reference value=""/>
            <display value=""/>
        </recipient>
    </restriction>
    <input>
        <type>
            <coding>
                <system value="http://eNahr.org/ValueSet/task-input-types"/>
                <code value="tags"/>
            </coding>
        </type>
        <valueString value="spz"/>
    </input>
</Task>
 :)


(:~
 : show task functionality for dashboard
 : 
 : @return html
 :)
declare function task:showFunctions()
{
    <div>
        <h3>Tasks:</h3>
        <ul>
            <li>Neu:
                <a href="index.html?action=newTask&amp;self=true&amp;topic=task">
                    <img src="resources/images/myself16x16.png" alt="MySelf"/>
                </a> ,
                <a href="index.html?action=newTask&amp;self=false&amp;topic=task">
                    <img src="resources/images/share16x16.png" alt="Team"/>
                </a> ,
                <a href="index.html?action=newTask&amp;self=false&amp;topic=team">
                    <img src="resources/images/user-group.png" alt="Team-Besprechung"/>
                </a>
            </li>
            <li><a href="index.html?action=listTasks&amp;filter=open">Offene Aufgaben</a>
            </li>
            <li><a href="index.html?action=listTasks&amp;filter=send">Gesendet&amp;offen</a>
            </li>
            <li><a href="index.html?action=listTasks&amp;filter=open_team">Team-Besprechung</a>, <a href="/exist/restxq/nabu/tasks2pdf?realm=kikl-spz&amp;loguid=u-admin&amp;lognam=print-bot&amp;code=team&amp;status=requested&amp;status=received&amp;status=accepted"><img src="resources/images/download-16x16.png" alt="Team-Besprechung"/></a></li>
            <!--
            <li>
                <a href="index.html?action=listCategories">View Categories</a>
            </li>
            <li>
                <a href="index.html?action=listTags">View Tags</a>
            </li>
            <li>
                <a href="index.html?action=taskMetrics">Task Metrics</a>
            </li>
            -->
        </ul>
    </div>
};

(:~
 : show tasks
 : 
 : @param $status (open, all, send)
 : @return html
 :)
declare function task:listTasks($status as xs:string*)
{
    let $realm := "kikl-spz"
    let $org  := concat($task:organizations, '/', $realm)
    let $now := adjust-dateTime-to-timezone(current-dateTime())
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $roles  := r-practrole:rolesByID($prid,$realm,$uid,$unam)/fhir:role/string()
    let $states := switch($status)
        case 'open' return ('requested','received','accepted')
        case 'send' return ('requested','received')
        default return  ('requested','received','accepted','ready')
    let $source := switch($status)
        case 'send' return $uid
        default return ''
    let $target := switch($status)
        case 'send' return ''
        case 'open_team' return ''
        default return $uid
    let $code := switch($status)
        case 'open_team' return 'team'
        default return ('task','team')
    let $target-role := switch ($status)
        case 'open_team' return ""
        default return $roles
    let $myTasks := r-task:tasksXML(
          $realm,$uid,$unam
        , '1', '*', $code
        , $source, $target, $target-role
        , '1994-06-01T08:00:00', '2021-04-01T19:00:00'
        , '', $states, 'full')

    let $head  := switch($status)
        case 'open' return 'Offene Aufgaben'
        case 'open_team' return 'Team-Besprechung'
        case 'send' return 'Gesendete offene Aufgaben'
        default return '??? Fehler'
    return
    <div><h2>{$head}<span>({$myTasks/count})</span></h2>
    {
    if ($myTasks/count > 0)
    then 
        <table id="opentasks" class="tablesorter">
            <thead>
                <tr id="0">
                    <th>Prio</th>
                    <th>Fällig</th>
                    <th>Patient</th>
                    <th>Betreff</th>
                    <th>Queue</th>
                    <th>me?</th>
                    <th>Typ</th>
                    <th>Tags</th>
                    <th>ass</th>
                </tr>
            </thead>
            <tbody>{ task:tasksToRows($uid,$roles,$myTasks) }</tbody>
            <script type="text/javascript" defer="defer" src="../nabu/FHIR/Task/listTasks.js"/>       
        </table>
        else ()
    }
        <p>
            <ul>
                <li>
            Neues Ticket für <a href="index.html?action=newTask&amp;self=true&amp;topic=task">mich</a>,
            <a href="index.html?action=newTask&amp;self=false&amp;topic=task">Team</a> oder
            <a href="index.html?action=newTask&amp;self=true&amp;topic=team">Fall-Besprechung</a></li>
            </ul>
        </p>
    </div>
};


declare %private function task:tasksToRows(
      $uid as xs:string
    , $roles as xs:string+
    , $tasks)
{
    for $task in $tasks/fhir:Task
    let $tid := $task/fhir:id/@value/string()
    let $tags := $task/fhir:input[fhir:type/fhir:coding/fhir:system[@value="http://eNahar.org/ValueSet/task-input-types"]]/fhir:valueString/@value/string()
    let $due  := if ($task/fhir:restriction/fhir:period/fhir:end/@value!='')
            then
                format-date(xs:date(head(tokenize($task/fhir:restriction/fhir:period/fhir:end/@value,"T"))),"[D01].[M01].[Y01]")
            else format-date(current-date(),"[D01].[M01].[Y01]")
    let $remind := if ($due='22-06-15') then 'remind'
                    else ''
    let $ass  := task:isAssigned($uid,$task)
    let $uref := concat($task:practitioners,'/',$uid)
    let $isCC := task:isCC(($uref,$roles), $task)
    return
         <tr id="{$tid}">
            <td>{task:mapPriorityValue($task)}</td>
            <td class="{$remind}">{$due}</td>
            <td>{$task//fhir:for/fhir:display/@value/string()}</td>
            <td>{$task//fhir:description/@value/string()}</td>
            <td>
            {   if ($ass)
                then ''
                else r-group:roleByAlias($task/fhir:restriction/fhir:recipient/fhir:extension/fhir:valueString/@value/string())/fhir:name/@value/string()
            }
            </td> 
            <td>
            {   if ($ass)
                then
                    (
                        <span style="display:none">{string-join(
                                                        $task/fhir:restriction/fhir:recipient/fhir:reference/@value
                                                        , " :: ")}</span>
                    ,   <img src="resources/images/myself16x16.png" alt="MySelf"/>
                    )
                else 
                    for $r in $task/fhir:restriction/fhir:recipient
                    let $tnam := $r/fhir:display/@value/string() (: hack for empty display values :)
                    return
                        if ($tnam="")
                        then substring-after($r/fhir:reference/@value, 'u-')
                        else $tnam
            }
            </td>
            <!--
            <td>{if ($isCC)
                 then if ($ass) (: ich bin's selbst CC :)
                      then <img src="resources/images/myself16x16.png" alt="MySelf"/>
                      else <img src="resources/images/user-role16x16.png" alt="Role"/>
                 else () (:  empty :)
            }</td>
            -->
            <td>{task:getTaskIcon($task)}</td>
            <td>{$tags}</td>
            <td>
            {
                if ($task/fhir:status[@value='received'])
                then <img src="resources/images/add.gif" alt="new"/>
                else ()
            }</td>
         </tr> 
};

declare variable $task:prio := 
    <priorities>
        <option value="normal" label=""/>
        <option value="urgent" label="dringend"/>
        <option value="asap"   label="asap"/>
        <option value="stat"   label="sofort"/>
        <option value="low"    label="niedrig"/>
    </priorities>;
    
declare %private function task:mapPriorityValue($t)
{
    let $prio := $t//fhir:priority/@value/string()
    return
        $task:prio//option[@value=$prio]/@label/string()
};

declare %private function task:getTaskIcon($t)
{
    let $t_type := $t/fhir:code/fhir:coding/fhir:code/@value/string()
    return
    if ($t_type='incident')
    then <img src="resources/images/bomb16x16.png" alt="Notfall"/>
    else if ($t_type='team')
    then <img src="resources/images/user-group.png" alt="Meeting"/>
    else if ($t_type='question')
    then <img src="resources/images/arrow_return_180_left.png" alt="Anfrage"/>
    else ()
};

declare %private function task:isAssigned($uid, $task as element(fhir:Task)) as xs:boolean
{
    let $uref  := concat($task:practitioners, '/', $uid)
    return
        $uref = $task/fhir:restriction/fhir:recipient/fhir:reference/@value
};

declare %private function task:isCC($uref,$task) as xs:boolean
{
    let $ccs := $task/fhir:restriction/fhir:recipient
    return
        count($ccs//fhir:reference[@value=$uref])>0
};


declare %private function task:isAssignedOrAuth($uid, $task, $roles) as xs:boolean
{
    let $uref  := concat($task:practitioners, '/', $uid)
    let $isAuth := if ($uref = $task/fhir:restriction/fhir:recipient/fhir:reference/@value
                or ($task/fhir:restriction/fhir:recipient[fhir:reference/@value=$uref]/fhir:extension/fhir:valueString/@value=$roles and $task/fhir:restriction/fhir:recipient[fhir:reference/@value=$uref]/fhir:reference/@value=''))   (: role   :)
        then 'perm_basic' = r-practrole:perms($uid)/fhir:perm
        else 'perm_updateTasks' = r-practrole:perms($uid)/fhir:perm
    return
        $isAuth
};

(:~
 : 
 : show xform for ticket
 : 
 : @param $tid   ticket id
 : @param $type  ticket type
 : @return: () 
 :  
:)
declare function task:editTask($tid as xs:string*, $self as xs:string*, $type as xs:string*)
{
    let $realm  := 'kikl-spz'
    let $org    := concat($task:organizations, '/', $realm)
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $roles  := r-practrole:rolesByID($prid,$realm,$uid,$unam)/fhir:role/string()

    let $header := "Ticket: "
    let $task   := r-task:taskByID($tid, $realm, $uid, $unam)
    let $isNew  := false()
    let $isSelf := $uref = $task/fhir:owner/fhir:reference/@value      
    let $isMoveable := 'moveTasks' = r-practrole:perms($uid)/fhir:perm
    let $tt  := ($type,$task/fhir:code/fhir:coding/fhir:code/@value)[1] (: type via cmdline overrides :)
    let $today := adjust-dateTime-to-timezone(current-dateTime(),())
    return
(<div style="display:none;">
    <xf:model id="m-task">
        <xf:instance xmlns="" id="i-task">
            <data>
                {$task}
            </data>
        </xf:instance>
        
        <xf:submission id="s-submit-task"
                				   ref="instance('i-task')/*:Task"
								   method="put"
								   replace="none">
	    		<xf:resource value="concat('/exist/restxq/nabu/tasks?loguid=',encode-for-uri(instance('i-login')/*:loguid),'&amp;lognam=',encode-for-uri(instance('i-login')/*:lognam),'&amp;realm=',encode-for-uri(instance('i-login')/*:realm))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:action ev:event="xforms-submit-done">
                <xf:action if="instance('i-dfa')/*:status-changed='true'">
                    <xf:action if="string-length(instance('i-task')/*:Task/*:basedOn/*:reference/@value)>0">
                        <xf:send submission="s-update-careplan-status"/>
                    </xf:action>
                </xf:action>
                <xf:load resource="/exist/apps/nabu/index.html"/>
            </xf:action>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit task! validation?</xf:message>
        </xf:submission>
        <!--
        <xf:bind ref="instance('i-task')/route"        readonly="true()"/>
        <xf:bind ref="instance('i-task')/recipient"    readonly="true()"/>
        -->
        <xf:bind ref="instance('i-task')/*:Task/*:owner/*:reference/@value"     readonly="true()"/>
        <xf:bind ref="instance('i-task')/*:Task/*:requester/*:extension/*:reference/@value"  readonly="true()"/>


        <xf:bind ref="instance('i-task')/*:Task/*:code/*:coding/*:code/@value"       type="xs:string" constraint="string-length(.) &gt; 0"/>
        <xf:bind ref="instance('i-task')/*:Task/*:priority/@value"   type="xs:string" constraint="string-length(.) &gt; 0"/>
<!--
        <xf:bind ref="instance('i-task')/*:Task/*:restriction/*:recipient/*:extension/*:valueString/@value"       type="xs:string" constraint="string-length(.) &gt; 1"/>
-->
        <xf:bind ref="instance('i-task')/*:Task/*:description/@value" readonly="true()"/>
        <xf:bind ref="instance('i-task')/*:Task/*:note[1]/*:text/@value"    readonly="true()"/>
        <xf:bind ref="instance('i-task')/*:Task/*:status/@value"     type="xs:string" constraint="string-length(.) &gt; 0"/>        
        <xf:bind
            ref="instance('i-task')/*:Task/*:restriction/*:period/*:end/@value"
            type="xs:string" constraint="matches(.,'h|m|nw|\dw|\dm|\d{{2}}-\d{{2}}-\d{{2}}|\d{{2}}\.\d{{2}}\.\d{{2}}')"/>    
        
        <xf:instance id="i-t-infos" xmlns="" src="{$task:task-infos-uri}"/>
        
        <xf:instance id="i-login">
            <data xmlns="">
                <loguid>{$uid}</loguid>
                <lognam>{$unam}</lognam>
                <realm>{$realm}</realm>
                <today>{$today}</today>
            </data>
        </xf:instance>
        <xf:submission id="s-update-careplan-status"
								   method="post"
								   replace="none">
                <xf:resource value="concat('/exist/restxq/nabu/careplans/',substring-after(instance('i-task')/*:Task/*:basedOn/*:reference/@value,'nabu/careplans/'),'/actions/',instance('i-task')/*:Task/*:id/@value,'?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'),'&amp;status=',instance('i-t-infos')/*:status-t2cp-a/*:code[@e=instance('i-task')/*:Task/*:status/@value]/@a,'&amp;outcome=',encode-for-uri(instance('i-task')/*:Task/*:note[last()]/*:text/@value))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot update careplan action status!</xf:message>
        </xf:submission>        
        <xf:instance id="i-dfa" xmlns="">
            <data>
                <status-changed>true</status-changed>
                <event>leave</event>
            </data>
        </xf:instance>
        
        <xf:instance id="i-bricks" xmlns="">
            <bricks xmlns="http://hl7.org/fhir">
                <event value=""/>
                <note>
                    <authorReference>
                        <reference value="{$uref}"/>
                        <display value="{$unam}"/>
                    </authorReference>
                    <time value="{adjust-dateTime-to-timezone(current-dateTime(),())}"/>
                    <text value=""/>
                </note>
            </bricks>
        </xf:instance>
        
        <xf:instance id="i-memo">
            <data xmlns="">
                <recipient>
                    <role value=""/>
                    <reference value=""/>
                    <display value=""/>
                </recipient>
            </data>
        </xf:instance>
        
        <xf:action ev:event="xforms-model-construct-done">
        </xf:action>
        <xf:action ev:event="xforms-ready">
            <xf:action if="count(instance('i-task')/*:Task/*:note)!=2">
                <xf:insert at="last()" position="after" ref="instance('i-task')/*:Task/*:note"
                    origin="instance('i-bricks')/*:note"/>
            </xf:action>
        </xf:action>
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
        <xf:input id="subject-ref"     ref="instance('i-task')/*:Task/*:for/*:reference/@value"/>
        <xf:input id="subject-display" ref="instance('i-task')/*:Task/*:for/*:display/@value"/>
        <xf:input id="target-role"     ref="instance('i-memo')/*:recipient/*:role/@value">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'received'"/>
                <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient/*:reference/@value" value="''"/>
                <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient/*:display/@value" value="''"/>
            </xf:action>
        </xf:input>
        <xf:input id="target-ref"      ref="instance('i-memo')/*:recipient/*:reference/@value">
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'received'"/>
            </xf:action>
        </xf:input>
        <xf:input id="target-display"  ref="instance('i-memo')/*:recipient/*:display/@value"/>    
</div>,
<xf:group id="task">
    <xf:action ev:event="addRecipient">
        <xf:insert ref="instance('i-task')/*:Task/*:restriction/*:recipient"
            context="instance('i-task')/*:Task/*:restriction"
            origin="instance('i-t-infos')/*:bricks/*:recipient"/>
        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[last()]/*:extension/*:valueString/@value" value="instance('i-memo')/*:recipient/*:role/@value"/>
        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[last()]/*:reference/@value" value="instance('i-memo')/*:recipient/*:reference/@value"/>
        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[last()]/*:display/@value" value="instance('i-memo')/*:recipient/*:display/@value"/>
        <xf:setvalue ref="instance('i-memo')/*:recipient/*:role/@value" value="''"/>
        <xf:setvalue ref="instance('i-memo')/*:recipient/*:reference/@value" value="''"/>
        <xf:setvalue ref="instance('i-memo')/*:recipient/*:display/@value" value="''"/>
        <script type="text/javascript">
            console.log('clear filters');
            $('.task-select[name="role-hack"]').val('').trigger('change');
            $('.task-select[name="target-hack"]').val('').trigger('change');
        </script>
    </xf:action>
    <h2><xf:output ref="instance('i-t-infos')/types/option[@value=instance('i-task')/*:Task/*:code/*:coding/*:code/@value]/@label-de">
        </xf:output>-Ticket: <xf:output ref="instance('i-task')/*:Task/*:description/@value"></xf:output></h2>
    <table>
        <tr>
            <td colspan="5">
                { task:mkTaskGroup($isSelf) }
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Abbrechen</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/nabu/index.html"/> 
                </xf:trigger>
            </td>
            <td>
                <strong>Workflow:</strong>
            </td>
            <td>
                <xf:select1 ref="instance('i-dfa')/*:event" class="medium-select" incremental="true">
                    <xf:itemset ref="instance('i-t-infos')/*:scxml/*:state[@id='received']/*:transition">
                        <xf:label ref="./@label-de"/>
                        <xf:value ref="./@event"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='reassign'">
                        <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'received'"/>
<!--
                        <xf:setvalue ref="instance('i-task')/*:Task/*:detail/*:comment/@value" value="concat('war zugewiesen von: ',instance('i-task')/*:Task/*:owner/*:display/@value,'&amp;#10',instance('i-task')/*:Task/*:detail/*:comment/@value)"/>
-->
                        <xf:setvalue ref="instance('i-task')/*:Task/*:owner/*:reference/@value"     value="''"/>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:owner/*:display/@value"       value="''"/>
                        <xf:setvalue ref="instance('i-memo')/*:recipient/*:reference/@value" value="''"/>
                        <xf:setvalue ref="instance('i-memo')/*:recipient/*:display/@value" value="''"/>
                        <xf:toggle case="reassign"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='accept'">
                        <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'accepted'"/>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:owner/*:reference/@value" value="'{$uref}'"/>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:owner/*:display/@value" value="'{$unam}'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='resolve'">
                        <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'completed'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='reopen'">
                        <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'received'"/>
                    </xf:action>
                    <xf:action ev:event="xforms-value-changed" if="instance('i-dfa')/*:event='leave'">
                        <xf:message level="ephemeral">don't touch</xf:message>
                    </xf:action>
                </xf:select1>
            </td>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:hint>This button will save the ticket.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-task"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td>
                <xf:trigger ref="instance('i-task')/*:Task/*:for[*:reference/@value!='']" class="svSaveTrigger">
                    <xf:label>./. Patient</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:load show="new">
                            <xf:resource value="concat('/exist/apps/nabu/index.html?action=listPatients&amp;id=',substring-after(instance('i-task')/*:Task/*:for/*:reference/@value,'nabu/patients/'))"/>
                        </xf:load>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</xf:group>
)
};

declare %private function task:mkTaskGroup($isSelf as xs:boolean)
{
    <xf:group ref="instance('i-task')/*:Task" class="svFullGroup bordered">
            <xf:select1 ref="./*:priority/@value" class="medium-select">
                    <xf:label>Priorität:</xf:label>
                    <xf:itemset nodeset="instance('i-t-infos')/priorities/option">
                        <xf:label ref="./@label-de"/>
                        <xf:value ref="./@value"/>
                    </xf:itemset>
            </xf:select1>
            <xf:output ref="instance('i-task')/*:Task/*:owner/*:display/@value" class="medium-input">
                <xf:label>Zuweiser:</xf:label>
            </xf:output>
            <xf:output value="substring-after(instance('i-task')/*:Task/*:owner/*:reference/@value, 'u-')" if="instance('i-task')/*:Task/*:owner/*:display/@value=''"/>
            <br/>
            <xf:input ref="./*:requester/*:display/@value" class="long-input">
                    <xf:label>Ext. Anfrage?</xf:label>
                    <xf:hint>Initiator des Tickets</xf:hint>
            </xf:input>
            <xf:switch id="queue">
                    <xf:case id="leave">
                        <xf:output value="string-join(instance('i-task')/*:Task/*:restriction/*:recipient/*:extension/*:valueString/@value,'::')">
                            <xf:label>Queues</xf:label>
                        </xf:output>
                        <span>::</span>
                        <xf:output value="string-join(instance('i-task')/*:Task/*:restriction/*:recipient/*:display/@value,'::')"/>
                        <xf:output value="string-join(
                                        for $r in instance('i-task')/*:Task/*:restriction/*:recipient/*:reference/@value
                                        return
                                            substring-after($r, 'u-')
                                ,'::')" if="instance('i-task')/*:Task/*:restriction/*:recipient/*:display/@value=''"/>
                        <br/>
                        <xf:output value="instance('i-task')/*:Task/*:for/*:display/@value">
                            <xf:label>Patient:</xf:label>
                        </xf:output>
                        <br/>
                    </xf:case>
                    <xf:case id="reassign">
                    <table>
            <tr>
                <td rowspan="3">
                    <strong>Zugewiesen</strong>
                </td>
                <td rowspan="3" colspan="2">
                    <xf:repeat id="r-recipients-id" ref="./*:restriction/*:recipient" appearance="compact" class="svRepeat">
                        <xf:output ref="./*:extension/*:valueString/@value"/>
                        <xf:output ref="./*:display/@value">
                        </xf:output>
                    </xf:repeat>
                </td>
                <td>
                    <strong>Queue</strong>
                </td>
                <td colspan="2">
                    <select class="task-select" name="role-hack">
                        <option></option>
                    </select>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Erbringer</strong>
                </td>
                <td colspan="2">
                    <select class="task-select" name="target-hack">
                        <option></option>
                   </select>
                </td>
            </tr>
            <tr>
                <td>
                <xf:trigger class="svAddTrigger">
                    <xf:label>Zuweisen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:action if="string-length(instance('i-memo')/*:recipient/*:role/@value)=0 and string-length(substring-after(instance('i-memo')/*:recipient/*:reference/@value,'metis/practitioners/'))=0">
                            <xf:message level="ephemeral">Kein Erbringer ausgewählt!</xf:message>
                        </xf:action>
                        <xf:action if="string-length(instance('i-memo')/*:recipient/*:role/@value)&gt;0 or string-length(substring-after(instance('i-memo')/*:recipient/*:reference/@value,'metis/practitioners/'))&gt;0">
                            <xf:dispatch name="addRecipient" targetid="task"/>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
                </td>
                        <td colspan="2">
                <xf:trigger ref="instance('i-task')/*:Task/*:restriction/*:recipient[count(.)&gt;0]" class="svDelTrigger">
                    <xf:label>Löschen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:delete ref="instance('i-task')/*:Task/*:restriction/*:recipient[index('r-recipients-id')]"/>
                    </xf:action>
                </xf:trigger>
                        </td>
                        </tr>
                        <tr>
                            <td>
                                <strong>Patient:</strong>
                            </td>
                            <td colspan="2">
                                <select class="task-select" name="subject-hack">
                                    <option></option>
                                </select>
                            </td>
                        </tr>
                    </table>
                    </xf:case>
            </xf:switch>
        <script type="text/javascript" defer="defer" src="../nabu/FHIR/Task/task.js"/>
        <xf:input ref="./*:description/@value" class="long-input">
            <xf:label>Betreff:</xf:label>
        </xf:input>
        <xf:textarea ref="./*:note[1]/*:text/@value" class="fullarea">
            <xf:label>Text:</xf:label>
        </xf:textarea>
        <xf:textarea ref="./*:note[2]/*:text/@value" class="fullarea">
            <xf:label>Kommentar :</xf:label>
        </xf:textarea>
        <xf:output value="instance('i-task')/*:Task/*:note[2]/*:authorReference/*:display/@value"/>
        <xf:input ref="./*:restriction/*:period/*:end/@value" class="">
            <xf:label>Fällig am:</xf:label>
            <xf:hint>(h|m|nw|dw|dm|yy-mm-dd|dd.mm.yy)</xf:hint>
        </xf:input>
        <xf:input ref="./*:input[*:type/*:coding/*:system[@value='http://eNahar.org/ValueSet/task-input-types']]/*:valueString/@value" class="">
            <xf:label>Tags:</xf:label>
            <xf:hint>Tags erlauben Filtern und Sortieren von Tickets</xf:hint>
        </xf:input>
        <xf:output ref="instance('i-task')/*:Task/*:status/@value">
            <xf:label>Status:</xf:label>
        </xf:output>
    </xf:group>
};

(:~
 : 
 : show xform for ticket
 : 
 : @param $tid   ticket id
 : @param $type  ticket type
 : @return: () 
 :  
:)
declare function task:newTask($self as xs:string*, $type as xs:string*)
{
    let $realm  := 'kikl-spzn'
    let $now := adjust-dateTime-to-timezone(current-dateTime(), ())
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid := substring-after($uref,'metis/practitioners/')
    let $unam := $logu/fhir:practitioner/fhir:display/@value/string()
    let $loggrp := $logu/fhir:specialty//fhir:code/@value/string()
    let $org  := concat($task:organizations, '/', $realm)
    let $isNew  := true()
    let $isSelf := xs:boolean($self)
    let $isMoveable := 'moveTasks' = r-practrole:perms($uid)/fhir:perm
    let $ttype  := switch($type)
        case 'task' return 'task'
        case 'team' return 'team'
        default return 'task'
    let $tlabel := switch($ttype)
        case 'team' return 'Team'
        default return 'ToDo'
    let $today := adjust-dateTime-to-timezone(current-dateTime(),())
    return
(<div style="display:none;">
    <xf:model id="m-task">
        <xf:instance xmlns="" id="i-task">
            <data/>
        </xf:instance>
        
        <xf:submission id="s-submit-task"
                				   ref="instance('i-task')/*:Task"
								   method="put"
								   replace="none">
			<xf:resource value="concat('/exist/restxq/nabu/tasks?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:load ev:event="xforms-submit-done" resource="/exist/apps/nabu/index.html"/> 
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit task! validation?</xf:message>
        </xf:submission>

        <xf:bind ref="instance('i-task')/*:Task/*:code/*:coding/*:code/@value"       type="xs:string" constraint="string-length(.) &gt; 0"/>
        <xf:bind ref="instance('i-task')/*:Task/*:priority/@value"   type="xs:string" constraint="string-length(.) &gt; 0"/>
<!--
        <xf:bind ref="instance('i-task')/*:Task/*:restriction/*:recipient/*:extension/*:valueString/@value"       type="xs:string" constraint="string-length(.) &gt; 1"/>
-->
        <xf:bind ref="instance('i-task')/*:Task/*:description/@value"    type="xs:string" constraint="string-length(.) &gt; 3"/>
        <xf:bind ref="instance('i-task')/*:Task/*:status/@value"     type="xs:string" constraint="string-length(.) &gt; 0"/>     
        <xf:bind ref="instance('i-task')/*:Task/*:restriction/*:period/*:end/@value"     type="xs:string" 
                                                            constraint="matches(.,'h|m|nw|\dw|\dm|\d{{2}}-\d{{2}}-\d{{2}}|\d{{2}}\.\d{{2}}\.\d{{2}}')"/>    
        
        <xf:instance id="i-t-infos" xmlns="" src="{$task:task-infos-uri}"/>
        
        <xf:instance id="i-login">
            <data xmlns="">
                <loguid>{$uid}</loguid>
                <lognam>{$unam}</lognam>
                <realm>{$realm}</realm>
                <today>{$today}</today>
            </data>
        </xf:instance>
        
        <xf:instance id="i-memo">
            <data xmlns="">
                <recipient>
                    <role value=""/>
                    <reference value=""/>
                    <display value=""/>
                </recipient>
            </data>
        </xf:instance>
        <xf:action ev:event="xforms-model-construct-done">
            <xf:insert ref="instance('i-task')/*:Task"
                context="instance('i-task')"
                origin="instance('i-t-infos')/*:bricks/*:Task"/>
        </xf:action>
        <xf:action ev:event="xforms-ready">
            <xf:setvalue ref="instance('i-task')/*:Task/*:code/*:coding/*:code/@value"     value="'{$ttype}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:code/*:coding/*:display/@value"  value="'{$tlabel}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:code/*:text/@value"              value="'{$tlabel}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:requester/*:reference/@value"    value="'{$uref}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:requester/*:display/@value"      value="'{$unam}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:note/*:authorReference/*:reference/@value"    value="'{$uref}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:note/*:authorReference/*:display/@value"      value="'{$unam}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:note/*:time/@value"              value="'{adjust-dateTime-to-timezone(current-dateTime(),())}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:authoredOn/@value"               value="'{adjust-dateTime-to-timezone(current-dateTime(),())}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:requester/*:extension/*:valueReference/*:reference/@value"   value="'{$org}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:period/*:start/@value"   value="'{format-dateTime(current-dateTime(),'[Y01]-[M01]-[D01]')}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:period/*:end/@value"   value="'{format-dateTime(current-dateTime(),'[Y01]-[M01]-[D01]')}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:owner/*:reference/@value"    value="'{$uref}'"/>
            <xf:setvalue ref="instance('i-task')/*:Task/*:owner/*:display/@value"      value="'{$unam}'"/>
            { if ($isSelf)
                then
                    <xf:action>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:owner/*:reference/@value"    value="'{$uref}'"/>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:owner/*:display/@value"      value="'{$unam}'"/>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value"               value="'accepted'"/>
                        <xf:insert ref="instance('i-task')/*:Task/*:restriction/*:recipient"
                            context="instance('i-task')/*:Task/*:restriction"
                            origin="instance('i-t-infos')/*:bricks/*:recipient"/>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[1]/*:extension/*:valueString/@value"       value="'{$loggrp}'"/>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[1]/*:reference/@value"  value="'{$uref}'"/>
                        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[1]/*:display/@value"    value="'{$unam}'"/>
                    </xf:action>
                else ()
            }
        </xf:action>

        
    </xf:model>
    <!-- shadowed inputs for select2 hack, to register refs for fluxprocessor -->
        <xf:input id="subject-ref"     ref="instance('i-task')/*:Task/*:for/*:reference/@value"/>
        <xf:input id="subject-display" ref="instance('i-task')/*:Task/*:for/*:display/@value"/>
        <xf:input id="target-role"     ref="instance('i-memo')/*:recipient/*:role/@value">
        { if ($isSelf)
            then
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'accepted'"/>
                </xf:action>
            else
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'received'"/>
            </xf:action>
        }
        </xf:input>
        <xf:input id="target-ref"      ref="instance('i-memo')/*:recipient/*:reference/@value">
        { if ($isSelf)
            then
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'accepted'"/>
                </xf:action>
            else
                <xf:action ev:event="xforms-value-changed">
                    <xf:setvalue ref="instance('i-task')/*:Task/*:status/@value" value="'received'"/>
            </xf:action>
        }
        </xf:input>
        <xf:input id="target-display"  ref="instance('i-memo')/*:recipient/*:display/@value"/>        
</div>,
<xf:group id="task">
    <xf:action ev:event="addRecipient">
        <xf:insert ref="instance('i-task')/*:Task/*:restriction/*:recipient"
            context="instance('i-task')/*:Task/*:restriction"
            origin="instance('i-t-infos')/*:bricks/*:recipient"/>
        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[last()]/*:extension/*:valueString/@value" value="instance('i-memo')/*:recipient/*:role/@value"/>
        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[last()]/*:reference/@value" value="instance('i-memo')/*:recipient/*:reference/@value"/>
        <xf:setvalue ref="instance('i-task')/*:Task/*:restriction/*:recipient[last()]/*:display/@value" value="instance('i-memo')/*:recipient/*:display/@value"/>
        <xf:setvalue ref="instance('i-memo')/*:recipient/*:role/@value" value="''"/>
        <xf:setvalue ref="instance('i-memo')/*:recipient/*:reference/@value" value="''"/>
        <xf:setvalue ref="instance('i-memo')/*:recipient/*:display/@value" value="''"/>
        <script type="text/javascript">
            console.log('clear filters');
            $('.task-select[name="role-hack"]').val('').trigger('change');
            $('.task-select[name="target-hack"]').val('').trigger('change');
        </script>
    </xf:action>
    <h2><xf:output ref="instance('i-t-infos')/types/option[@value=instance('i-task')/*:Task/*:code/*:coding/*:code/@value]/@label-de">
        </xf:output>: <xf:output ref="instance('i-task')/*:Task/*:description/@value"></xf:output></h2>
    <table>
        <tr>
            <td colspan="6">
                <hr/>
            </td>
        </tr>
        <tr>
            <td colspan="6">
                { task:mkNewTaskGroup($isSelf) }
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Abbrechen</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/nabu/index.html"/> 
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Speichern</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-task"/>
                    </xf:action>
                </xf:trigger>
            </td>
        </tr>
    </table>
</xf:group>
)
};


declare %private function task:mkNewTaskGroup($isSelf as xs:boolean)
{
    <xf:group ref="instance('i-task')/*:Task" class="svFullGroup">
        <table>
            <tr>
                <td>
                    <strong>Typ:</strong>
                </td>
                <td>
        <xf:select1 ref="./*:code/*:coding/*:code/@value" class="medium-input" incremental="true">
            <xf:itemset nodeset="instance('i-t-infos')/types/option">
                <xf:label ref="./@label-de"/>
                <xf:value ref="./@value"/>
            </xf:itemset>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-task')/*:Task/*:code/*:text/@value"
                    value="instance('i-t-infos')/types/option[@value= instance('i-task')/*:Task/*:code/*:coding/*:code/@value]/@label-de"/>
                <xf:setvalue ref="instance('i-task')/*:Task/*:code/*:coding/*:display/@value"
                    value="instance('i-t-infos')/types/option[@value= instance('i-task')/*:Task/*:code/*:coding/*:code/@value]/@label-de"/>
            </xf:action>
        </xf:select1>
                </td>
                <td>
                    <strong>Prio</strong>
                </td>
                <td colspan="1">
        <xf:select1 ref="./*:priority/@value" class="short-input">
            <xf:itemset nodeset="instance('i-t-infos')/priorities/option">
                <xf:label ref="./@label-de"/>
                <xf:value ref="./@value"/>
            </xf:itemset>
        </xf:select1>
                </td>
            </tr>
            <tr>
        { if ($isSelf)
            then ()
            else
            (
                <td>
                    <strong>Ext. Anfrage</strong>
                </td>
            ,   <td>
                    <xf:input ref="./*:requester/*:display/@value">
                        <xf:hint>Initiator des Tickets</xf:hint>
                    </xf:input>
                </td>
            )
        }
            </tr>
            <tr>
                <td><hr/></td>
            </tr>
            <tr>
                <td rowspan="3">
                    <strong>Zugewiesen</strong>
                </td>
                <td rowspan="3" colspan="2">
                   <xf:repeat id="r-recipients-id" ref="./*:restriction/*:recipient" appearance="compact" class="svRepeat">
                        <xf:output ref="./*:extension/*:valueString/@value"/>
                        <xf:output ref="./*:display/@value">
                        </xf:output>
                </xf:repeat>
                </td>
                <td>
                    <strong>Queue</strong>
                </td>
                <td colspan="2">
                    <select class="task-select" name="role-hack">
                        <option></option>
                    </select>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Erbringer</strong>
                </td>
                <td colspan="2">
                    <select class="task-select" name="target-hack">
                        <option></option>
                   </select>
                </td>
            </tr>
            <tr>
                <td>
                <xf:trigger class="svAddTrigger">
                    <xf:label>Zuweisen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:action if="string-length(instance('i-memo')/*:recipient/*:role/@value)=0 and string-length(instance('i-memo')/*:recipient/*:reference/@value)=0">
                            <xf:message level="ephemeral">Kein Erbringer ausgewählt!</xf:message>
                        </xf:action>
                        <xf:action if="string-length(instance('i-memo')/*:recipient/*:role/@value)&gt;0 or string-length(instance('i-memo')/*:recipient/*:reference/@value)&gt;0">
                            <xf:dispatch name="addRecipient" targetid="task"/>
                        </xf:action>
                    </xf:action>
                </xf:trigger>
                </td>
                <td colspan="2">
                <xf:trigger ref="instance('i-task')/*:Task/*:restriction/*:recipient[count(.)&gt;0]" class="svDelTrigger">
                    <xf:label>Löschen</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:delete ref="instance('i-task')/*:Task/*:restriction/*:recipient[index('r-recipients-id')]"/>
                    </xf:action>
                </xf:trigger>
                </td>
            </tr>
            <tr>
                <td colspan="6"><hr/></td>
            </tr>
            <tr>
                <td>
                    <strong>Patient:</strong>
                </td>
                <td colspan="4">
        <select class="task-select" name="subject-hack">
            <option></option>
        </select>
        <script type="text/javascript" defer="defer" src="../nabu/FHIR/Task/task.js"/>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Betreff:</strong>
                </td>
                <td colspan="2">
        <xf:input ref="./*:description/@value" incremental="true" class="long-input">
        </xf:input>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Text:</strong>
                </td>
                <td colspan="5">
        <xf:textarea ref="./*:note[1]/*:text/@value" class="fullarea">
        </xf:textarea>
                </td>
            </tr>
            <tr>
                <td>
                    <strong>Fällig am:</strong>
                </td>
                <td>
        <xf:input ref="./*:restriction/*:period/*:end/@value" class="">
            <xf:hint>(h|m|nw|\dw|\mM|dd.mm.yy|yy-mm-dd)</xf:hint>
        </xf:input>
                </td>
                <td>
                    <strong>Tags:</strong>
                </td>
                <td colspan="1">
        <xf:input ref="./*:input[*:type/*:coding/*:system[@value='http://eNahar.org/ValueSet/task-input-types']]/*:valueString/@value" class="">
            <xf:hint>Tags erlauben Filtern und Sortieren von Tickets</xf:hint>
        </xf:input>
                </td>
                <td>
                    <strong>Status:</strong>
                </td>
                <td>
        <xf:output ref="instance('i-task')/*:Task/*:status/@value">
        </xf:output>
                </td>
            </tr>
        </table>
    </xf:group>
};

