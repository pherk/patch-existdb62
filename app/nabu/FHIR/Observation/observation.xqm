xquery version "3.0";

(:~
 : observation module
 :
 : ?? why no recipient in FHIR 1.5
 : 
 : @author Peter Herkenrath 
 : @version 1.0
 : @see http://enahar.org
 :
 :)

module namespace obs="http://enahar.org/exist/apps/nabu/observation";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace fhir= "http://hl7.org/fhir";

(:~
 : fillTemplate
 : makes Observation resource
 :  
 : @param $subject   subject 
 : 
 : @return Observation
 :) 
declare function obs:fillTemplate(
        $subject as item()
      )
{
        <Observation>
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
            <status value="preliminary"/>
            <code>
                <coding>
                    <system value=""/>
                    <code value=""/>
                    <display value=""/>
                </coding>
                <text value=""/>
            </code>
            { $subject }
            <effectiveDateTime value=""/>
            <issued value=""/>
            <comment value=""/>
        </Observation>
};

