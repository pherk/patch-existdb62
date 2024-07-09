xquery version "3.1";

module namespace pravail = "http://enahar.org/exist/apps/metis/pravail";


declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";



declare function pravail:mkAvailGroup() 
{
    <xf:group  ref="instance('i-account')" class="svFullGroup bordered">
        <xf:label>Anwesenheiten</xf:label>
        <table>
            <thead>
                <td>
                    <xf:label>WorkTime </xf:label>
                    <xf:trigger>
                        <xf:label>+</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert
                                nodeset="instance('i-account')/*:availableTime"
                                context="instance('i-account')"
                                origin="instance('i-pinfos')/*:bricks/*:availableTime"/>
                        </xf:action>
                    </xf:trigger>
                    <xf:trigger>
                        <xf:label>-</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:delete
                                nodeset="instance('i-account')/*:availableTime"
                                at="index('tce-avails-id')"/>
                        </xf:action>
                    </xf:trigger>
                </td>
            </thead>
            <tbody>
                <tr><td>
                    <xf:repeat id="tce-avails-id"
                            ref="./*:availableTime" appearance="compact" class="svRepeat">
                        <xf:select1 ref="./*:daysOfWeek/@value" class="medium-input">
                            <xf:label class="svRepeatHeader">Wochentag</xf:label>
                            <xf:itemset nodeset="instance('i-pinfos')/*:daysOfWeek/*:code">
                                <xf:label ref="./@label-ger"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                        </xf:select1>
                        <xs:input ref="./*:allDay/@value"  class="xsdBoolean svRepeatBool">
                            <xf:label class="svRepeatHeader">Ganzer Tag?</xf:label>
                        </xs:input>
                        <xf:input ref="./*:availableStartTime/@value">
                            <xf:label class="svRepeatHeader">Beginn</xf:label>
                        </xf:input>
                        <xf:input ref="./*:availableEndTime/@value">
                            <xf:label class="svRepeatHeader">Ende</xf:label>
                        </xf:input>
                    </xf:repeat>
                </td>
                </tr>
            </tbody>
        </table>
    </xf:group>
};

