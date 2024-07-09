xquery version "3.0";
module namespace goal = "http://enahar.org/exist/apps/nabu/goal";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";


declare function goal:fillTemplate(
      $cat as xs:string
    )
{
    let $category := switch($cat)
        case 'treatment' return 'treatment'
        default return $cat
    return
        <Goal xmlns="http://hl7.org/fhir">
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <lifecycleStatus value="proposed"/>
            <achievementStatus>
                <coding>
                    <system value="http://hl7.org/fhir/ValueSet/goal-achievement"/>
                    <code value="in-progress"/>
                </coding>
                <text value="in Arbeit"/>
            </achievementStatus>
            <category>
                <coding> 
                    <system value="http://hl7.org/fhir/goal-category"/> 
                    <code value="{$category}"/> 
                </coding>                 
            </category>
            <priority>
                <coding> 
                    <system value="http://hl7.org/fhir/goal-priority"/> 
                    <code value="medium-priority"/> 
                    <display value="mittel"/> 
                </coding> 
                <text value="mittel"/>                
            </priority>
            <description>
                <text value=""/>
            </description>
            <subject>
                <reference value=""/>
                <display value=""/>
            </subject>
            <startDate value=""/>
            <target>
                <measure>
                    <coding>
                        <system value=""/>
                        <code value=""/>
                        <display value=""/>
                    </coding>
                    <text value=""/>                    
                </measure>
                <dueDate value=""/>
            </target>
            <statusDate value=""/>
            <statusReason value=""/>
            <expressedBy>
                <reference value=""/>
                <display value=""/>
            </expressedBy>
        </Goal>
};
