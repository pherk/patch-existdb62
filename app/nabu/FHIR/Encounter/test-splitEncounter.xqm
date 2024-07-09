xquery version "3.1";

import module namespace commsub = "http://enahar.org/exist/apps/nabu/comm-submit" at "/db/apps/nabu/FHIR/Communication/comm-submit.xqm";

declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";

let $new := 
(
        <Encounter xmlns="http://hl7.org/fhir" xml:id="e-6aefb826-7bc5-4d12-ac37-77177cada119">
        <id value="e-6aefb826-7bc5-4d12-ac37-77177cada119"/>
        <meta>
            <versionId value="0"/>
        </meta>
        <lastModifiedBy>
            <reference value="metis/practitioners/c-a91274e3-4ac3-4d47-b9f2-736dff0eaf82"/>
            <display value="Boeckmann, Kerstin"/>
        </lastModifiedBy>
        <lastModified value="2018-06-28T15:17:32.35"/>
        <definition>
            <reference value=""/>
            <display value=""/>
        </definition>
        <basedOn>
            <reference value="nabu/careplans/c-fa6dbd86-3b89-4eb6-89c3-2f052452eee1"/>
            <display value="Request Import"/>
        </basedOn>
        <priority value="0"/>
        <status value="planned"/>
        <class value="AMB"/>
        <type>
            <coding>
                <system value="#encounter-type"/>
                <code value="amb-spz-ortho-qr"/>
                <display value="Ortho Queen Rania"/>
            </coding>
            <text value="Ortho Queen Rania"/>
        </type>
        <subject>
            <reference value="nabu/patients/p-22208"/>
            <display value="Spachowski, Casper, *2013-07-10"/>
        </subject>
        <participant>
            <type>
                <coding>
                    <system value="#encounter-role"/>
                    <code value="spz-ortho"/>
                    <display value="spz-ortho"/>
                </coding>
                <text value="spz-ortho"/>
            </type>
            <period>
                <start value="2018-09-14T08:00:00"/>
                <end value="2018-09-14T08:15:00"/>
            </period>
            <individual>
                <reference value="metis/practitioners/c-1789"/>
                <display value="Ellerich, Karl Josef"/>
            </individual>
        </participant>
        <appointment>
            <reference value="nabu/orders/o-cb957134-d70e-438a-ba0b-a8771931f2cb?detail=1"/>
        </appointment>
        <period>
            <start value="2018-09-14T08:00:00"/>
            <end value="2018-09-14T08:15:00"/>
        </period>
        <reasonCode>
            <coding>
                <system value="#encounter-reason"/>
                <code value="amb"/>
                <display value="Amb. Besuch"/>
            </coding>
            <text value="Amb. Besuch - WV"/>
        </reasonCode>
        <serviceProvider>
            <reference value="metis/organizations/kikl-spz"/>
            <display value="SPZ Kinderklinik"/>
        </serviceProvider>
        <location>
            <location>
                <reference value="metis/locations/kikl-spz"/>
                <display value="SPZ KiKl"/>
            </location>
            <status value="planned"/>
            <period>
                <start value="2018-09-14T08:00:00"/>
                <end value="2018-09-14T08:15:00"/>
            </period>
        </location>
    </Encounter>
    , <Encounter xmlns="http://hl7.org/fhir" xml:id="e-6aefb826-7bc5-4d12-ac37-77177cada119">
        <id value="e-6aefb826-7bc5-4d12-ac37-77177cada119"/>
        <meta>
            <versionId value="0"/>
        </meta>
        <lastModifiedBy>
            <reference value="metis/practitioners/c-a91274e3-4ac3-4d47-b9f2-736dff0eaf82"/>
            <display value="Boeckmann, Kerstin"/>
        </lastModifiedBy>
        <lastModified value="2018-06-28T15:17:32.35"/>
        <definition>
            <reference value=""/>
            <display value=""/>
        </definition>
        <basedOn>
            <reference value="nabu/careplans/c-fa6dbd86-3b89-4eb6-89c3-2f052452eee1"/>
            <display value="Request Import"/>
        </basedOn>
        <priority value="0"/>
        <status value="planned"/>
        <class value="AMB"/>
        <type>
            <coding>
                <system value="#encounter-type"/>
                <code value="amb-spz-eeg"/>
                <display value="EEG"/>
            </coding>
            <text value="Arzt"/>
        </type>
        <subject>
            <reference value="nabu/patients/p-22208"/>
            <display value="Spachowski, Casper, *2013-07-10"/>
        </subject>
        <participant>
            <type>
                <coding>
                    <system value="#encounter-role"/>
                    <code value="spz-ortho"/>
                    <display value="spz-ortho"/>
                </coding>
                <text value="spz-ortho"/>
            </type>
            <period>
                <start value="2018-09-14T08:00:00"/>
                <end value="2018-09-14T08:15:00"/>
            </period>
            <individual>
                <reference value="metis/practitioners/c-1789"/>
                <display value="Ellerich, Karl Josef"/>
            </individual>
        </participant>
        <appointment>
            <reference value="nabu/orders/o-cb957134-d70e-438a-ba0b-a8771931f2cb?detail=1"/>
        </appointment>
        <period>
            <start value="2018-09-14T09:00:00"/>
            <end value="2018-09-14T09:15:00"/>
        </period>
        <reasonCode>
            <coding>
                <system value="#encounter-reason"/>
                <code value="amb"/>
                <display value="Amb. Besuch"/>
            </coding>
            <text value="Amb. Besuch - WV"/>
        </reasonCode>
        <serviceProvider>
            <reference value="metis/organizations/kikl-spz"/>
            <display value="SPZ Kinderklinik"/>
        </serviceProvider>
        <location>
            <location>
                <reference value="metis/locations/kikl-spz"/>
                <display value="SPZ KiKl"/>
            </location>
            <status value="planned"/>
            <period>
                <start value="2018-09-14T08:00:00"/>
                <end value="2018-09-14T08:15:00"/>
            </period>
        </location>
    </Encounter>
    , <Encounter xmlns="http://hl7.org/fhir" xml:id="e-6aefb826-7bc5-4d12-ac37-77177cada119">
        <id value="e-6aefb826-7bc5-4d12-ac37-77177cada119"/>
        <meta>
            <versionId value="0"/>
        </meta>
        <lastModifiedBy>
            <reference value="metis/practitioners/c-a91274e3-4ac3-4d47-b9f2-736dff0eaf82"/>
            <display value="Boeckmann, Kerstin"/>
        </lastModifiedBy>
        <lastModified value="2018-06-28T15:17:32.35"/>
        <definition>
            <reference value=""/>
            <display value=""/>
        </definition>
        <basedOn>
            <reference value="nabu/careplans/c-fa6dbd86-3b89-4eb6-89c3-2f052452eee1"/>
            <display value="Request Import"/>
        </basedOn>
        <priority value="0"/>
        <status value="planned"/>
        <class value="AMB"/>
        <type>
            <coding>
                <system value="#encounter-type"/>
                <code value="amb-spz-arzt"/>
                <display value="Arzt"/>
            </coding>
            <text value="Arzt"/>
        </type>
        <subject>
            <reference value="nabu/patients/p-22208"/>
            <display value="Spachowski, Casper, *2013-07-10"/>
        </subject>
        <participant>
            <type>
                <coding>
                    <system value="#encounter-role"/>
                    <code value="spz-ortho"/>
                    <display value="spz-ortho"/>
                </coding>
                <text value="spz-ortho"/>
            </type>
            <period>
                <start value="2018-09-14T08:00:00"/>
                <end value="2018-09-14T08:15:00"/>
            </period>
            <individual>
                <reference value="metis/practitioners/c-1789"/>
                <display value="Ellerich, Karl Josef"/>
            </individual>
        </participant>
        <appointment>
            <reference value="nabu/orders/o-cb957134-d70e-438a-ba0b-a8771931f2cb?detail=1"/>
        </appointment>
        <period>
            <start value="2018-09-14T09:00:00"/>
            <end value="2018-09-14T09:15:00"/>
        </period>
        <reasonCode>
            <coding>
                <system value="#encounter-reason"/>
                <code value="amb"/>
                <display value="Amb. Besuch"/>
            </coding>
            <text value="Amb. Besuch - WV"/>
        </reasonCode>
        <serviceProvider>
            <reference value="metis/organizations/kikl-spz"/>
            <display value="SPZ Kinderklinik"/>
        </serviceProvider>
        <location>
            <location>
                <reference value="metis/locations/kikl-spz"/>
                <display value="SPZ KiKl"/>
            </location>
            <status value="planned"/>
            <period>
                <start value="2018-09-14T08:00:00"/>
                <end value="2018-09-14T08:15:00"/>
            </period>
        </location>
    </Encounter>
)

let $old :=
(
    <Encounter xmlns="http://hl7.org/fhir" xml:id="e-6aefb826-7bc5-4d12-ac37-77177cada119">
        <id value="e-6aefb826-7bc5-4d12-ac37-77177cada119"/>
        <meta>
            <versionId value="0"/>
        </meta>
        <lastModifiedBy>
            <reference value="metis/practitioners/c-a91274e3-4ac3-4d47-b9f2-736dff0eaf82"/>
            <display value="Boeckmann, Kerstin"/>
        </lastModifiedBy>
        <lastModified value="2018-06-28T15:17:32.35"/>
        <definition>
            <reference value=""/>
            <display value=""/>
        </definition>
        <basedOn>
            <reference value="nabu/careplans/c-fa6dbd86-3b89-4eb6-89c3-2f052452eee1"/>
            <display value="Request Import"/>
        </basedOn>
        <priority value="0"/>
        <status value="planned"/>
        <class value="AMB"/>
        <type>
            <coding>
                <system value="#encounter-type"/>
                <code value="amb-spz-arzt"/>
                <display value="Arzt"/>
            </coding>
            <text value="Arzt"/>
        </type>
        <subject>
            <reference value="nabu/patients/p-22208"/>
            <display value="Spachowski, Casper, *2013-07-10"/>
        </subject>
        <participant>
            <type>
                <coding>
                    <system value="#encounter-role"/>
                    <code value="spz-ortho"/>
                    <display value="spz-ortho"/>
                </coding>
                <text value="spz-ortho"/>
            </type>
            <period>
                <start value="2018-09-16T08:00:00"/>
                <end value="2018-09-16T08:15:00"/>
            </period>
            <individual>
                <reference value="metis/practitioners/c-1789"/>
                <display value="Ellerich, Karl Josef"/>
            </individual>
        </participant>
        <appointment>
            <reference value="nabu/orders/o-cb957134-d70e-438a-ba0b-a8771931f2cb?detail=1"/>
        </appointment>
        <period>
            <start value="2018-09-14T09:00:00"/>
            <end value="2018-09-14T09:15:00"/>
        </period>
        <reasonCode>
            <coding>
                <system value="#encounter-reason"/>
                <code value="amb"/>
                <display value="Amb. Besuch"/>
            </coding>
            <text value="Amb. Besuch - WV"/>
        </reasonCode>
        <serviceProvider>
            <reference value="metis/organizations/kikl-spz"/>
            <display value="SPZ Kinderklinik"/>
        </serviceProvider>
        <location>
            <location>
                <reference value="metis/locations/kikl-spz"/>
                <display value="SPZ KiKl"/>
            </location>
            <status value="planned"/>
            <period>
                <start value="2018-09-14T08:00:00"/>
                <end value="2018-09-14T08:15:00"/>
            </period>
        </location>
    </Encounter>
)

return
    commsub:splitEncounters($new,$old)