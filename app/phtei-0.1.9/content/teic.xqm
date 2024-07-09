xquery version "3.0";


(: 
 : TEI  module
 : common functions, tests
 : 
 :)
module namespace teic = "http://enahar.org/lib/teic";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function teic:table2tei($data as node()*, $facets as node()) as node()?
{
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    { teic:header("Kontaktdaten") }
        <text xml:lang="en">
        { teic:front()}
        { teic:tabulate($data, $facets)}
        </text>
    </TEI>
};

declare function teic:front()
{
    <front xmlns="http://www.tei-c.org/ns/1.0">
        <titlePage>
            <docTitle>
                <titlePart type="main">THOMAS OF Reading.</titlePart>
                <titlePart type="alt">OR, The sixe worthy yeomen of the West.</titlePart>
            </docTitle>
            <docEdition>Now the fourth time corrected and enlarged</docEdition>
            <byline>By T.D.</byline>
            <figure>
                <head>TP</head>
                <p>Thou shalt labor till thou returne to duste</p>
                <figDesc>Printers Ornament used by TP</figDesc>
            </figure>
            <docImprint>Printed at <name type="place">London</name> for <name>T.P.</name>
                <date>1612.</date>
            </docImprint>
        </titlePage>
    </front>
};

declare function teic:tabulate($data as node()*, $facets as node()) as node()?
{
    <body xmlns="http://www.tei-c.org/ns/1.0">
    <div>
        <table rows="{count($data)}" cols="5">
        {
            for $r in $data
            return
            <row role="label">
                <cell role="data">{$r/*:name/*:family/@value/string()}</cell>
                <cell role="data">{$r/*:address/*:postalCode/@value/string()}</cell>
                <cell role="data">{$r/*:address/*:city/@value/string()}</cell>
                <cell role="data">{$r/*:address/*:line/@value/string()}</cell>
                <cell role="data">{$r/*:telecom[*:use/@value='work']/*:value/@value/string()}</cell>
            </row>
        }
            </table>
        </div>
    </body>
};

declare function teic:header($title)
{
    <teiHeader xmlns="http://www.tei-c.org/ns/1.0">
        <fileDesc>
            <titleStmt>
                <title>{$title}</title>
                <author>SPZ Ambulanzteam</author>
                <respStmt>
                    <resp>prepared by</resp>
                    <name>Metis</name>
                </respStmt>
            </titleStmt>
            <publicationStmt>
                <distributor>SPZ der Kinderklinik</distributor>
                <address>
                    <addrLine>Kerpener Str. 62, 50737 Köln</addrLine>
                </address>
                <availability>
                    <p>Freely available on a non-commercial basis.</p>
                </availability>
                <date when="2015">2015</date>
            </publicationStmt>
            <sourceDesc>
                <p>Daten aus der Metis Datenbank</p>
            </sourceDesc>
        </fileDesc>
    </teiHeader>
};


