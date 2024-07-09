xquery version "3.0";

module namespace enc-orphans = "http://enahar.org/exist/apps/nabu/encounter-orphans";


import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole" 
               at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";

declare variable $enc-orphans:restxq-orphans      := "/exist/restxq/nabu/orphans";

declare variable $enc-orphans:encounter-infos-uri := "/exist/apps/nabu/FHIR/Encounter/encounter-infos.xml";

declare function enc-orphans:orphan-view()
{
    let $today := adjust-date-to-timezone(current-date(),())
    let $status := 
        (
          <status>planned</status>
        , <status>tentative</status>
        )
    let $logu   := r-practrole:userByAlias(sm:id()//sm:real/sm:username/string())
    let $prid := $logu/fhir:id/@value/string()
    let $uref := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid   := substring-after($uref,'metis/practitioners/')
    let $unam  := $logu/fhir:practitioner/fhir:display/@value/string()
    let $start := dateTime($today,xs:time("08:00:00"))
    let $end   := $start + xs:dayTimeDuration("P7D")
    let $realm := "kikl-spz"
    let $head  := 'Termine' 
    return
(<div style="display:none;">
    <xf:model id="m-orphans" xmlns:fhir="http://hl7.org/fhir">
        <xf:instance  xmlns="" id="i-encs">
            <data/>
        </xf:instance>

        <xf:submission id="s-get-encounters"
                    ref="instance('i-search')"
                	instance="i-encs"
					method="get"
					replace="instance">
			<xf:resource value="concat('{$enc-orphans:restxq-orphans}/encounters?loguid=',encode-for-uri('{$uid}'),'&amp;lognam=',encode-for-uri('{$unam}'),'&amp;realm=',encode-for-uri('{$realm}'))"/>
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">error get-orphans</xf:message>
        </xf:submission>
        
        <xf:instance xmlns="" id="i-search">
            <parameters>
                <start>1</start>
                <length>*</length>
                <uid></uid>
                <group></group>
                <sched/>
                <patient/>
                <rangeStart>{$start}</rangeStart>
                <rangeEnd>{$end}</rangeEnd>
                { $status }
                <_sort>date:asc</_sort>
            </parameters>
        </xf:instance>

        <xf:instance xmlns="" id="i-dateTime">
            <data>
                <startdate>{$today}</startdate>
                <enddate>{xs:date($end)}</enddate>
                <nofd>7</nofd>
            </data>
        </xf:instance>
        <xf:bind ref="instance('i-dateTime')/*:startdate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:enddate" type="xs:date"/>
        <xf:bind ref="instance('i-dateTime')/*:nofd" type="xs:integer" constraint=". &gt; 0"/>
        
        <xf:action ev:event="xforms-model-construct-done">
            <xf:send submission="s-get-encounters"/>
        </xf:action>
    </xf:model>
</div>
,<xf:group class="svFullGroup bordered">
    <xf:label>Verwaiste Termine</xf:label>
    <table>
        <tr>
            <td colspan="4">
                <xf:group class="svFullGroup">
                    <xf:label>Zeitraum</xf:label><br/>
                    <xf:input ref="instance('i-dateTime')/*:startdate" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'">
                        <xf:label class="svListHeader">Start:</xf:label>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue 
                                ref="instance('i-dateTime')/*:nofd"
                                value="(xs:date(instance('i-dateTime')/*:enddate) - xs:date(instance('i-dateTime')/*:startdate)) div xs:dayTimeDuration('P1D') + 1"/>
                            <xf:action>
                                <xf:setvalue
                                    ref="instance('i-search')/*:rangeStart"
                                    value="concat(instance('i-dateTime')/*:startdate,'T08:00:00')"/>
                                <xf:send submission="s-get-encounters"/>
                            </xf:action>
                        </xf:action>
                    </xf:input>
                    <xf:input ref="instance('i-dateTime')/*:enddate" appearance="bf:iso8601" data-bf-params="date:'dd.MM.yyyy'">
                        <xf:label class="svListHeader">Ende:</xf:label>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue 
                                ref="instance('i-dateTime')/*:nofd"
                                value="(xs:date(instance('i-dateTime')/*:enddate) - xs:date(instance('i-dateTime')/*:startdate)) div xs:dayTimeDuration('P1D') + 1"/>
                            <xf:action>
                                <xf:setvalue
                                    ref="instance('i-search')/*:rangeEnd"
                                    value="concat(instance('i-dateTime')/*:enddate,'T20:00:00')"/>
                                <xf:send submission="s-get-encounters"/>
                            </xf:action>
                        </xf:action>
                    </xf:input>
                    <xf:output ref="instance('i-dateTime')/*:nofd">
                        <xf:label>Anzahl Tage</xf:label>
                    </xf:output>
                </xf:group>
            </td>
        </tr>
        <tr>
            <td>
                <xf:group class="svFullGroup bordered">
                    <xf:label>Termine</xf:label><br/>
                    <xf:repeat id="r-orphan-ids" ref="instance('i-encs')/*:Encounter" appearance="compact" class="svRepeat">
            <xf:output value="tokenize(./*:period/*:start/@value,'T')[1]">
                <xf:label class="svListHeader">Datum:</xf:label>                        
            </xf:output>
            <xf:output value="concat(format-dateTime(./*:period/*:start/@value, '[H1]:[m01]'),'-',format-dateTime(./*:period/*:end/@value, '[H1]:[m01]'))">
                <xf:label class="svListHeader">Von-Bis:</xf:label>                        
            </xf:output>
            <xf:output ref="./partOf/display/@value" class="">
                <xf:label>Kombi</xf:label>
            </xf:output>
            <xf:output ref="./*:subject/*:display/@value">
                <xf:label class="svListHeader">Patient:</xf:label>
            </xf:output>
            <xf:output ref="./*:reasonCode/*:text/@value">
                <xf:label class="svListHeader">Anlass</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant/*:type/*:coding/*:code/@value">
                <xf:label class="svListHeader">Service:</xf:label>                        
            </xf:output>
            <xf:output ref="./*:participant/*:individual/*:display/@value">
                <xf:label class="svListHeader">Erbringer:</xf:label>                        
            </xf:output>
            <xf:output value="./*:status/@value">
                <xf:label class="svListHeader">Status:</xf:label>                        
            </xf:output>
                    </xf:repeat>
                </xf:group>
            </td>
        </tr>
    </table>
</xf:group>
)
};