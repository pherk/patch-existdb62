xquery version "3.0";

(:~
 : Composition module
 :
 : ?? why no recipient in FHIR 1.5
 : 
 : @author Peter Herkenrath 
 : @version 1.0
 : @see http://enahar.org
 :
 :)

module namespace composition="http://enahar.org/exist/apps/nabu/composition";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace fhir= "http://hl7.org/fhir";


        
declare variable $composition:appinfo :=
<TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
        <fileDesc>
            <titleStmt>
                <title>Letter to Family: Appointment</title>
            </titleStmt>
            <publicationStmt>
                <p>Published as an example for a appointment letter.</p>
            </publicationStmt>
            <sourceDesc>
                <p>No source: born digital.</p>
            </sourceDesc>
        </fileDesc>
    </teiHeader>
</TEI>;

(:~
 : fillTemplate
 : makes Composition resource
 :  
 : @param $payload
 : @param $authors   authors
 : @param $subject   subject 
 : @param $recipient recipient aka Überweisender Arzt
 : 
 : @return Composition
 :) 
declare function composition:fillTemplate(
        $payload as item()
      , $subject as item()
      , $group as xs:string
      , $authors as item()+
      , $recipients as item()*
      , $dateline as element(tei:dateline)?
      , $source as xs:string
      )
{
    let $date := if ($dateline)
        then concat($dateline/tei:date/@when, 'T08:00:00')
        else if ($payload//tei:dateline/tei:date)
        then concat($payload//*:dateline/tei:date/@when, 'T08:00:00')
        else ''
    let $report-title := $group
    let $report-type := $group
    return
<Composition xmlns="http://hl7.org/fhir">
    <id value=""/>
    <meta>
        <versionId value="0"/>
    </meta>
    <identifier/>

    <type>
        <coding>
            <system value="http://loinc.org"/>
            <code value="60568-3"/>
            <display value="synoptic report"/>
        </coding>
    </type>
    <category>
        <coding>
            <system value="http://loinc.org"/>
            <code value="173421-1"/>
            <display value="Report"/>
        </coding>
        <text value="{$report-type}"/>
    </category>
    { $subject }
    <encounter>
        <reference value=""/>
    </encounter>
    <date value="{$date}"/>
    { $authors }
    <title value="{concat($subject/fhir:display/@value, ' - ', $date)}"/>
    <status value="final"/>
    <confidentiality value="N"/>
    { if (count($recipients)>0)
        then
            for $rec in $recipients
            return
            <extension url="http://eNahar.org/nabu/extension/composition-recipient">
                <valueReference>
                { $rec }
                </valueReference>
            </extension>
        else ()
    }
    <attester>
        <mode value="official"/>
        <time value=""/>
        <party>
            <reference value="metis/organizations/kikl-spz"/>
            <display value="SPZ Kinderklinik"/>
        </party>
    </attester>
    <custodian>
        <reference value="metis/organizations/kikl-spz"/>
        <display value="SPZ Kinderklinik"/>        
    </custodian>
    <event>
        <code>
            <coding>
                <system value="#nabu-event"/>
                <code value="ambulant"/>
                <display value="ambulante Vorstellung"/>
            </coding>
            <text value="ambulante Vorstellung"/>
        </code>
        <period>
            <start value=""/>
            <end value=""/>
        </period>
        <detail></detail>
    </event>
    <section>
        <title value="{$report-title}"/>
        <code>
            <coding>
                <system value="#nabu-report"/>
                <code value="report"/>
                <display value="medical report"/>
            </coding>
            <coding>
                <system value="#nabu-report-source"/>
                <code value="{$source}"/>
                <display value="{$source}"/>
            </coding>
            <text value="{concat($group,': ',$source)}"/>
        </code>
        <text>
            <status value="imported"/>
            { $payload/tei:div }
        </text>
        <mode value="working"/>
    </section>
</Composition>
};

