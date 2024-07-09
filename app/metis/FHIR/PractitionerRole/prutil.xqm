xquery version "3.1";

module namespace prutil = "http://enahar.org/exist/apps/metis/prutil";


declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";


declare function prutil:mkMainGroup() {
        <xf:group  ref="instance('i-account')" class="svFullGroup bordered">
            <xf:input id="a-name" ref="./*:name[*:use/@value='official']/*:family/@value" class="">
                <xf:label class="svListHeader">Name:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:output id="a-alias" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#metis-account']/*:value/@value" class="medium-input">
                <xf:label class="svListHeader">Alias:</xf:label>
            </xf:output>
            <xf:input id="a-persid" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#ukk-idm']/*:value/@value" class="medium-input">
                <xf:label class="svListHeader">PersID:</xf:label>
            </xf:input>
            { prutil:mkDetailGroup() }
            { prutil:mkTelecomGroup()}
        </xf:group>
};

declare function prutil:mkAdminGroup() {
        <xf:group  ref="instance('i-account')" class="svFullGroup bordered">
            <xf:input id="a-name" ref="./*:practitioner/*:display/@value" class="">
                <xf:label class="svListHeader">Nabu-Name:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:input id="a-alias" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#metis-account']/*:value/@value" class="medium-input">
                <xf:label class="svListHeader">Alias:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:input id="a-persid" ref="./*:identifier[*:system/@value='http://eNahar.org/nabu/system#ukk-idm']/*:value/@value" class="medium-input">
                <xf:label class="svListHeader">PersID:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:input>
            <xf:input id="a-active" ref="./*:active/@value" class="">
                <xf:label class="svListHeader">Active:</xf:label>
            </xf:input>
            { prutil:mkRBACGroup() }
            <br/>
            { prutil:mkDetailGroup() }
            { prutil:mkTelecomGroup()}
        </xf:group>
};

declare %private function prutil:mkRBACGroup() {
        <xf:group ref="instance('i-account')">
            <xf:select1 id="a-org" ref="./*:organization/*:reference/@value">
                <xf:label class="svListHeader">Org:</xf:label>
                    <xf:itemset nodeset="instance('i-organizations')/*:Organization">
                        <xf:label ref="./*:name/@value"/>
                        <xf:value ref="./*:identifier/*:value/@value"/>
                    </xf:itemset>
                    <xf:action ev:event="xforms-value-changed">
                        <xf:setvalue ref="instance('i-account')/*:organization/*:display/@value"
                                value="instance('i-organizations')/*:Organization[./*:identifier/*:value/@value=instance('i-account')/*:organization/*:reference/@value]/*:name/@value"/>
                    </xf:action>
            </xf:select1>
            <xf:group class="svFullGroup bordered">
                <xf:label>Roles</xf:label>
                <xf:group ref="instance('i-views')/has-no-roles">
                    <p>No roles defined yet.</p>
                </xf:group>
                <xf:repeat id="r-role-id" ref="./*:code/*:coding" appearance="compact" class="svRepeat multicol">
                    <xf:select1 ref="./*:code/@value" class="">
                        <xf:itemset nodeset="instance('i-roles')/*:Group">
                            <xf:label ref="./*:name/@value"/>
                            <xf:value ref="./*:code/*:text/@value"/>
                        </xf:itemset>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue ref="instance('i-account')/*:code/*:coding[index('r-role-id')]/*:display/@value"
                                value="instance('i-roles')/*:Group[./*:code/*:text/@value=instance('i-account')/*:code/*:coding[index('r-role-id')]/*:code/@value]/*:name/@value"/>
                            <xf:setvalue ref="instance('i-account')/*:code/*:text/@value"
                                value="instance('i-account')/*:code/*:coding[index('r-role-id')]/*:display/@value"/>
                        </xf:action>
                    </xf:select1>
                </xf:repeat>
                <xf:group appearance="minimal" class="svTriggerGroup">
                    <table>
                        <tr>
                            <td>
                                <xf:trigger class="svAddTrigger" >
                                    <xf:label>New</xf:label>
                                    <xf:action ev:event="DOMActivate">
                                        <xf:insert position="after" at="index('r-role-id')"
                                            nodeset="instance('i-account')/*:code/*:coding"
                                            context="instance('i-account')/*:code"
                                            origin="instance('i-bricks')/*:code/*:coding"/>
                                    </xf:action>
                                </xf:trigger>
                            </td>
                            <td>
                                <xf:trigger  ref="instance('i-views')/delete-role" class="svDelTrigger">
                                    <xf:label>Delete</xf:label>
                                    <xf:delete ev:event="DOMActivate"
                                        nodeset="instance('i-account')/*:code/*:coding" at="index('r-role-id')"/>
                                </xf:trigger>
                            </td>
                        </tr>
                    </table>
                </xf:group>
            </xf:group>
            <xf:textarea id="a-details" ref="./details" class="fullareashort">
                <xf:label class="svListHeader">Details:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:textarea>
            <xf:textarea id="a-note" ref="./notes" class="fullareashort">
                <xf:label class="svListHeader">Notizen:</xf:label>
                <xf:alert>a string is required</xf:alert>
            </xf:textarea>
        </xf:group>
};

declare %private function prutil:mkDetailGroup()
{
    <xf:group ref="instance('i-account')" class="svFullGroup bordered">
        <xf:label>Details</xf:label><br/>
        <xf:select1 id="tce-specialty" ref="./*:specialty/*:coding/*:code/@value" class="medium-input">
            <xf:label>Beruf</xf:label>
            <xf:itemset nodeset="instance('i-pinfos')/profs/prof">
                <xf:label ref="./@label"/>
                <xf:value ref="./@value"/>
            </xf:itemset>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-account')/*:specialty/*:coding/*:display/@value"
                    value="instance('i-pinfos')/profs/prof[./@value=instance('i-account')/*:specialty/*:coding/*:code/@value]/@label"/>
                <xf:setvalue ref="instance('i-account')/*:specialty/*:text/@value"
                    value="instance('i-account')/*:specialty/*:coding/*:display/@value"/>
            </xf:action>
        </xf:select1>
        <xf:select1 id="tce-loc" ref="*:location/*:display/@value">
            <xf:label>Büro:</xf:label>
            <xf:itemset nodeset="instance('i-rooms')/*:Location">
                <xf:label ref="./*:name/@value"/>
                <xf:value ref="./*:name/@value"/>
            </xf:itemset>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-account')/*:location/*:reference/@value"
                    value="concat('metis/locations/',instance('i-rooms')/*:Location[*:name/@value=instance('i-account')/*:location/*:display/@value]/*:id/@value)"/>
            </xf:action>
        </xf:select1>
        <xf:select1 id="tce-hcs" ref="*:healthcareService/*:display/@value">
            <xf:label>Service:</xf:label>
            <xf:itemset nodeset="instance('i-pinfos')/hcs/healthcareService">
                <xf:label ref="./@label-ger"/>
                <xf:value ref="./@value"/>
            </xf:itemset>
            <xf:action ev:event="xforms-value-changed">
                <xf:setvalue ref="instance('i-account')/*:healthcareService/*:reference/@value"
                    value="concat('metis/locations/',instance('i-pinfos')/*:hcs/*:healthcareService[*:value/@value=instance('i-account')/*:healthcareService/*:display/@value]/*:id/@value)"/>
            </xf:action>
        </xf:select1>
        <xf:textarea id="tce-note" ref="./*:extension[@url='http://eNahar.org/metis/url#note']/*:note/@value" class="fullarea">
            <xf:label>Notiz:</xf:label>
        </xf:textarea>
    </xf:group>
};


declare %private function prutil:mkTelecomGroup()
{
    <xf:group  ref="instance('i-account')" class="svFullGroup bordered">
        <xf:label>Telecom</xf:label>
        <table>
            <thead>
                <td>
                    <xf:label>Work </xf:label>
                    <xf:trigger>
                        <xf:label>+</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:insert
                                nodeset="instance('i-account')/*:telecom[*:use/@value='work']"
                                context="instance('i-account')"
                                origin="instance('i-pinfos')/*:bricks/*:telecom[*:use/@value='work']"/>
                        </xf:action>
                    </xf:trigger>
                    <xf:trigger>
                        <xf:label>-</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:delete
                                nodeset="instance('i-account')/*:telecom[*:use/@value='work']"
                                at="index('tce-work-id')"/>
                        </xf:action>
                    </xf:trigger>
                </td>
            </thead>
            <tbody>
                <tr><td>
                    <xf:repeat id="tce-work-id"
                            ref="./*:telecom[*:use/@value='work']" appearance="compact" class="svRepeatHalf">
                        <xf:select1 ref="./*:system/@value" class="short-input">
                            <xf:label class="svRepeatheader">System</xf:label>
                            <xf:itemset nodeset="instance('i-pinfos')/telecom/system">
                                <xf:label ref="./@label"/>
                                <xf:value ref="./@value"/>
                            </xf:itemset>
                        </xf:select1>
                        <xf:input ref="./*:value/@value">
                            <xf:label class="svRepeatHeader">Nr:</xf:label>
                        </xf:input>
                    </xf:repeat>
                </td>
                </tr>
            </tbody>
        </table>
    </xf:group>
};

