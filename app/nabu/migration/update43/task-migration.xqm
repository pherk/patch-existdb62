xquery version "3.0";

module namespace taskmigr = "http://enahar.org/exist/apps/nabu/task-migration";
import module namespace date   = "http://enahar.org/exist/apps/nabu/date"    at "/db/apps/nabu/modules/date.xqm";
declare namespace fhir= "http://hl7.org/fhir";

declare function taskmigr:update-1.0-8(
          $task as element(fhir:Task)
        )
{
    if ($task/fhir:encounter)
    then
        system:as-user('vdba', 'kikl823!',
            (
              update delete $task/fhir:context
            , update delete $task/fhir:descriptionReference
            ))
    else ()
};

declare function taskmigr:update-1.0-7(
          $task as element(fhir:Task)
        )
{
    if ($task/fhir:context)
    then
        system:as-user('vdba', 'kikl823!',
            (
              update insert
                <encounter>
                {
                    $task/fhir:context/*
                }</encounter>
                following $task/fhir:context
            ))
    else ()
};

declare function taskmigr:update-1.0-6(
          $task as element(fhir:Task)
        )
{
    if ($task//fhir:system[@value='#task-reason'])
    then
        system:as-user('vdba', 'kikl823!',
            (
              update value
                    $task/fhir:code/fhir:coding/fhir:system/@value
                    with 
                    "http://eNahar.org/ValueSet/task-reason"
            ))
    else ()
};

declare function taskmigr:update-1.0-5(
          $task as element(fhir:Task)
        )
{
    if ($task//fhir:system[@value='#task-input-types'])
    then
        system:as-user('vdba', 'kikl823!',
            (
              update value
                    $task/fhir:input/fhir:type/fhir:coding/fhir:system/@value
                    with 
                    "http://eNahar.org/ValueSet/task-input-types"
            ))
    else ()
};

declare function taskmigr:update-1.0-4(
          $task as element(fhir:Task)
        )
{
    if ($task//fhir:extension[@url='#task-recipient-role'])
    then
        let $ext := $task/fhir:restriction/fhir:recipient/fhir:extension[@url='#task-recipient-role']
        return
            let $ref := $ext/fhir:reference/@value/string()
            let $disp := $ext/fhir:display/@value/string()
            return
            system:as-user('vdba', 'kikl823!',
            (
              update replace 
                    $task/fhir:restriction/fhir:recipient/fhir:extension[@url='#task-recipient-role']
                    with 
                    <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#task-recipient-role">
                        <valueReference>
                                <reference value="{$ref}"/>
                                <display value="{$disp}"/>
                        </valueReference>
                    </extension>
            ))
    else ()
};


declare function taskmigr:update-1.0-3(
          $task as element(fhir:Task)
        )
{
        system:as-user('vdba', 'kikl823!',
            (
              update delete $task/fhir:requester/fhir:agent
            , update delete $task/fhir:requester/fhir:onBehalfOf
            ))
};

declare function taskmigr:update-1.0-2(
      $task as element(fhir:Task)
    )
{
    if ($task/fhir:requester/fhir:agent)
    then
        system:as-user('vdba', 'kikl823!',
            (
              update insert <reference xmlns="http://hl7.org/fhir" value="{$task/fhir:requester/fhir:agent/fhir:reference/@value/string()}"/>
                            into $task/fhir:requester
            , update insert <display xmlns="http://hl7.org/fhir" value="{$task/fhir:requester/fhir:agent/fhir:display/@value/string()}"/>
                            into $task/fhir:requester
            , update insert <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/extension#onBehalfOf">
                                <valueReference>
                                    <reference value="metis/organizations/kikl-nspz"/>
                                    <display value="SPZ Kinderklinik Neuropädiatrie"/>
                                </valueReference>
                            </extension>
                            into $task/fhir:requester
            ))
    else ()
};

declare function taskmigr:update-1.0-1(
          $task as element(fhir:Task)
        )
{
    if ($task/fhir:reasonCode)
    then
        system:as-user('vdba', 'kikl823!',
            (
              update delete $task/fhir:reason
            ))
    else ()
};

declare function taskmigr:update-1.0-0(
      $task as element(fhir:Task)
    )
{
    if ($task/fhir:reasonCode)
    then ()
    else
        system:as-user('vdba', 'kikl823!',
            (
              update insert <reasonCode xmlns="http://hl7.org/fhir">
                            { $task/fhir:reason/* }
                            </reasonCode>
                            following $task/fhir:reason
            ))
};

declare function taskmigr:repair-0.9.11-7(
          $task as element(fhir:Task)
        )
{
    if($task/fhir:meta/fhir:extension[@url='#http://eNahar.org/nabu/extension#lastUpdatedBy'])
    then
        system:as-user('vdba', 'kikl823!',
            (
             update value
                    $task/fhir:meta/fhir:extension[@url="#http://eNahar.org/nabu/extension#lastUpdatedBy"]/@url
                    with
                        "http://eNahar.org/nabu/extension#lastUpdatedBy"
            ))
    else ()
};


declare function taskmigr:repair-0.9.11-6(
          $task as element(fhir:Task)
        )
{
    let $ext := $task/fhir:meta/fhir:extension[@url='#lastUpdatedBy']
    return
    if ($ext/fhir:reference)
    then

        let $ref := $ext/fhir:reference/@value/string()
        let $disp := $ext/fhir:display/@value/string()
        return
        system:as-user('vdba', 'kikl823!',
            (
             update replace
                    $task/fhir:meta/fhir:extension[@url="#lastUpdatedBy"]
                    with
                        <extension xmlns="http://hl7.org/fhir" url="#http://eNahar.org/nabu/extension#lastUpdatedBy">
                            <valueReference>
                                <reference value="{$ref}"/>
                                <display value="{$disp}"/>
                            </valueReference>
                        </extension>
            ))
    else
        ()
};


declare function taskmigr:repair-0.9.11-5(
          $task as element(fhir:Task)
        )
{
    try {
        let $start := if ($task/fhir:restriction/fhir:period/fhir:end/@value!='')
            then xs:dateTime($task/fhir:restriction/fhir:period/fhir:end/@value/string())
            else ""
        return
            ""
    } catch * {
        let $new := try {
                    date:easyDateTime($task/fhir:restriction/fhir:period/fhir:end/@value/string())
            } catch * {
                    adjust-dateTime-to-timezone(current-dateTime(),())
            }
        let $upd :=
            system:as-user('vdba', 'kikl823!',
                (
                    update value $task/fhir:restriction/fhir:period/fhir:end/@value with $new
                ))
        return
            $task
    }
};

declare function taskmigr:repair-0.9.11-4(
          $task as element(fhir:Task)
        )
{
    try {
        let $start := if ($task/fhir:restriction/fhir:period/fhir:start/@value!='')
            then xs:dateTime($task/fhir:restriction/fhir:period/fhir:start/@value/string())
            else ""
        return
            ""
    } catch * {
        let $new := try {
                    date:easyDateTime($task/fhir:restriction/fhir:period/fhir:start/@value/string())
            } catch * {
                    adjust-dateTime-to-timezone(current-dateTime(),())
            }
        let $upd :=
            system:as-user('vdba', 'kikl823!',
                (
                    update value $task/fhir:restriction/fhir:period/fhir:start/@value with $new
                ))
        return
            $task
    }
};

declare function taskmigr:migrate-0.9.11-3(
          $task as element(fhir:Task)
        )
{
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
                for $r in $task/fhir:restriction/fhir:recipient
                return
                      update delete $r/fhir:role
            , update delete $task/fhir:lastModified
            , update delete $task/fhir:lastModifiedBy
            ))
    return
        $task
};

declare function taskmigr:migrate-0.9.11-2(
          $task as element(fhir:Task)
        )
{
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update delete $task/fhir:restriction/fhir:deadline
            , for $r in $task/fhir:restriction/fhir:recipient
                let $role :=                     
                        <extension xmlns="http://hl7.org/fhir" url="#task-recipient-role">
                            <valueString value="{$r/fhir:role/@value/string()}"/>
                        </extension>
                return
                    update insert $role following $r/fhir:display
            , update insert <lastUpdated xmlns="http://hl7.org/fhir" value="{$task/fhir:lastModified/@value/string()}"/>
                            into $task/fhir:meta
            , update insert <extension xmlns="http://hl7.org/fhir" url="#lastUpdatedBy">
                                <valueReference>
                                    <reference value="{$task/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                                    <display value="{$task/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                                </valueReference>
                            </extension>
                            into $task/fhir:meta
            ))
    return
        $task
};

declare function taskmigr:migrate-0.9.11-1(
          $task as element(fhir:Task)
        )
{
    let $dl := $task//fhir:deadline/@value/string()
    let $period :=                     
            <period xmlns="http://hl7.org/fhir">
                {$task/fhir:executionPeriod/fhir:start}
                <end value="{$dl}"/>
            </period>
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update insert $period following $task/fhir:restriction/fhir:deadline
            ))
    return
        $task
};

declare function taskmigr:repair-0.9($task as element(fhir:Task))
{
    system:as-user('vdba', 'kikl823!',
            (
              update value $task/fhir:note/fhir:time[starts-with(@value,'adjust')]/@value with $task/fhir:lastModified/@value/string()
            ))
};


(:~
 : migrates pre Nabu 0.8 to Patient v3.0.1 
 : pre 0.8
 :)


declare function taskmigr:update-0.8($task as element(fhir:Task))
{
    system:as-user('vdba', 'kikl823!',
            (
              update replace $task/fhir:meta/fhir:versionID with
                <versionId xmlns="http://hl7.org/fhir" value="{$task/fhir:meta/fhir:versionID/@value/string()}"/>
            , update replace $task/fhir:note with 
                <note  xmlns="http://hl7.org/fhir">
                        <authorReference>
                            <reference value="{$task/fhir:note/fhir:author/fhir:reference/@value/string()}"/>
                            <display value="{$task/fhir:note/fhir:author/fhir:display/@value/string()}"/>
                        </authorReference>
                        <time value="{$task/fhir:note/fhir:time/@value/string()}"/>
                        <text value="{$task/fhir:note/fhir:text/@value/string()}"/>
                </note>
            ))
};


declare function taskmigr:mapOrderPriority($prio)
{
    let $new := switch($prio) 
        case "high"  return "urgent"
        case "low"   return "low"
        default return $prio
    return
        $new
};

declare function taskmigr:mapOrderStatus($status)
{
    let $new := switch($status) 
        case "new"  return "draft"
        case "assigned"   return "received"
        case "accepted"  return "accepted"
        case "closed"   return "completed"
        default return $status
    return
        $new
};

declare function taskmigr:order2task($o as element(fhir:Order)) as element(fhir:Task)
{
    let $d := $o/fhir:detail
    let $task :=
        <Task xmlns="http://hl7.org/fhir" xml:id="{$o/@xml:id/string()}">
            {$o/fhir:id}
            <meta>
                <versionId value="{$o/fhir:meta/fhir:versionID/@value/string()}"/>
            </meta>
            {$o/fhir:lastModifiedBy}
            {$o/fhir:lastModified}
            <definitionReference>
                <reference value=""/>
                <display value=""/>
            </definitionReference>
            <basedOn>
                <reference value=""/>
                <display value=""/>                
            </basedOn>
            <status value="{taskmigr:mapOrderStatus($o/fhir:extension/fhir:status/fhir:coding/fhir:code/@value)}"/>
            <intent value="order"/>
            <priority value="{taskmigr:mapOrderPriority($d/fhir:priority/fhir:coding/fhir:code/@value)}"/>
            <code>
                <coding>
                    <system value="#task-reason"/>
                    <code value="{$o/fhir:reason/fhir:coding/fhir:code/@value/string()}"/>
                    <display value="{$o/fhir:reason/fhir:coding/fhir:display/@value/string()}"/>
                </coding>
                <text value="{$o/fhir:reason/fhir:text/@value/string()}"/>
            </code>
            <description value="{$d/fhir:summary/@value/string()}"/>
            <for>
                <reference value="{$o/fhir:subject/fhir:reference/@value/string()}"/>
                <display value="{$o/fhir:subject/fhir:display/@value/string()}"/>
            </for>
            <executionPeriod>
                <start value=""/>
                <end value=""/>
            </executionPeriod>
            <authoredOn value="{$o/fhir:date/@value/string()}"/>
            <requester>
                <agent>
                    <reference value="{$o/fhir:source/fhir:reference/@value/string()}"/>
                    <display value="{$o/fhir:source/fhir:display/@value/string()}"/>
                </agent>
                <onBehalfOf>
                    <reference value="{$o/fhir:authority/fhir:reference/@value/string()}"/>
                    <display value="{$o/fhir:authority/fhir:display/@value/string()}"/>
                </onBehalfOf>
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
                <reference value="{$o/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                <display value="{$o/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
            </owner>
            <reason>
                <text value="spz"/>
            </reason>
            <note>
                <authorReference>
                    <reference value="{$o/fhir:source/fhir:reference/@value/string()}"/>
                    <display value="{$o/fhir:source/fhir:display/@value/string()}"/>
                </authorReference>
                <time value="{$o/fhir:date/@value/string()}"/>
                <text value="{$d/fhir:info/@value/string()}"/>
            </note>
            {
                if ($d/fhir:comment/@value ='')
                then ()
                else 
                    <note>
                        <authorReference>
                            <reference value="{$o/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                            <display value="{$o/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                        </authorReference>
                        <time value="{$o/fhir:lastModified/@value/string()}"/>
                        <text value="{$d/fhir:comment/@value/string()}"/>
                    </note>
            }
            <restriction>
                <deadline value="{$o/fhir:when/fhir:schedule/fhir:event/@value/string()}"/>
                <recipient>
                    <role value="{$o/fhir:target/fhir:role/@value/string()}"/>
                    <reference value="{$o/fhir:target/fhir:reference/@value/string()}"/>
                    <display value="{$o/fhir:target/fhir:display/@value/string()}"/>
                </recipient>
            </restriction>
            <input>
                <type>
                    <coding>
                        <system value="#task-input-types"/>
                        <code value="tags"/>
                    </coding>
                </type>
                <valueString value="{$d/fhir:tags/@value/string()}"/>
            </input>
        </Task>
    return
        $task
};
