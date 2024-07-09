xquery version "3.0";


import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-order   = "http://enahar.org/exist/restxq/nabu/orders"    at "../FHIR/Order/order-routes.xqm";

declare variable $local:info := 
<task-infos>
    <types>
        <option value="task" label="Anfrage"/>
        <option value="team" label="Meeting"/>
        <option value="task" label="ToDo"/>
        <option value="incident" label="Beschwerde-Vorfall"/>
        <option value="action" label="Aktion"/>
    </types>
    <priorities>
        <option value="high" label="hoch"/>
        <option value="middle" label="mittel"/>
        <option value="normal" label="mittel"/>
        <option value="low" label="niedrig"/>
    </priorities>
    <status>
        <option value="open" label="offen"/>
        <option value="done" label="erledigt!"/>
        <option value="notDone" label="unerledigt!"/>
        <option value="closed" label="geschlossen"/>
        <option value="reopened" label="wieder offen"/>
    </status>
</task-infos>;

declare function local:fillOrder($t as item())
{

  let $status := $local:info/status/option[@value=$t/t_status]/@label
  let $type   := $local:info/types/option[@value=$t/t_type]/@label
  let $prio   := $local:info/priorities/option[@value=$t/t_priority]/@label
  let $created_at   := $t/created_at/string()
  let $problem_id   := if (normalize-space($t/problem_id)  ="") then '' else concat("nabu/patients/",       $t/problem_id)
  let $submitter_id := if (normalize-space($t/submitter_id)="") then '' else concat("metis/practitioners/", $t/submitter_id)
  let $assignee_id  := if (normalize-space($t/assignee_id) ="") then '' else concat("metis/practitioners/", $t/assignee_id)
  let $requester    := $t/requester/string()
  let $t_role       := $t/t_role/string()
  let $t_type       := if ($t/t_type="question")
        then "task"
        else $t/t_type/string()
  let $t_due_at     := $t/t_due_at/string()
  let $colls        := for $c in $t/collaborators/*
                return
                    <collaborator>
                        <reference value="metis/practitioners/{$c/collaborator/string()}"/>
                        <display value=""/>
                    </collaborator>
  let $t_tags       := $t/t_tags/string()
  let $t_priority   := switch($t/t_priority)
        case 'medium' return 'normal'
        case 'middle' return 'normal'
        default return $t/t_priority/string()
  let $t_subject    := $t/t_subject/string()
  let $t_description:= $t/t_description/string()
  let $t_comment    := $t/t_comment/string()
  let $t_status     := switch ($t/t_status)
        case 'open' return 'assigned'
        case 'done' return 'closed'
        case 'notDone' return 'closed'
        default return $t/t_status/string()
  return
<Order xmlns="http://hl7.org/fhir" xml:id="{$t/@xml:id/string()}">
    <id value="{$t/@xml:id/string()}"/>
    <meta>
        <versionID value="0"/>
    </meta>
    <date value="{$created_at}"/>
    <subject>
            <reference value="{$problem_id}"/>
            <display value=""/>
    </subject>
    <source>
        <reference value="{$submitter_id}"/>
        <display value=""/>
    </source>
    <target>
        <role value="{$t_role}"/>
        <reference value="{$assignee_id}"/>
        <display value=""/>
    </target>
    <reason>
        <coding>
            <system value="#order-reason"/>
            <code value="{$t_type}"/>
            <display value="{$type}"/>
        </coding>
        <text value="{$type}"/>
    </reason>
    <authority>
        <reference value="metis/organizations/kikl-spz"/>
        <display value="SPZ Kinderklinik"/>
    </authority>
    <when>
        <schedule>
            <event value="{$t_due_at}T08:00:00"/>
        </schedule>
    </when>
    <detail>
        <tags value="{$t_tags}"/>
        <requester value="{$requester}"/>
        <priority>
            <coding>
                <system value="#order-priority"/>
                <code value="{$t_priority}"/>
                <display value="{$prio}"/>
            </coding>
            <text value="{$prio}"/>
        </priority>
        <summary value="{$t_subject}"/>
        <info value="{$t_description}"/>
        <comment value="{$t_comment}"/>
        {
            $colls
        }
    </detail>
    <extension url="#order-status">
        <status>
            <coding>
                <system value="#order-status"/>
                <code value="{$t_status}"/>
                <display value="{$status}"/>
            </coding>
            <text value="{$status}"/>
        </status>
    </extension>
</Order>
};



let $tasks  := collection($config:nabu-imports)/ticket
let $loguid := 'u-admin'
let $realm := 'kikl-spz'
let $today := current-date()
let $now   := current-dateTime()

for $t in $tasks
let $order := local:fillOrder($t)

let $store := r-order:create-or-edit-order(<content>{$order}</content>, $realm, $loguid)

return ()

