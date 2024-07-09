xquery version "3.0";

module namespace tasklist = "http://enahar.org/exist/apps/nabu/task-list";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
import module namespace xqtime = "http://enahar.org/lib/xqtime";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

declare namespace fhir= "http://hl7.org/fhir";
declare namespace tei=  "http://www.tei-c.org/ns/1.0";

declare %private function tasklist:ccs(
        $ccs as element(fhir:recipient)*
    ) as xs:string?
{
    string-join(
          for $cc in $ccs
          return
            if (string-length($cc/fhir:display/@value)>0)
            then
                $cc/fhir:display/@value
            else 
                $cc/fhir:extension[@url='#task-recipient-role']/fhir:valueString/@value
        , ' <> '
        )
};

declare function tasklist:prepareSimpleList(
      $tasks as element(fhir:Task)*
    , $params as map(*)
    ) as element(tei:TEI)
{
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header("Taskliste") }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                    <head>Task-Liste</head>
                    <list>
                        { 
                            for $key in map:keys($params)
                            order by $key
                            return
                                <item><emph>{$key}</emph>: {map:get($params,$key)}</item>
                        }
                    </list>
                </div>
                <div>
                    <table rows="{count($tasks)}" cols="4:4:4:5"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <row role="label">
                            <cell role="label">Anfrager</cell>
                            <cell role="label">CC</cell>
                            <cell role="label">Patient</cell>
                            <cell role="label">Betreff</cell>
                        </row>
                    {
                        for $t in $tasks
                        order by $t/fhir:requester/fhir:display/@value/string()
                        return
                            (
                              <row role="data">
                                <cell role="data">{$t/fhir:requester/fhir:display/@value/string()}</cell>
                                <cell role="data">{tasklist:ccs($t/fhir:restriction/fhir:recipient)}</cell>
                                <cell role="data">{$t/fhir:for/fhir:display/@value/string()}</cell>
                                <cell role="data">{$t/fhir:description/@value/string()}</cell>
                              </row>
                            , <row role="data">
                                <cell role="data" cols="4">{string-join($t/fhir:note/fhir:text/@value,' <> ')}</cell>
                              </row>
                            , <row role="data">
                                <cell role="data" cols="4">---</cell>
                              </row>
                            )
                    }
                    </table>
                </div>
            </body>
        </text>
    </TEI>
    return $result
};

declare function tasklist:prepareTeamList(
      $tasks as element(fhir:Task)*
    , $params as map(*)
    ) as element(tei:TEI)
{
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header("Taskliste für Team") }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                    <head>Task-Liste für Team</head>
                    <list>
                        { 
                            for $key in map:keys($params)
                            order by $key
                            return
                                <item><emph>{$key}</emph>: {map:get($params,$key)}</item>
                        }
                    </list>
                </div>
                <div>
                    <table rows="{count($tasks)}" cols="4:4:4:5"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <row role="label">
                            <cell role="label">Anfrager</cell>
                            <cell role="label">CC</cell>
                            <cell role="label">Patient</cell>
                            <cell role="label">Betreff</cell>
                        </row>
                    {
                        for $t in $tasks
                        order by $t/fhir:requester/fhir:display/@value/string()
                        return
                            (
                              <row role="data">
                                <cell role="data">{$t/fhir:requester/fhir:display/@value/string()}</cell>
                                <cell role="data">{tasklist:ccs($t/fhir:restriction/fhir:recipient)}</cell>
                                <cell role="data">{$t/fhir:for/fhir:display/@value/string()}</cell>
                                <cell role="data">{$t/fhir:description/@value/string()}</cell>
                              </row>
                            , <row role="data">
                                <cell role="data" cols="4">{$t/fhir:note[1]/fhir:text/@value/string()}</cell>
                              </row>
                            , <row role="data">
                                <cell role="data" cols="4">{$t/fhir:note[2]/fhir:text/@value/string()}</cell>
                              </row>
                            , <row role="data">
                                <cell role="data" cols="4">---</cell>
                              </row>
                            )
                    }
                    </table>
                </div>
            </body>
        </text>
    </TEI>
    return $result
};
