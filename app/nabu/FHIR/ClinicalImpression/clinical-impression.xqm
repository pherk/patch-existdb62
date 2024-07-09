xquery version "3.0";
module namespace clinImpression = "http://enahar.org/exist/apps/nabu/clinical-impression";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";
import module namespace r-user = "http://enahar.org/exist/restxq/metis/users"      at "/db/apps/metis/FHIR/user/user-routes.xqm";
import module namespace r-clinImpression = "http://enahar.org/exist/restxq/nabu/clinical-impressions" at "/db/apps/nabu/FHIR/Task/clinimpression-routes.xqm";
import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients" at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";


declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";

declare function clinImpression:fillTemplate()
{
        <ClinicalImpression xmlns="http://hl7.org/fhir">
            <id value=""/>
            <meta>
                <versionId value="0"/>
            </meta>
        	<identifier/>
        	<status value="completed"/>
    	    <code>
                <coding>
            	    <system value="http://snomed.info/sct"/>
            	    <code value=""/>
                    <display value=""/>
                </coding>
                <text value=""/>        		    
    	    </code>
        	<description value=""/>
        	<subject>
        	    <reference value=""/>
        	    <display value=""/>
        	</subject>
    	    <context>
    	        <reference value=""/>
    	    </context>
        	<effectiveDateTime value=""/>
    	    <date value=""/>
        	<assessor>
        	    <reference value=""/>
        	    <display value=""/>
        	</assessor>
        	<previous><!-- 0..1 Reference(ClinicalImpression) Reference to last assessment --></previous>
    	    <problem/>
        	<investigation>  <!-- 0..* One or more sets of investigations (signs, symptions, etc.) -->
        		<code>
            	    <coding>
            	        <system value="http://snomed.info/sct"/>
            	        <code value=""/>
        	            <display value=""/>
        	        </coding>
            	    <text value=""/>        		    
        		</code>
    		    <item><!-- 0..* Reference(Observation|QuestionnaireResponse|FamilyMemberHistory|
    DiagnosticReport|RiskAssessment|ImagingStudy) Record of a specific investigation -->
                    <display value=""/>
                </item>
    	    </investigation>
	        <protocol value=""/><!-- 0..* Clinical Protocol followed -->
        	<summary value=""/><!-- 0..1 Summary of the assessment -->
	        <finding>  <!-- 0..* Possible or likely findings and diagnoses -->
		        <itemCodeableConcept><!-- 1..1 CodeableConcept|Reference(Condition|Observation) What was found -->
		            <text value=""/>
		        </itemCodeableConcept>
    		    <basis value="[string]"/><!-- 0..1 Which investigations support finding -->
	        </finding>
        	<prognosisCodeableConcept>
        	    <coding>
        	        <system value="http://snomed.info/sct"/>
        	        <code value=""/>
        	        <display value=""/>
        	    </coding>
        	    <text value=""/>
        	</prognosisCodeableConcept>
	        <prognosisReference>
	            <reference value=""/>
	        </prognosisReference>
	        <action/>
        </ClinicalImpression>
};
