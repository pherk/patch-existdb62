xquery version "3.0";
module namespace careplan = "http://enahar.org/exist/apps/nabu/careplan";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

import module namespace r-careplan = "http://enahar.org/exist/restxq/nabu/careplans" at "/db/apps/nabu/FHIR/CarePlan/careplan-routes.xqm";


declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";


declare function careplan:getCP(
      $subject as element(fhir:subject)
    , $realm as xs:string
    , $author as element(fhir:author)
    , $title as xs:string
    , $request as item()*
    ) as element(fhir:CarePlan)
{
    let $loguid := substring-after($author/fhir:reference/@value,'metis/practitioners/')
    let $lognam := $author/fhir:display/@value/string()
    let $act := careplan:request2activity($request,$author,$title)
    let $cps := r-careplan:careplansXML($realm,$loguid,$lognam,'',$subject/fhir:id/@value,'active','full')
    return
        if (count($cps/fhir:CarePlan)>0)
        then
            let $cp := ($cps/fhir:CarePlan[fhir:title/@value=$title],$cps/fhir:CarePlan)[1]
            let $upd := system:as-user('vdba', 'kikl823!',
                    (
                        update insert $request
                            following $cp/fhir:note
                    ))
            return
                $cp
        else 
            let $content := careplan:mkCarePlan(
                      $subject
                    , $author
                    , ()
                    , $title
                    , ''
                    ,$act)
            let $cp := r-careplan:putCarePlanXML(document {$content},$realm,$loguid,$lognam)
            return
                $cp[local-name(.)='CarePlan']
};

declare function careplan:request2activity(
      $action as item()*
    , $author as element(fhir:author)
    , $title as xs:string
    ) as element(fhir:activity)*
{
    for $a in $action
    return
        let $ref := switch(local-name($action))
            case 'Order' return concat('nabu/orders/',$action/fhir:id/@value)
            case 'Task'  return concat('nabu/tasks/',$action/fhir:id/@value)
            default return 
                let $lll := util:log-app('ERROR','apps.nabu',concat('invalid action type: ',local-name($action)))
                return ()
        let $dsp := $action/fhir:description/@value/string()
        return
            <activity xmlns="http://hl7.org/fhir">
                <outcomeCodeableConcept>
                    <coding>
                        <system value="http://snomed.info/sct"/> 
                        <code value=""/> 
                        <display value=""/>
                    </coding>
                    <text value=""/>
                </outcomeCodeableConcept>
                <outcomeReference>
                    <reference value=""/>
                    <display value=""/>
                </outcomeReference>
                <reference>
                    <reference value="{$ref}"/>
                    <display value="{$dsp}"/>
                </reference>
                <progress>
                    <authorReference>
                        <reference value="{$author/fhir:reference/@value/string()}"/>
                        <display value="{$author/fhir:display/@value/string()}"/>
                    </authorReference>
                    <time value="{adjust-dateTime-to-timezone(current-dateTime(),())}"/>
                    <text value="{concat('angelegt über ',$title)}"/>           
                </progress>
            </activity>
};

declare function careplan:mkCarePlan(
      $subject as element(fhir:subject)
    , $author as element(fhir:author)
    , $definition as element(fhir:definition)?
    , $title as xs:string
    , $description as xs:string
    , $activity as element(fhir:activity)*
    ) as element(fhir:CarePLan)
{
        <CarePlan xmlns="http://hl7.org/fhir">
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            { $definition }
            <status value="active"/>
            <intent value="order"/>
            <title value="{$title}"/>
            <description value="{$description}"/>
            { $subject }
            <period>
                <start value="{adjust-dateTime-to-timezone(current-dateTime(),())}"/>
                <end value=""/>
            </period>
            { $author }
            <note>
                <authorReference>
                    <reference value="{$author/fhir:reference/@value/string()}"/>
                    <display value="{$author/fhir:display/@value/string()}"/>
                </authorReference>
                <time value="{adjust-dateTime-to-timezone(current-dateTime(),())}"/>
                <text value="{concat('angelegt über ',$title)}"/>           
            </note>
            { $activity }
        </CarePlan>
};
