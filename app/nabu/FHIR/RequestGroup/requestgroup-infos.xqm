<requestgroup-infos>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="draft">
        <state id="draft">
            <transition target="active" event="activate"/>
        </state>
        <state id="active">
            <transition target="cancelled" event="cancel"/>
            <transition target="completed" event="finish"/>
            <transition target="suspended" event="suspend"/>
            <state id="suspended">
                <transition target="active" event="reactivate"/>
            </state>
        </state>

        <state id="cancelled">
            <transition target="active" event="reactivate"/>
        </state>
        <state id="completed">
            <transition target="active" event="reactivate"/>
        </state>
    </scxml>
    <fhir-state>
        <code label-de="inaktiv" value="draft"/>
        <code label-de="aktiv" value="active"/>
        <code label-de="beendet" value="completed"/>
        <code label-de="angehalten" value="suspended"/>
        <code label-de="abgebrochen" value="cancelled"/>
        <code label-de="Fehler" value="entered-in-error"/>
        <code label-de="???" value="unknown"/>
    </fhir-state>
    <intent>
        <code label-de="Vorschlag" value="proposal"/>
        <code label-de="Plan" value="plan"/>
        <code label-de="Order" value="order"/>
    </intent>
    <priority>
        <code label-de="Routine" value="routine"/>
        <code label-de="dringend" value="urgent"/>
        <code label-de="sbwm" value="asap"/>
        <code label-de="sofort" value="stat"/>
    </priority>
    <action-relationship>
Code	Display	Definition
before-start	Before Start	The action must be performed before the start of the related action.
before	Before	The action must be performed before the related action.
before-end	Before End	The action must be performed before the end of the related action.
concurrent-with-start	Concurrent With Start	The action must be performed concurrent with the start of the related action.
concurrent	Concurrent	The action must be performed concurrent with the related action.
concurrent-with-end	Concurrent With End	The action must be performed concurrent with the end of the related action.
after-start	After Start	The action must be performed after the start of the related action.
after	After	The action must be performed after the related action.
after-end	After End	The action must be performed after the end of the related action.
    </action-relationship>
    <action-type>
    Code	Display	Definition
create	Create	The action is to create a new resource.
update	Update	The action is to update an existing resource.
remove	Remove	The action is to remove an existing resource.
fire-event	Fire Event	The action is to fire a specific event.
    </action-type>
    <action-condition-kind>
Code	Display	Definition
applicability	Applicability	The condition describes whether or not a given action is applicable.
start	Start	The condition is a starting condition for the action.
stop	Stop	The condition is a stop, or exit condition for the action.
    </action-condition-kind>
    <bricks>
        <RequestGroup xmlns="http://hl7.org/fhir">
            <id value=""/>
            <status value="draft"/>
            <intent value="order"/>
            <priority value="routine"/>
            <code>
                <coding>
                    <system value=""/>
                    <code value=""/>
                </coding>
                <text value=""/>
            </code>
            <subject>
                <reference value=""/>
                <display value=""/>
            </subject>
            <authoredOn value="[dateTime]"/>
            <author>
                <reference value=""/>
                <display value=""/>                
            </author>
            <reasonCode>
                <coding>
                    <code value=""/>
                    <display value=""/>
                </coding>
                <text value=""/>
            </reasonCode>
        </RequestGroup>
        <identifier>
            <use value="[code]"/><!-- 0..1 usual | official | temp | secondary | old (If known) -->
            <type>
                <coding>
                    <system value=""/>
                    <code value=""/>
                </coding>
                <text value=""/>
            </type>
            <system value="[uri]"/>
            <value value="[string]"/>
            <period>
                <start value=""/>
            </period>
            <assigner>
                <reference value=""/>
                <display value=""/>
            </assigner>            
        </identifier>
        <instantiatesCanonical value=""/>
        <instantiatesURI value=""/>
        <basedOn>
            <reference value=""/>
            <diaply value=""/>
        </basedOn>
        <replaces>
            <reference value=""/>
            <diaplay value=""/>
        </replaces>
        <groupIdentifier>
            <value value=""/>
        </groupIdentifier>
        <code>
            <coding>
                <system value=""/>
                <code value=""/>
            </coding>
            <text value=""/>
        </code>
        <encounter>
            <reference value=""/>
            <diaply value=""/>            
        </encounter>
        <reasonReference>
            <reference value=""/>
            <display value=""/>
        </reasonReference>
        <action>
            <prefix value="[string]"/><!-- 0..1 User-visible label for the action (e.g. 1. or A.) -->
            <title value="[string]"/><!-- 0..1 User-visible title -->
            <description value="[string]"/><!-- 0..1 Short description of the action -->
            <textEquivalent value="[string]"/><!-- 0..1 Static text equivalent of the action, used if the dynamic aspects cannot be interpreted by the receiving system -->
            <priority value=""/>
            <code>
                <coding>
                    <system value=""/>
                    <code value=""/>
                </coding>
                <text value=""/>                
            </code>
            <documentation><!-- 0..* RelatedArtifact Supporting documentation for the intended performer of the action --></documentation>
            <timingPeriod><!-- 0..1 dateTime|Period|Duration|Range|Timing When the action should take place --></timingPeriod>
            <participant><!-- 0..* Reference(Patient|Person|Practitioner|RelatedPerson) Who should perform the action --></participant>
            <type>
                <coding>
                    <system value="http://hl7.org/fhir/ValueSet/action-type"/>
                    <code value=""/>
                </coding>
                <text value=""/>                
            </type>
            <groupingBehavior value="[code]"/><!-- 0..1 visual-group | logical-group | sentence-group -->
            <selectionBehavior value="[code]"/><!-- 0..1 any | all | all-or-none | exactly-one | at-most-one | one-or-more -->
            <requiredBehavior value="[code]"/><!-- 0..1 must | could | must-unless-documented -->
            <precheckBehavior value="[code]"/><!-- 0..1 yes | no -->
            <cardinalityBehavior value="[code]"/><!-- 0..1 single | multiple -->
            <resource>
                <reference value=""/>
                <display value=""/>
            </resource>
        </action>
        <note>
            <author>
                <reference value=""/>
                <display value=""/>
            </author>
            <time value=""/>
            <text value=""/>
        </note>
        <condition>
            <kind value="[code]"/>
            <description value="[string]"/><!-- 0..1 Natural language description of the condition -->
            <language value="[string]"/><!-- 0..1 Language of the expression -->
            <expression value="[string]"/><!-- 0..1 Boolean-valued expression -->
        </condition>
        <relatedAction>  <!-- 0..* Relationship to another action -->
            <actionId value="[id]"/><!-- 1..1 What action this is related to -->
            <relationship value="[code]"/><!-- 1..1 before-start | before | before-end | concurrent-with-start | concurrent | concurrent-with-end | after-start | after | after-end -->
            <offsetRange><!-- 0..1 Duration|Range Time offset for the relationship --></offsetRange>
        </relatedAction>
    </bricks>
</requestgroup-infos>