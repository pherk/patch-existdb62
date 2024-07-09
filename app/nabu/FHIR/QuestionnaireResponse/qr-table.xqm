xquery version "3.0";

module namespace qr-table = "http://enahar.org/exist/apps/nabu/qr-table";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
import module namespace xqtime = "http://enahar.org/lib/xqtime";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

declare namespace fhir= "http://hl7.org/fhir";

declare function qr-table:prepareQRTable(
      $qr as element(fhir:QuestionnaireResponse)
    )
{
    let $header := "BayleyIII"
    let $date := "20181-07-01T10:00:00"
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header($header) }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                {
                    (: enumerate days in period :)
                    for $n in (0 to 1)
                    return
                    <table rows="5" cols="3.5:2:7:4"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <head>BayleyIII-Testergebnisse von {format-dateTime($date,'[D01].[M01].[Y01]')}</head>
                            <row role="label">
                                    <cell role="label">Uhrzeit</cell>
                                    <cell role="label">OE</cell>
                                    <cell role="label">Patient</cell>
                                    <cell role="label">Erbringer</cell>
                            </row>
                    {
                        for $a in (1,2,3,4,5)
                        let $scale := "10"
                        let $raw := "10" 
                        order by $raw
                        return
                        <row role="data">
                            <cell role="data">{$raw}</cell>
                            <cell role="data">{$scale}</cell>
                            <cell role="data">{$a}</cell>
                            <cell role="data">{$a}</cell>
                        </row>
                    }
                    </table>
                }
                </div>
            </body>
        </text>
    </TEI>
    return $result
};
