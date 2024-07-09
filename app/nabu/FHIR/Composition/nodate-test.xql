xquery version "3.1";
declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:normalize-month($m)
{
    switch($m)
        case 'Jan' return '01'
        case 'Feb' return '02'
        case 'Apr' return '04'
        case 'Mai' return '05'
        case 'Jun' return '06'
        case 'Jul' return '07'
        case 'Aug' return '08'
        case 'Sep' return '09'
        case 'Okt' return '10'
        case 'Nov' return '11'
        case 'Dez' return '12'
        case 'Januar' return '01'
        case 'Februar' return '02'
        case 'März' return '03'
        case 'April' return '04'
        case 'Mai' return '05'
        case 'Juni' return '06'
        case 'Juli' return '07'
        case 'August' return '08'
        case 'September' return '09'
        case 'Oktober' return '10'
        case 'November' return '11'
        case 'Dezember' return '12'
        default return $m
};

declare function local:analyze-date($dl)
{
    let $toks := analyze-string($dl/string(), $import:regexp-dateline)

    let $day := $toks/fn:match/fn:group[@nr=1]/string()
    let $mon0 := ($toks/fn:match//fn:group[@nr=3]/string(), $toks/fn:match//fn:group[@nr=4]/string())[1]

    let $mon := if (string(number($mon0)) != 'NaN')
        then $mon0
        else import:normalize-month($mon0)
    let $year:= $toks/fn:match/fn:group[@nr=5]/string()
    let $year := ($year)[1]
    let $isoyear := if (string-length($year) = 2)
            then if (xs:integer($year) > 50)
                then concat('19',$year)
                else concat('20',$year)
            else $year
    let $gdate:= string-join(($day,$mon,$year),'.')
};

declare function local:possibleDate($c)
{
    let $dn := tokenize($c/fhir:section/fhir:code/fhir:text/@value,": ")[2]
    let $ci := doc('/db/apps/nabuCom/import/' || $dn)
    let $y0 := substring-after(tokenize($dn,'/')[1],'Befunde')
    let $y1 := if (string-length($y0)=2) then $y0 else substring($y0,1,2)
    let $y  := "20" || $y1
    return
        <letter path="{$dn}" y="{$y}">
        {
        for $p in $ci/body//p
        return
            if (matches($p,$y) or matches($p,$y1))
            then
              let $dtks := tokenize($p,'/')
              return
                if (count($dtks)=2 and string-length($dtks[1])<25)
                then
                  <possible-date when="{local:analyze-date($dtks[1])}">{$dtks[1]}</possible-date>
                else if (matches($p,'am .*' || $y0))
                then
                  <possible-date-first-sentence>{$p/string()}</possible-date-first-sentence>
                else ()
            else ()
        }</letter>
};

let $cc := collection('/db/apps/nabuComposition/data/nodate')
let $cs := $cc/fhir:Composition
let $ls := 
    <nodate>{
        for $c in subsequence($cs,1,10)
            return
                local:possibleDate($c)
    }</nodate>
return
    system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabu/statistics/evals","composition-nodate.xml",$ls))
    
    