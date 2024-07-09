xquery version "3.0";

let $leaves := 
    <leaves>
        <leave xml:id="l-3faeef73-1d6c-4097-b744-3249855313af">
        <id value="l-4bb25066-b996-41d7-a098-be438299f64e"/>
        <meta>
            <tag>
                <text value=""/>
            </tag>
            <versionID value="3"/>
        </meta>
        <lastModifiedBy>
            <reference value="metis/practitioners/c-05287e3c-283e-47dc-bf4e-60202fa96d5c"/>
            <display text="Armbrust"/>
        </lastModifiedBy>
        <lastModified value="2016-03-16T11:36:28.201+01:00"/>
        <identifier>
            <value value=""/>
        </identifier>
        <cause>
            <coding>
                <code value="V"/>
                <display value="Vertretung"/>
            </coding>
        </cause>
        <actor>
            <reference value="metis/practitioners/u-martakisk"/>
            <display value="Martakis, Kyriakos"/>
        </actor>
        <allDay value="true"/>
        <summary value="Springer April"/>
        <description value=""/>
        <status>
            <coding>
                <code value="confirmed"/>
                <display value="bestätigt"/>
            </coding>
        </status>
        <period>
            <start value="2016-04-04T00:00:00"/>
            <end value="2016-04-13T23:59:59"/>
        </period>
    </leave>
    <leave xml:id="l-436f173d-1f76-48ef-a9a3-53e5fa162591">
        <id value="l-5cf2c2dd-1a03-4088-8ce1-d33998118029"/>
        <meta>
            <tag>
                <text value=""/>
            </tag>
            <versionID value="1"/>
        </meta>
        <lastModifiedBy>
            <reference value="metis/practitioners/metis/practitioners/u-martakisk"/>
            <display text=""/>
        </lastModifiedBy>
        <lastModified value="2016-03-05T17:01:23.328+01:00"/>
        <identifier>
            <value value=""/>
        </identifier>
        <cause>
            <coding>
                <code value="KS1"/>
                <display value="Spätdienst-1"/>
            </coding>
        </cause>
        <actor>
            <reference value="metis/practitioners/u-martakisk"/>
            <display value="Martakis, Kyriakos"/>
        </actor>
        <allDay value="false"/>
        <summary value="Spätdienst"/>
        <description value=""/>
        <status>
            <coding>
                <code value="tentative"/>
                <display value="provisorisch"/>
            </coding>
        </status>
        <period>
            <start value="2016-04-07T00:00:00"/>
            <end value="2016-04-07T11:00:00"/>
        </period>
    </leave>
    <leave xml:id="l-c82dc035-d34e-42cd-9c1f-0fb999f62980">
        <id value="l-312b36a9-2a89-4e89-ae49-bdd24fec3dde"/>
        <meta>
            <tag>
                <text value=""/>
            </tag>
            <versionID value="1"/>
        </meta>
        <lastModifiedBy>
            <reference value="metis/practitioners/metis/practitioners/u-martakisk"/>
            <display text=""/>
        </lastModifiedBy>
        <lastModified value="2016-03-05T17:01:23.328+01:00"/>
        <identifier>
            <value value=""/>
        </identifier>
        <cause>
            <coding>
                <code value="KS1"/>
                <display value="Spätdienst-1"/>
            </coding>
        </cause>
        <actor>
            <reference value="metis/practitioners/u-martakisk"/>
            <display value="Martakis, Kyriakos"/>
        </actor>
        <allDay value="false"/>
        <summary value="Spätdienst"/>
        <description value=""/>
        <status>
            <coding>
                <code value="tentative"/>
                <display value="provisorisch"/>
            </coding>
        </status>
        <period>
            <start value="2016-04-08T00:00:00"/>
            <end value="2016-04-08T11:00:00"/>
        </period>
    </leave>
</leaves>

let $date := xs:date('2016-04-14')
let $actor := 'metis/practitioners/u-martakisk'
    let $lll := util:log-system-out($date)
    let $cnt := count($leaves/leave[actor/reference/@value=$actor][allDay/@value/string()='true'][xs:date(tokenize(period/start/@value,'T')[1])<=$date][xs:date(tokenize(period/end/@value,'T')[1])>=$date])
    return
        $cnt > 0
