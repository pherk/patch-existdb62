xquery version "3.0";
(:~
: transformation of xhtml converted docs to TEIP5 model
: @author Peter Herkenrath (C) 2016
: @version 0.7.11
: @see http://enahar.org
:
:)
module namespace dl2tei = "http://enahar.org/exist/apps/nabudocs/dl2tei";

declare variable $dl2tei:regexp-nameclass := "[\wäöüÄÖÜßáéó-]+";
declare variable $dl2tei:regexp-namechars := "\wäöüÄÖÜßáéó-";
declare variable $dl2tei:regexp-name  :=
    concat(
          "("
        , $dl2tei:regexp-nameclass
        , "), ("
        , $dl2tei:regexp-nameclass
        , "[ "
        , $dl2tei:regexp-namechars
        , "]*)|("
        , $dl2tei:regexp-nameclass
        , "[ "
        , $dl2tei:regexp-namechars
        , "]*) ("
        , $dl2tei:regexp-nameclass
        , ")");
declare variable $dl2tei:regexp-birth := "((\d+)\.(\d+)\.(\d+))";
declare variable $dl2tei:regexp-family-given-birth2 :=
    concat(
          "(("
        , $dl2tei:regexp-nameclass
        , ")([, ]?)("
        , $dl2tei:regexp-nameclass
        , ")([,: ]*)(?:(geboren|geb.|\*)? *(?:am )?)((\d+)\.[ ]?(\d+)\.[ ]?(\d+)))"
        );
declare variable $dl2tei:regexp-family-given-birth3 :=
    concat(
          "(("
        , $dl2tei:regexp-nameclass
        , ")(, ?)("
        , $dl2tei:regexp-nameclass
        , "[ "
        , $dl2tei:regexp-namechars
        , "]*)"
        , "([,: ]*)(?:(geboren|geb.|\*)? *(?:am )?)((\d+)\.[ ]?(\d+)\.[ ]?(\d+)))"
        );
declare variable $dl2tei:regexp-phys :=
    concat(
          '((Frau|Herrn|Herr|Praxis)?#?'
        , '(PD|OA|OÄ)? ?(Dr\.[ ]?)?(med. ?)?'
        , '([A-Z][a-z]?\. *([A-Z][a-z]?\.)*|[a-zA-ZäöüßÄÖÜ\-]+)?'
        , ' '
        , '([a-zA-ZäöüßÄÖÜ\-]+)#'
        , '([a-zA-ZäöüßÄÖÜ\p{P} \d]+)#?'
        , '([\d]{4,5})? ?([a-zA-ZäöüßÄÖÜ\-\d ]+)?)'
        );
declare variable $dl2tei:regexp-signees :=
    concat(
          '(?: )?((PD|OA|OÄ)?( )?(Dr\.[ ]?(med.[ ]?))?'
        , '([A-Z][a-z]?[a-z]?\. *([A-Z][a-z]?\.)*|[a-zA-ZäöüßÄÖÜ\-]+)?'
        , ' '
        , '([a-zA-ZäöüßÄÖÜ\-]+))'
        );
declare variable $dl2tei:regexp-procs :=
    string-join(
    (
       "^(.*(EEG|ERG|VEP|SEP|MRT)[^:]?):$"
    ,  "^(Achse [IV]+)"
    ), '|');
declare variable $dl2tei:regexp-roles := string-join(
(
  "(?: )?(((Leiter|OÄ|Oberärztin) Sozial- (u\.|und) Neuropädiatrie)"
, "(Leiter (Sozialpädiatrisches Zentrum|des SPZ))"
, "((Arzt|Ärztin|(Fach|Assistenz)(arzt|ärztin)) (für|f\.) (Kinder- und Jugendmedizin))"
, "((Ober|Funktionsober|Ambulanz|Assistenz|Kinder)(arzt|ärztin))"
, "(Orthopäde)"
, "((?:(OA|OÄ) )?Orthopädie(?:(-Kinderklinik)?))"
, "(Neuropädiatrie)"
, "(Arzt f\. Kinder- und Jugendpsychiatrie und -psychotherapie)"
, "(Pädiatrische Endokrinologie und Diabetologie)"
, "((Ergo|Physio)therapeutin)"
, "(Logopädin)"
, "((Dipl\.[ -]|Diplom-)Psycholog(e|in)|Diplompsycholog(e|in))"
, "(Kinder- und Jugendlichenpsychotherapeutin)"
, "(Psychologischer Psychotherapeut|Psychologische Psychotherapeutin|Psychol\. Psychotherapeutin \(VT\))"
, "(Dipl\.- Psych\./ Dipl\.-Päd\.)"
, "(Klinische Neuropsychologin GNP))"
), '|');

declare variable $dl2tei:regexp-dateline := "(\d+)\.[ ]?((\d+)\.|([A-Z][a-zä]+))[ ]?(\d+)([ /]*[^ /]*)";

declare function dl2tei:ltrans($l,$filename)
{
    (: let $lll := util:log-app('DEBUG','apps.nabu',$filename) :)
    (: step 1+2 deleting header div, logo img :)
    (: step 3: Klinikdirektor :)
    let $body := $l/*:body

    let $subheader := normalize-space(subsequence($body/*:p,1,2)[matches(.,'Prof')])
    (: step 4: Adresse, Subject, Datum :)
    let $start0 := dl2tei:elementsAfterHeader($body)
    let $start := if (matches($start0[1],'Köln, den'))
        then subsequence($start0,2)
        else $start0

let $lll := util:log-app('DEBUG','apps.nabu',$start0[1])

    let $opener := dl2tei:opener($body, $start0[1], $filename)

let $lll := util:log-app('DEBUG','apps.nabu','closer')

    (: step 5 Intro :)
    (: step 6: Diagnosen :)
    (: step 7: Therapien :)
    (: step 8: Gruß, Unterschriften :)
    (: step 9 Durchschläge, Postscript :)
    let $closer := dl2tei:closer($body)
    (: step 10 Text :)
 
let $lll := util:log-app('DEBUG','apps.nabu','text')

    let $text := 
        let $retsl := $start[matches(.,'[mM]it freundlichen')] | $start[dl2tei:nameAlike(.)]
        let $tps   :=
            if ($retsl)
            then
                let $end := dl2tei:index-of-node($start,$retsl[1])-1
                return subsequence($start,1,$end)
            else $start
let $lll := util:log-app('DEBUG','apps.nabu',count($tps))
        let $mps := dl2tei:text($tps)
(: 
let $lll := util:log-app('DEBUG','apps.nabu',$mps)
:)
        return
            dl2tei:mergeps($mps)

    let $body   :=
        <div xmlns="http://www.tei-c.org/ns/1.0" type="letter-body">
            { $text }
        </div>
    let $letter :=
        <body xmlns="http://www.tei-c.org/ns/1.0">
            <div class="letter">
                <div class="header">{$subheader}</div>
                { $opener }
                { $body }
                { $closer }
            </div>
        </body>
    return
        $letter
};

declare function dl2tei:index-of-node
  ( $nodes as node()* ,
    $nodeToFind as node() )  as xs:integer* {

  for $seq in (1 to count($nodes))
  return $seq[$nodes[$seq] is $nodeToFind]
 } ;
 
declare function dl2tei:closer($body)
{
    if (dl2tei:hasGreeting($body) or dl2tei:nameAlike($body))
    then
        let $ps := $body/*:p
        let $retcl := dl2tei:closerForward(head($ps),subsequence($ps,2))
        let $closer  := 
                if ($retcl/ok)
                then
                    $retcl/*:value/*:closer
                else
                    util:log-app('DEBUG','apps.nabu',$retcl/error)

        let $psp0 := for $p in $retcl/*:cont/*:p
            return (: filter out empty par and old footer :)
                if (normalize-space($p)='' or ($p/*:span/@id and $p/*:span/@id=('Frame1','Frame2')) or matches($p,'(Steuernummer|ÖPNV)'))
                    then
                        ()
                    else
                        $p
        (: there are letters with naked span as cc elements :)
        let $psp := if (count($psp0) = 0)
            then $body/*:span[matches(.,'(D/|d/)')]
            else $psp0
        let $postscript := if ($retcl/ok and count($psp)>0)
        then 
            <list xmlns="http://www.tei-c.org/ns/1.0" type="cclist" rend="">
            {
                for $p in $psp
                return
                    <item xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</item>
            }
            </list>
        else ()
        return
            ($closer,$postscript)
    else ()
};

declare function dl2tei:intro($body)
{
    let $intro := 
        if (dl2tei:hasSpanHeader($body))
        then 
            let $ps := dl2tei:elementsAfterHeader($body)
            return
                $ps[matches(.,"(ich berichte|wir berichten)")]
                (: w/o 2nd header table row :)
        else if (dl2tei:hasBodyTable($body))
        then (: collect p before header table;  :)
            dl2tei:paraBetweenTables($body)[normalize-space(.)!='']
    else
        let $ps := dl2tei:elementsAfterHeader($body)
        let $din :=
            (: w/o 2nd header table row :)
            if (count($body/*:table[1]/*:tr)=2)
            then $ps[matches(.,"(ich berichte|wir berichten)")]
            else $body/*:table[1]/*:tr[3]/*:td[1]/*:p[matches(.,"(ich berichte|wir berichten)")]
        return
            $din
    return
        for $p in $intro
        return
            <p xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</p>
};

declare function dl2tei:paraBetweenTables($body)
{   
    (: Kayessian method of node-set intersection would be better :)
    $body/*:p/preceding-sibling::*:table[1]/preceding-sibling::*:p[preceding-sibling::*:table] (: [matches($body/*:table[2]/*:tr[1]/*:td[1]/*:p,'Name')]] :)
};

declare function dl2tei:elementsAfterHeader($body)
{
    if (dl2tei:hasSpanHeader($body))
    then if ($body/*:p/*:span[@id="Rahmen4"])
        then
            $body/*[preceding-sibling::*:p[*:span[@id="Rahmen4"][last()]]]
        else 
            $body/*[preceding-sibling::*:p[*:span[@id="Rahmen3"][last()]]]
    else
        $body/*[preceding-sibling::*:table]
};

declare function dl2tei:skipEmptyPara($seq)
{
    if (empty($seq))
    then ()
    else
        if (normalize-space(head($seq))='')
        then
            dl2tei:skipEmptyPara(subsequence($seq,2))
        else
            $seq
};

declare function dl2tei:hasBodyTable($body) as xs:boolean
{
    if (count($body/*:table)>1)
    then matches($body/*:table[2]/*:tr[1]/*:td[1]/*:p,'Name')
    else false()
};

declare function dl2tei:hasSpanHeader($body) as xs:boolean
{
    if ($body/*:p/*:span[@id="Rahmen1"] and $body/*:p/*:span[@id="Rahmen3"])  (: Adresse und Sidebar rechts :)
    then true()
    else if ($body/*:p/*:span[@id="Rahmen1"] and $body/*:p/*:span[@id="Rahmen4"])  (: Adresse und Sidebar rechts :)
    then true()
    else false()
};

declare function dl2tei:text($ps)
{
    let $lll := util:log-app('TRACE','apps.nabu','procs')
(: 
    let $lll := util:log-app('TRACE','apps.nabu', $ps)
:)
    let $processed := dl2tei:procs($ps)
    let $lll := util:log-app('TRACE','apps.nabu','lists processed')
(: 
    let $lll := util:log-app('TRACE','apps.nabu', $processed)
:)
    for $p in $processed
    return
        typeswitch($p)
            case element(p) return dl2tei:dtp($p)
            case element(table) return dl2tei:dttable($p)
            case element(div)   return
                                    if ($p/@type and $p/@type='footer')
                                    then ()
                                    else dl2tei:text($p/*)
            case element(ul)    return dl2tei:list($p, 'bulleted')
            case element(ol)    return dl2tei:list($p, 'numbered')
            default return $p
};

declare function dl2tei:text2($ps)
{
    for $p in $ps
    return
        typeswitch($p)
            case element(p) return dl2tei:dtp($p)
            case element(table) return dl2tei:dttable($p)
            case element(div)   return dl2tei:text($p/*)
            case element(ul)    return dl2tei:list($p, 'bulleted')
            case element(ol)    return dl2tei:list($p, 'numbered')
            default return $p
};

declare function dl2tei:list($list, $rend)
{
    <list xmlns="http://www.tei-c.org/ns/1.0" type="simple" rend="{$rend}">
        {
            for $li in $list/*:li
            return
                <item>{normalize-space($li)}</item>
        }
    </list>
};

declare function dl2tei:procs($ps)
{
    let $ret0 := dl2tei:diagnosen($ps)
    let $ret1 := dl2tei:medication($ret0)
    let $ret2 := dl2tei:therapien($ret1)
    return 
        $ret2
(: 
    let $aids  := 
            if ($rethx/ok)
            then
            (
              <label xmlns="http://www.tei-c.org/ns/1.0"><hi rend="bold">Hilfsmittel:</hi></label>
            , <item xmlns="http://www.tei-c.org/ns/1.0">
                <list>
                {
                    $rettx/*:value/*:item
                }
                </list>
              </item>
            )
            else
                ()
:)
};
declare function dl2tei:dtp($p)
{
(: 
    let $lll := util:log-app('TRACE','apps.nabu',$p)
    let $lll := util:log-app('TRACE','apps.nabu',normalize-space($p))
    return
:)
    if (normalize-space($p)!='')
    then
        if (count($p/*:span) = 2)
        then
            <div xmlns="http://www.tei-c.org/ns/1.0" type="block">
                <p>
                    {dl2tei:procedure($p/*:span[1])}
                    <seg>{normalize-space($p/*:span[2])}</seg>
                    {
                        for $s in subsequence(subsequence($p/*:span,2),2)
                        return
                            <seg xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($s)}</seg>
                    }
                </p>
            </div>
        else if (($p/*:span/@id and $p/*:span/@id=('Frame1','Frame2')) or matches($p,'(Steuernummer|ÖPNV)'))
            then
                ()
            else
                <p xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</p>
    else ()
};

declare function dl2tei:dttable($table)
{
    let $nr := dl2tei:noOfRows($table)
    let $nc := dl2tei:noOfCols($table)
    return
    <table xmlns="http://www.tei-c.org/ns/1.0" rows="{$nr}" cols="{$nc}">
    {
        if ($table/*:tbody)
        then for $tr in $table//*:tr
            return
                dl2tei:dttd($tr)
        else
            for $tr in $table/*:tr
            return
                dl2tei:dttd($tr)
    }</table>
};
declare function dl2tei:noOfRows($table)
{
    if (count($table/*:tbody)=2)
    then count($table/*:tbody[2]/*:tr) + 1
    else if ($table/*:tbody)
    then count($table/*:tbody[1]/*:tr)
    else count($table/*:tr)
};

declare function dl2tei:noOfCols($table)
{
    if ($table/*:thead)
    then count($table/*:thead/*:tr/*:td)
    else if ($table/*:tbody)
    then count($table/*:tbody[1]/*:tr[1]/*:td)
    else count($table/*:tr[1]/*:td)
};

declare function dl2tei:dttd($tr)
{
    <row xmlns="http://www.tei-c.org/ns/1.0">
    {
        for $td at $i in $tr/*:td
        return
            <cell  xmlns="http://www.tei-c.org/ns/1.0" type="{if ($i=1) then 'label' else 'data'}">
            {
                if (count($td/*)>0)
                then for $p in $td/*
                    return
                        dl2tei:text2($p)
                else <p xmlns="http://www.tei-c.org/ns/1.0"></p>
            }
           </cell>
    }
    </row>
};

declare function dl2tei:dtspan($span)
{
    normalize-space($span)
};

declare function dl2tei:procedure($s as xs:string*)
{
    let $ns := normalize-space($s)
    let $toks := analyze-string($ns, $dl2tei:regexp-procs)
(:
    let $lll := util:log-app('DEBUG','apps.nabu',$toks)
:)
    return
        if ($toks/fn:match)
        then
            if ($toks/fn:match//*:group)
            then 
                <strong>
                    <name xmlns="http://www.tei-c.org/ns/1.0" type="fhir:procedure" nymRef="{concat('#procedure-',$toks/fn:match//fn:group[@nr=2])}">{$ns}</name>
                </strong>
            else
                <strong>
                    <name xmlns="http://www.tei-c.org/ns/1.0" type="MAS" nymRef="{concat('#mas-axis-',$toks/fn:match//fn:group[@nr=3])}">{$ns}</name>
                </strong>
        else <seg xmlns="http://www.tei-c.org/ns/1.0">{$ns}</seg>
};

(:~
 : mergeps
 : merge two paragraphs,  if missing stop or proc label in first para
 : 
 : @para $ps    list of (p|*)
 : 
 : @return modified list
 :)
declare function dl2tei:mergeps(
      $ps as item()*
    ) as item()*
{
    if (count($ps)>0)
    then
        reverse(dl2tei:mergeps2(head($ps),subsequence($ps,2),()))
    else
        ()
};

declare %private function dl2tei:mergeps2(
      $h as item()
    , $t as item()*
    , $acc as item()*
    ) as item()+
{
    if (local-name($h)='p' and local-name(head($t))='p')
    then
        (: merge if missing stop or proc label in $h :)
        let $tuple := dl2tei:merge2p($h,head($t))
        let $nt    := (subsequence($tuple,2),subsequence($t,2))
        let $nacc  := (head($tuple),$acc)
        return
            if (count($nt)>0)
            then
                dl2tei:mergeps2(head($nt),subsequence($nt,2),$nacc)
            else
                $nacc
    else
        if (count($t)>0)
        then
            dl2tei:mergeps2(head($t),subsequence($t,2), ($h, $acc))
        else
            ($h,$acc)
};

declare %private function dl2tei:merge2p(
      $h as item()
    , $t as item()+
    ) as item()+
{
    if (matches($h,'[0-9\.,][ ]*$') or ends-with(head($t),':')) (: do not merge :)
    then
        ($h,$t)
    else if (ends-with($h,':')) (: merge if procedure but next p only :)
    then
        (
          <div xmlns="http://www.tei-c.org/ns/1.0" type="block">
            <p>
                {dl2tei:procedure($h)}
                <seg>{normalize-space(head($t))}</seg>
            </p>
          </div>
        , subsequence($t,2)
        )        
    else 
        (
          <p xmlns="http://www.tei-c.org/ns/1.0">
          { concat($h,' ',head($t))}
          </p>
        , subsequence($t,2)
        )
};

declare function dl2tei:opener($body, $start, $filename as xs:string)
{
    <opener xmlns="http://www.tei-c.org/ns/1.0">
        { dl2tei:address($body) }
        { dl2tei:dateline($body, $start, $filename) }
        { dl2tei:subjects( $body ) }
        { dl2tei:salute($body)}
    </opener>
};

declare %private function dl2tei:salute($body)
{
<salute>
{
    if (dl2tei:hasSpanHeader($body))
    then 
        let $ps := dl2tei:elementsAfterHeader($body)
        return
        for $gr in $ps[dl2tei:hasSalute(.)]
        return
            <p xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($gr)}</p>
    else if (dl2tei:hasBodyTable($body))
    then 
        let $ps := dl2tei:paraBetweenTables($body)
        return
            dl2tei:nonEmptyParas($ps)
    else (: old table header :)
        let $ps := 
                if (count($body/*:table[1]/*:tr)=2)
                then dl2tei:elementsAfterHeader($body)
                else $body/*:table[1]/*:tr[3]/*:td[1]/*:p       (: anomaly :)
        for $gr in $ps[dl2tei:hasSalute(.)]
        return
            <p xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($gr)}</p>
}
</salute>
};

declare function dl2tei:address($body)
{
    if (dl2tei:hasSpanHeader($body))
    then
        <address xmlns="http://www.tei-c.org/ns/1.0">
            <retourline>{ string-join(($body/*:p/*:span[@id="Rahmen2"]/string()),", ") }</retourline>
            {
                for $l in $body/*:p/*:span[@id="Rahmen1"][normalize-space(.)!=""]
                return
                    <addrLine xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($l)}</addrLine>
            }
        </address>
    else
    let $td := $body/*:table[1]/*:tr[1]/*:td[1]
    let $adr := if($td/*:h3)
        then let $lines :=  
                for $p in $td/*:p[normalize-space(.)!=""]
                return
                    <addrLine xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</addrLine>
            return
                <address xmlns="http://www.tei-c.org/ns/1.0">
                    <retourline>{ $td/*:h3/string() }</retourline>
                    { $lines }
                </address>
        else
            <address xmlns="http://www.tei-c.org/ns/1.0">
            {
                for $p in $td//*:p[normalize-space(.)!=""]
                return
                if (matches($p,'SPZ'))
                then
                    <retourline>{normalize-space($p)}</retourline>
                else
                    <addrLine xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</addrLine>
            }
            </address>
    return
        $adr
};

(:  from functx :)
declare function dl2tei:pad-integer-to-length
  ( $integerToPad as xs:anyAtomicType? ,
    $length as xs:integer )  as xs:string {

   if ($length < string-length(string($integerToPad)))
   then error(xs:QName('functx:Integer_Longer_Than_Length'))
   else concat
         (dl2tei:repeat-string(
            '0',$length - string-length(string($integerToPad))),
          string($integerToPad))
};
declare function dl2tei:repeat-string
  ( $stringToRepeat as xs:string? ,
    $count as xs:integer )  as xs:string {

   string-join((for $i in 1 to $count return $stringToRepeat),
                        '')
};
declare function dl2tei:date
  ( $year as xs:anyAtomicType ,
    $month as xs:anyAtomicType ,
    $day as xs:anyAtomicType )  as xs:date
{
    try {
        xs:date(
            concat(
                dl2tei:pad-integer-to-length(xs:integer($year),4),'-',
                dl2tei:pad-integer-to-length(xs:integer($month),2),'-',
                dl2tei:pad-integer-to-length(xs:integer($day),2)))
    } catch * {
        if (xs:integer($day)=29 and xs:integer($month)=2)
        then 
            xs:date(
                concat(
                      dl2tei:pad-integer-to-length(xs:integer($year),4)
                    , '-02-28'
                    )
                )
        else 
            xs:date('1900-01-01')
    }
};

declare function dl2tei:normalize-month($m)
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

declare function dl2tei:dateline($body, $ps, $filename)
{
    let $ds := if (dl2tei:hasSpanHeader($body)) (: Briefe ab 2020 :)
        then 
            $body/*:p/*:span[@id=("Rahmen3","Rahmen4")][last()]
        else
            let $d := $body/*:table[1]/*:tr[2]/*:td[2]/*:p[matches(.,"Köln, den")]
            return
                if ($d)
                then $d
                else $ps/*:span[matches(.,"Köln, den")]/..
    let $lll := util:log-app('DEBUG','apps.nabu',string-join(($filename, $ds),'_'))
    return
        dl2tei:formatDateLine($ds, $filename)
};

declare function dl2tei:formatDateLine($ds, $filename)
{
if ($ds)
then
    let $toks := analyze-string($ds[1], $dl2tei:regexp-dateline)

    let $day := $toks/fn:match/fn:group[@nr=1]/string()
    let $mon0 := ($toks/fn:match//fn:group[@nr=3]/string(), $toks/fn:match//fn:group[@nr=4]/string())[1]

    let $mon := if (string(number($mon0)) != 'NaN')
        then $mon0
        else dl2tei:normalize-month($mon0)
    let $year:= $toks/fn:match/fn:group[@nr=5]/string()
    let $year := ($year)[1]
    let $isoyear := if (string-length($year) = 2)
            then if (xs:integer($year) > 50)
                then concat('19',$year)
                else concat('20',$year)
            else $year
    let $gdate:= string-join(($day,$mon,$year),'.')
    let $sa  := $toks/fn:match/fn:group[@nr=6]/string()
    return
        try {
            let $iso := dl2tei:date($isoyear,$mon,$day)
            return
                <dateline xmlns="http://www.tei-c.org/ns/1.0">Köln, den <date when="{$iso}">{$gdate}</date>, {$sa}</dateline>
        } catch * {
            let $lll := util:log-app('DEBUG','apps.nabu',string-join(($filename, $err:code , $err:description, $err:value),'_'))
            return
                <dateline xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($ds[1])}</dateline>
        }
else
    <dateline xmlns="http://www.tei-c.org/ns/1.0"></dateline>
};

declare function dl2tei:nonEmptyParas( $ps )
{
    for $p in $ps[normalize-space(./string())!='']
    return
        <p xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</p>
};

declare function dl2tei:block( $p, $ps)
{
    if (normalize-space($p)='') (: skip empty para :)
    then
        dl2tei:block(head($ps), subsequence($ps,2))
    else if (local-name($p)='p')
    then
        let $res := <p xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</p>
        return
            if (count($ps)>0) (: eol? :)
            then
                let $retb2 := dl2tei:block2(head($ps), subsequence($ps,2), $res)
                return
                if ($retb2/ok)
                then
                    <ret>
                        <ok/>
                        <value>{reverse($retb2/*:value/*)}</value>
                        <cont>{$retb2/*:cont/*}</cont>
                    </ret>
                else
                    <ret>
                        <error>error in block2?</error>
                        <cont>{$ps}</cont>
                    </ret>
            else
                <ret>
                    <ok/>
                    <value>{$res}</value>
                    <cont>{$ps}</cont>
                </ret>
    else
        <ret>
            <error>no para</error>
            <cont>{($p,$ps)}</cont>
        </ret>
};

declare function dl2tei:block2( $p, $ps, $list)
{
    if (normalize-space($p)='' or local-name($p)!='p') (: exit when empty para :)
    then
        <ret>
            <ok/>
            <value>{$list}</value>
            <cont>{$ps}</cont>
        </ret>
    else
        let $res := (<p xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</p>,$list)
        return    
            if (count($ps)>0) (: eol? :)
            then
                dl2tei:block2(head($ps), subsequence($ps,2), $res)
            else
                <ret>
                    <ok/>
                    <value>{$res}</value>
                    <cont/>
                </ret>
};

declare function dl2tei:subjects( $body )
{
    if (dl2tei:hasSpanHeader($body))
    then dl2tei:subjectFromDINHeader($body)
    else if (dl2tei:hasBodyTable($body))
    then dl2tei:subjectFromHeaderTable($body)
    else dl2tei:subjectFromDINHeader($body)
};

declare function dl2tei:recapitalize($s as xs:string) as xs:string
{
    let $btoks := tokenize($s,'-')
    let $bs := for $bt in $btoks
        let $lw := lower-case($bt)
        let $ltoks := tokenize($lw,' ')
        let $utoks := for $lt in $ltoks
            let $first := substring($lt,1,1)
            let $rest := substring($lt,2)
            return
            concat(upper-case($first),$rest)
        return
            string-join($utoks,' ')
    return string-join($bs,'-')
};

declare function dl2tei:para-transform($x)
{
   typeswitch($x)
   case element(a) return ()
   case element(span) return
        if (($x/@id and $x/@id=('Frame1','Frame2')) or matches($x,'(Steuernummer|ÖPNV)'))
        then ()
        else $x/fn:string()
   case element() return
     for $y in $x/node()
     return dl2tei:para-transform($y)
   default return fn:string($x)
};

declare function dl2tei:para2subjects($ps as item()*) as item()*
{

let $lll := util:log-app('DEBUG','apps.nabu',$ps)

    for $p0 in $ps
        let $p := fn:replace(fn:string-join(dl2tei:para-transform($p0), " "), "\s+", " ")

        let $lll := util:log-app('DEBUG','apps.nabu',$p)
        let $toks := analyze-string($p[1], $dl2tei:regexp-family-given-birth3)
(:
        let $lll := util:log-app('DEBUG','apps.nabu',$toks)
:)
        return
            if (count($toks/fn:match)=1) (:  family, given, birthdate :)
            then 
                <subject xmlns="http://www.tei-c.org/ns/1.0">
                    <persName>
                        <surname>{ dl2tei:recapitalize($toks/fn:match//fn:group[@nr=2]) }</surname>
                        <forename>{ dl2tei:recapitalize(tokenize($toks/fn:match//fn:group[@nr=4],' ')[1]) }</forename>
                        <birth when="{dl2tei:date($toks/fn:match//fn:group[@nr=10],$toks/fn:match//fn:group[@nr=9],$toks/fn:match//fn:group[@nr=8])}">{$toks/fn:match//fn:group[@nr=7]/string()}</birth>
                    </persName>
                </subject>
            else
                let $toks := analyze-string($p[1], $dl2tei:regexp-family-given-birth2) (: relax comma :)
(: 
        let $lll := util:log-app('DEBUG','apps.nabu',$toks)
:)
                return
                    if (count($toks/fn:match)=1) (:  family given, birthdate :)
                    then 
                    <subject xmlns="http://www.tei-c.org/ns/1.0">
                        <persName>
                            <surname>{ dl2tei:recapitalize($toks/fn:match//fn:group[@nr=2]) }</surname>
                            <forename>{ dl2tei:recapitalize($toks/fn:match//fn:group[@nr=4]) }</forename>
                            <birth when="{dl2tei:date($toks/fn:match//fn:group[@nr=10],$toks/fn:match//fn:group[@nr=9],$toks/fn:match//fn:group[@nr=8])}">{$toks/fn:match//fn:group[@nr=7]/string()}</birth>
                        </persName>
                    </subject>
            else
                ()
                (:
                <subject xmlns="http://www.tei-c.org/ns/1.0">{replace($p,"( geboren | geb\. | \*| \*am )",', *')}</subject>
                :)
};

declare function dl2tei:para2subjects-relaxed($ps as item()*) as item()*
{
    for $p0 in $ps
            
            let $lll := util:log-app('DEBUG','apps.nabu',$p0)
     
            let $p := (: leads to node conversion error, if naked name
                if ($p0/*:span[not(preceding-sibling::node())]) (: match only span at begin :)
                then let $spans := for $span in $p0/*[not(self::a)]
                                return
                                    normalize-space($span/string())
                      let $bd := $p0/text()[not(following-sibling::node())]
                    return string-join(($spans,$bd),' ')
                else :) 
                    normalize-space($p0/string())

            let $lll := util:log-app('DEBUG','apps.nabu',$p)

            let $toks0 := analyze-string($p[1], $dl2tei:regexp-family-given-birth2)
            let $toks := if (count($toks0/fn:match) = 0)
                then analyze-string($p[1], $dl2tei:regexp-family-given-birth3)
                else $toks0
 
            let $lll := util:log-app('DEBUG','apps.nabu',$toks)

            return
                if (count($toks/fn:match)>0) (:  family, given, birthdate :)
                then
                    let $match := $toks/fn:match[1]
                    let $year    := $match//fn:group[@nr=10]
                    let $isoyear := if (string-length($year) = 2)
                        then if (xs:integer($year) > 50)
                            then concat('19',$year)
                            else concat('20',$year)
                        else $year
                    return
                    <subject xmlns="http://www.tei-c.org/ns/1.0">
                        <persName>
                            { if (contains($match//fn:group[@nr=3],','))
                                then
                                    (
                                        <surname>{ dl2tei:recapitalize($match//fn:group[@nr=2]) }</surname>
                                    ,   <forename>{ dl2tei:recapitalize(tokenize($match//fn:group[@nr=4],' ')[1]) }</forename>
                                    )
                                else
                                    (
                                        <surname>{ dl2tei:recapitalize($match//fn:group[@nr=4]) }</surname>
                                    ,   <forename>{ dl2tei:recapitalize(tokenize($match//fn:group[@nr=2],' ')[1]) }</forename>
                                    )
                                }
                                <birth when="{dl2tei:date($isoyear,$match//fn:group[@nr=9],$match//fn:group[@nr=8])}">{$match//fn:group[@nr=7]/string()}</birth>
                        </persName>
                    </subject>
                else 
                    <subject xmlns="http://www.tei-c.org/ns/1.0">{replace($p,"( geboren | geb\. | \*| \*am )",' *')}</subject>
};

declare function dl2tei:subjectFromDINHeader($body )
{
(: 
    let $lll := util:log-app('DEBUG','apps.nabu',$body)
:)
    let $ps := dl2tei:elementsAfterHeader($body)
(: 
    let $lll := util:log-app('DEBUG','apps.nabu',$ps)
:)
(: 
    let $ps := if (count($body/*:table[1]/*:tr)=2)
        then dl2tei:paraAfterFirstTable($body)
        else $body/*:table[1]/*:tr[3]/*:td[1]/*:p
:)
(: 
let $lll := util:log-app('DEBUG','apps.nabu',$ps[following-sibling::*:p[contains(.,'geehrt')]][normalize-space(.)!=''])
:)
    let $subjects := dl2tei:para2subjects($ps[following-sibling::*:p[contains(.,'geehrt')]][normalize-space(.)!=''])

    let $lll := util:log-app('DEBUG','apps.nabu',$subjects)

    return
        if (count($subjects)>0)
        then $subjects
        else (: no subject before greeting, try all para :)
            let $possibleps := $ps[matches(.,"(geboren |geb\.|, \*|, \*am |Bescheinigung|Attest)")]
            let $lll := util:log-app('DEBUG','apps.nabu',$possibleps)
            return
                if (count($possibleps)>0) then dl2tei:para2subjects-relaxed($possibleps)
                else ()
};

declare function dl2tei:subjectFromHeaderTable( $body )
{
    let $table := $body/*:table[2]
    let $trnam := $table/*:tr[*:td/*:p[matches(.,'Name')]]
    let $trgeb := $table/*:tr[*:td/*:p[matches(.,'^(geboren|geb\.)')]]
    let $ns :=
            if (count($trnam/*:td[1]/*:p[1]/*:span)=1) (: Name in td[2]/p/span :)
            then normalize-space(string-join($trnam/*:td[2]/*:p/*:span,' '))
            else if (count($trnam/*:td[1]/*:p[1]/*:span)=2) (: Name in 2nd span :)
            then normalize-space($trnam/*:td[1]/*:p/*:span[2])
            else normalize-space($trnam/*:td[2]/*:p) (: Name in td[2]/p :)
    let $gbs :=
            if (count($trgeb/*:td[1]/*:p[1]/*:span)=1) (: regular case :)
            then normalize-space($trgeb/*:td[2]/*:p/*:span)
            else if (count($trgeb/*:td[1]/*:p[1]/*:span)=2) 
            then normalize-space($trgeb/*:td[1]/*:p[1]/*:span[2])
            else normalize-space($trgeb/*:td[2]/*:p)
    let $tokns  := analyze-string($ns, $dl2tei:regexp-name)
(: 
let $lll := util:log-app('DEBUG','apps.nabu',$trnam)
:)
    let $tokgbs := analyze-string($gbs, $dl2tei:regexp-birth)
    let $match := $tokgbs/fn:match[1]
    let $year    := $match//fn:group[@nr=4]
    let $isoyear := if (string-length($year) = 2)
        then if (xs:integer($year) > 50)
        then concat('19',$year)
        else concat('20',$year)
    else $year
    return
        <subject xmlns="http://www.tei-c.org/ns/1.0">
            <persName>
                <surname>{($tokns/fn:match/fn:group[@nr=1]/string(),$tokns/fn:match/fn:group[@nr=4]/string())}</surname>
                <forename>{($tokns/fn:match/fn:group[@nr=2]/string(),$tokns/fn:match/fn:group[@nr=3]/string())}</forename>
                <birth when="{string-join(($isoyear,$tokgbs/fn:match//fn:group[@nr=3],$tokgbs/fn:match//fn:group[@nr=2]),'-')}">{$tokgbs/fn:match/fn:group[@nr=1]/string()}</birth>
            </persName>
        </subject>
};

declare function dl2tei:diagnosen($ps)
{
let $lll := util:log-app('DEBUG','apps.nabu','diagnosen')
    let $pspan := $ps[*:span[matches(normalize-space(.),'^Diagnose[n ]?:?')]]
    let $pspanspan := $ps[*:span/*:span[matches(normalize-space(.),'^Diagnose[n ]?:?')]]
    let $pdia := ($pspan, $pspanspan)[1]

let $lll := util:log-app('DEBUG','apps.nabu',$pdia)

    return
        if (exists($pdia))
        then
            let $pscnt := count($ps)
            let $pidx := index-of($ps,$pdia)
            let $prec := subsequence($ps,1,$pidx - 1)
            let $fol  := subsequence($ps,$pidx + 1, $pscnt - $pidx)
(:  
let $lll := util:log-app('DEBUG','apps.nabu',$fol)
:)
            let $dx  := dl2tei:diagnosen2($pdia,$fol)
(: 
 :             let $lll := util:log-app('DEBUG','apps.nabu',$dx)
 :)
            let $diagnosen :=
                if ($dx/ok)
                then
                <list xmlns="http://www.tei-c.org/ns/1.0" type="dxlist" rend="gloss">
                    <label><hi rend="bold">Diagnosen:</hi></label>
                        { $dx/*:value/*:item[normalize-space(.)!=''] }
                </list>
                else
                    ()
            return 
                ($prec,$diagnosen,$dx/*:cont/*)
        else
            $ps
};

(:~
 :  <p><span>Diagnosen:</span><span>texttext</span></p>
 :  <p><span><span>Diagnosen:</span><span>texttext</span></span></p>
 : 
 : 
 :)
declare function dl2tei:diagnosen2($head,$tail)
{
    let $diagn := 
            <item xmlns="http://www.tei-c.org/ns/1.0">
            {
                let $dtext := if ($head/*:span[2])
                        then
                            $head/*:span[2]
                        else if ($head/*:span/*:span[2])
                        then
                            $head/*:span/*:span[2]
                        else
                            substring-after($head/*:span,'Diagnosen: ')
                return
                    dl2tei:icdcodes(normalize-space($dtext))
            }
            </item>
    return
            let $ret := dl2tei:dxitem(head($tail),subsequence($tail,2),$diagn)
            return
                if ($ret/ok)
                then
                    <ret>
                        <ok/>
                        <value>{reverse($ret/*:value/*:item)}</value>
                        <cont>{$ret/*:cont/*}</cont>
                    </ret>
                else
                    <ret>
                        <error>error in dxitem?</error>
                        <cont>{$tail}</cont>
                    </ret>
};

declare function dl2tei:dxitem($head,$tail,$list)
{
(: 
    let $lll := util:log-app('TRACE','apps.nabu',$head)
    let $lll := util:log-app('TRACE','apps.nabu',count($tail))
    return
:)
    if (normalize-space($head)="")
    then 
        let $lll := util:log-app('TRACE','apps.nabu',$head)
        return
        <ret>
            <ok/>
            <value>{$list}</value>
            <cont>{$tail}</cont>
        </ret>
    else 
        let $d   := dl2tei:icdcodes($head)
        let $ret := (<item xmlns="http://www.tei-c.org/ns/1.0">{$d}</item>,$list)
        return
        if (count($tail) > 0)
        then
            dl2tei:dxitem(head($tail),subsequence($tail,2), $ret)
        else
            <ret>
                <ok/>
                <value>{$ret}</value>
                <cont></cont>
            </ret>
        
};

declare variable $dl2tei:regexp-icdcode :=
    "\(([A-TV-Z]\d[0-9AB](?:\.([\dA-KXZ][\dAX-Z][\dX][0-59A-HJKMNP-S]|[\dA-KXZ][\dAX-Z][\dX]|[\dA-KXZ][\dAX-Z]|[\dA-KXZ]))?\))";

declare function dl2tei:icdcodes($s as xs:string)
{
    let $nd := normalize-space($s)
    let $toks := analyze-string(replace($s,' ',''),$dl2tei:regexp-icdcode)
    return
        if ($toks/fn:match)
        then
        let $icds   := for $icd in $toks/fn:match
            return replace(concat('#icd10-',$icd/*:group),'[\(\) ]','')
        return
            <name type="diagnosis" xmlns="http://www.tei-c.org/ns/1.0" nymRef="{string-join($icds,' ')}">{$nd}</name>
    else    <name type="diagnosis" xmlns="http://www.tei-c.org/ns/1.0" nymRef="">{$nd}</name>
};

declare function dl2tei:therapien($ps)
{
    let $pspan := $ps[*:span[matches(normalize-space(.),'^Therapie[n ]?:?')]]
    let $pspanspan := $ps[*:span/*:span[matches(normalize-space(.),'^Therapie[n ]?:?')]]
    let $pdia := ($pspan, $pspanspan)[1]
    return
        if (exists($pdia))
        then
            let $pscnt := count($ps)
            let $pidx := index-of($ps,$pdia)
            let $prec := subsequence($ps,1,$pidx - 1)
            let $fol  := subsequence($ps,$pidx + 1, $pscnt - $pidx)
            let $dx  := dl2tei:therapien2($pdia,$fol)
(:  
            let $lll := util:log-app('DEBUG','apps.nabu',$dx)
:)
            let $diagnosen :=
                if ($dx/ok)
                then
                <list xmlns="http://www.tei-c.org/ns/1.0" type="txlist" rend="gloss">
                    <label><hi rend="bold">Therapien:</hi></label>
                        { $dx/*:value/*:item }
                </list>
                else
                    ()
            return 
                ($prec,$diagnosen,$dx/*:cont/*)
        else
            $ps
};

declare function dl2tei:therapien2($head,$tail)
{
    let $tx := 
            <item xmlns="http://www.tei-c.org/ns/1.0">
            {
                let $dtext := if ($head/*:span[2])
                        then
                            $head/*:span[2]
                        else if ($head/*:span/*:span[2])
                        then
                            $head/*:span/*:span[2]
                        else
                            substring-after($head/*:span,'Therapien: ')
                return
                    dl2tei:icdcodes(normalize-space($dtext))
            }
            </item>
    let $ret := dl2tei:txitem(head($tail),subsequence($tail,2),$tx)
    return
                if ($ret/ok)
                then
                    <ret>
                        <ok/>
                        <value>{reverse($ret/*:value/*:item)}</value>
                        <cont>{$ret/*:cont/*}</cont>
                    </ret>
                else
                    <ret>
                        <error>error in txitem?</error>
                        <cont>{$tail}</cont>
                    </ret>
};


declare function dl2tei:txitem($head,$tail,$list)
{
    if (normalize-space($head)="" or local-name($head)!='p')
    then
        <ret>
            <ok/>
            <value>{$list}</value>
            <cont>{$tail}</cont>
        </ret>
    else 
        let $ret := 
            (
              <item xmlns="http://www.tei-c.org/ns/1.0">
                <name type="fhir:procedure" nymRef="">{normalize-space($head)}</name>
              </item>
            , $list)
        return
        if (count($tail) > 0)
        then
            dl2tei:txitem(head($tail),subsequence($tail,2), $ret)
        else
            <ret>
                <ok/>
                <value>{$ret}</value>
                <cont></cont>
            </ret>
};

declare function dl2tei:medication($ps)
{
    let $pspan := $ps[*:span[matches(normalize-space(.),'^(Medikation|Medikament[e]?):')]]
    let $pspanspan := $ps[*:span/*:span[matches(normalize-space(.),'^(Medikation|Medikament[e]?):')]]
    let $pdia := ($pspan, $pspanspan)[1]
    return
        if (exists($pdia))
        then
            let $pscnt := count($ps)
            let $pidx := index-of($ps,$pdia)
            let $prec := subsequence($ps,1,$pidx - 1)
            let $fol  := subsequence($ps,$pidx + 1, $pscnt - $pidx)
            let $dx  := dl2tei:medication2($pdia,$fol)
(: 
            let $lll := util:log-app('DEBUG','apps.nabu',$dx)
:)
            let $diagnosen :=
                if ($dx/ok)
                then
                <list xmlns="http://www.tei-c.org/ns/1.0" type="mdlist" rend="gloss">
                    <label><hi rend="bold">Medikation:</hi></label>
                        { $dx/*:value/*:item }
                </list>
                else
                    ()
            return 
                ($prec,$diagnosen,$dx/*:cont/*)
        else
            $ps
};

declare function dl2tei:medication2($head,$tail)
{
    let $medic := 
            <item xmlns="http://www.tei-c.org/ns/1.0">
            {
                let $dtext := if ($head/*:span[2])
                        then
                            $head/*:span[2]
                        else if ($head/*:span/*:span[2])
                        then
                            $head/*:span/*:span[2]
                        else
                            substring-after($head/*:span,'Medikation: ')
                return
                    dl2tei:icdcodes(normalize-space($dtext))
            }
            </item>
    let $ret := dl2tei:mditem(head($tail),subsequence($tail,2),$medic)
    return
            if ($ret/ok)
            then
                <ret>
                    <ok/>
                    <value>{reverse($ret/*:value/*:item)}</value>
                    <cont>{$ret/*:cont/*}</cont>
                </ret>
            else
                <ret>
                    <error>error in mditem?</error>
                    <cont>{$tail}</cont>
                </ret>
};


declare function dl2tei:mditem($head,$tail,$list)
{
    if (normalize-space($head)="" or local-name($head)!='p')
    then 
        <ret>
            <ok/>
            <value>{$list}</value>
            <cont>{$tail}</cont>
        </ret>
    else 
        let $ret :=
            (
              <item xmlns="http://www.tei-c.org/ns/1.0">
                <name type="fhir:substance" subtype="fhir:drug" nymRef="">{normalize-space($head)}</name>
              </item>
            , $list)
        return
        if (count($tail) > 0)
        then
            dl2tei:mditem(head($tail),subsequence($tail,2), $ret)
        else
            <ret>
                <ok/>
                <value>{$ret}</value>
                <cont></cont>
            </ret>
};

declare function dl2tei:aids($head,$tail)
{
    if (starts-with($head,'Hilfsmittel'))
    then 
        let $diagn := 
            <item xmlns="http://www.tei-c.org/ns/1.0">
                <name type="fhir:medicalaid" nymRef="">{tokenize($head,':')[2]}</name>
            </item>
        return
            let $ret := dl2tei:hxitem(head($tail),subsequence($tail,2),$diagn)
            return
                if ($ret/ok)
                then
                    <ret>
                        <ok/>
                        <value>{reverse($ret/*:value/*:item)}</value>
                        <cont>{$ret/*:cont/*}</cont>
                    </ret>
                else
                    <ret>
                        <error>error in hxitem?</error>
                        <cont>{$tail}</cont>
                    </ret>
    else 
        if (count($tail) > 0)
        then
            dl2tei:aids(head($tail),subsequence($tail,2))
        else
            <ret>
                <error>Hilfsmittel nicht gefunden</error>
                <cont>{$head,$tail}</cont>
            </ret>
};


declare function dl2tei:hxitem($head,$tail,$list)
{
    if ($head/string()="")
    then
        <ret>
            <ok/>
            <value>{$list}</value>
            <cont>{$tail}</cont>
        </ret>
    else 
        let $ret := 
            (
              <item xmlns="http://www.tei-c.org/ns/1.0">
                <name type="fhir:medicalaid" nymRef="">{$head/string()}</name>
              </item>
            , $list)
        return
        if (count($tail) > 0)
        then
            dl2tei:hxitem(head($tail),subsequence($tail,2), $ret)
        else
            <ret>
                <ok/>
                <value>{$ret}</value>
                <cont></cont>
            </ret>
};

declare function dl2tei:hasSalute($p)
{
    matches($p,'geehrt')
};

declare function dl2tei:hasGreeting($p)
{
    matches($p,'[mM]it freundlichen')
};

declare function dl2tei:closerForward($head,$tail)
{
    if (dl2tei:hasGreeting($head) or dl2tei:nameAlike($head))
    then 
        if (dl2tei:hasGreeting($head))
        then
            dl2tei:closer2($tail, <salute xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($head)}</salute>)
        else 
            dl2tei:closer2(($head,$tail), <salute xmlns="http://www.tei-c.org/ns/1.0"></salute>)
    else
        if (count($tail) > 0)
        then
            dl2tei:closerForward(head($tail),subsequence($tail,2))
        else
            <ret>
                <error>Unterschriften nicht gefunden</error>
                <cont>{$head,$tail}</cont>
            </ret>
};

declare function dl2tei:closer2($seq, $salute)
{
    let $skip := dl2tei:skipEmptyPara($seq)
    let $ret := dl2tei:signed(head($skip),subsequence($skip,2),())
    return
        if ($ret/ok)
        then
            <ret>
                <ok/>
                <value>
                    <closer xmlns="http://www.tei-c.org/ns/1.0">
                        { $salute }
                        {reverse($ret/*:value/*:signed)}
                    </closer>
                </value>
                <cont>{$ret/*:cont/*:p}</cont>
            </ret>
        else
            <ret>
                <error>error in signed?</error>
                <cont>{$skip}</cont>
            </ret>
};

declare function dl2tei:nameAlike($n)
{
    (: use analyze-string signees :)
       starts-with($n,'Dr.') 
    or starts-with($n,'PD')
    or (matches($n,'(Spee|Haeck|Zippel|Flemming|Düchting|Freiha)') and string-length(normalize-space($n/*:span[1])) < 20)
};

declare function dl2tei:signed($head,$tail,$list)
{
    if (count($tail)=0 or matches(normalize-space($head),"(D/|d/|Nachrichtlich|Anlage|Kerpener)"))
    then 
        <ret>
            <ok/>
            <value>{$list}</value>
            <cont>{($head,$tail)}</cont>
        </ret>
    else 
        let $retsig := dl2tei:signees($head,$tail)
  let $lll := util:log-app('DEBUG','apps.nabu',$retsig) 
        let $tail := dl2tei:skipEmptyPara($retsig/*:cont/*)
        return
        if (count($tail) > 0)
        then
            dl2tei:signed(head($tail),subsequence($tail,2), $retsig/*:value/*)
        else
            <ret>
                <ok/>
                <value>{$retsig/*:value/*}</value>
                <cont></cont>
            </ret>
};

declare function dl2tei:signees($head,$tail)
{
    let $toks := analyze-string(
             replace(normalize-space($head),'[()]','')
            , $dl2tei:regexp-signees)
    let $retbl := dl2tei:block($head,$tail)

let $lll := util:log-app('DEBUG','apps.nabu',$toks)

    let $roles := dl2tei:roles($retbl/*:value/*, $toks/fn:match)
    let $signees := for $m at $nm in $toks/fn:match
        return
            <signed xmlns="http://www.tei-c.org/ns/1.0">
                <l>
                    <name type="fhir:person" subtype="fhir:practitioner" nymRef="">
                       {normalize-space($m)}
                    </name>
                </l>
                { for $p in $roles[$nm]
                    return
                        <l xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($p)}</l>
                }
            </signed>
    return
        <ret>
            <ok/>
            <value>{reverse($signees)}</value>
            <cont>{$retbl/*:cont/*}</cont>
        </ret>
};

declare function dl2tei:roles($ps,$signees)
{
    let $ns := count($signees)
    let $rs := subsequence($ps,2)
    return
        if (count($rs) > 0)
        then
            if ($ns < 2)  (: parsing not needed :)
            then
                <role>{
                    for $r in $rs
                    return
                        <span>{normalize-space($r)}</span>
                }</role>
            else
                let $nrs := normalize-space(string-join($rs,' '))
                let $toks := analyze-string($nrs, $dl2tei:regexp-roles)
                return
                    if (count($toks/fn:match)=$ns)
                    then
                        for $m in $toks/fn:match
                        return
                            <role>{normalize-space($m)}</role>
                    else
(: 
    let $lll := util:log-app('DEBUG','apps.nabu',$nrs)               
    let $lll := util:log-app('DEBUG','apps.nabu',$toks)
                        return
:)
                        if ($signees[.,'[Bartz|Fricke'])
                        then
                            for $m in subsequence($toks/fn:match,1,$ns)
                            return
                                <role>{normalize-space($m)}</role>
                        else
                            error(xs:QName("ParseError"), "analyze roles -> complex case")
        else
            ()
};