xquery version "3.1";

module namespace helper="http://enahar.org/exist/apps/nabudocs/helper";

import module namespace dl2tei         = "http://enahar.org/exist/apps/nabudocs/dl2tei" at "../modules/dl2tei.xqm";
import module namespace composition    = "http://enahar.org/exist/apps/nabu/composition" at "/db/apps/nabu/FHIR/Composition/composition.xqm";
import module namespace condition      = "http://enahar.org/exist/apps/nabu/condition"   at "/db/apps/nabu/FHIR/Condition/condition.xqm";

import module namespace r-patient      = "http://enahar.org/exist/restxq/nabu/patients"       at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners" at "/db/apps/metis/FHIR/Practitioner/practitioner-routes.xqm";
import module namespace r-practrole    = "http://enahar.org/exist/restxq/metis/practrole"    at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

import module namespace r-condition    = "http://enahar.org/exist/restxq/nabu/conditions"     at "/db/apps/nabu/FHIR/Condition/condition-routes.xqm";
import module namespace r-composition  = "http://enahar.org/exist/restxq/nabu/compositions"   at "/db/apps/nabu/FHIR/Composition/composition-routes.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace fhir= "http://hl7.org/fhir";

declare function helper:composition($letter, $coll, $file, $subject, $group, $author, $recipient)
{
    helper:compositionWithDateline($letter, $coll, $file, $subject, $group, $author, $recipient, ())
};

declare function helper:compositionWithDateline($letter, $coll, $file, $subject, $group, $author, $recipient, $dateline)
{
    let $source:= concat($coll,'/',$file)
    let $lt := helper:canonizeTEISubject($letter, $subject)
(: 
    let $lll := util:log-app('TRACE','apps.nabu',$lt)
:)
    let $cp := composition:fillTemplate($lt, $subject, $group, $author, $recipient, $dateline, $source)
(:  
    let $lll := util:log-app('TRACE','apps.nabu',$cp)
:)
    let $store :=
        r-composition:putCompositionXML(document {$cp},"kikl-spz", "u-admin", "import-bot")
    return
        1
};

declare function helper:canonizeTEISubject($letter, $subject)
{
    let $pid := substring-after($subject/fhir:reference/@value,'nabu/patients/')
(:     
    let $lll := util:log-app('TRACE','apps.nabu',$pid)
:)
    let $p := r-patient:patientByIDXML($pid,"kikl-spz","u-admin","admin")
    let $header := $letter/tei:div/tei:div[@class='header']
    let $body := $letter/tei:div/tei:*[not(self::tei:opener)]
    let $obase := $letter/tei:div/tei:opener/tei:*[not(self::tei:subject)]
    let $tei-subject := 
        <subject xmlns="http://www.tei-c.org/ns/1.0">
            <persName>
                <surname>{$p/fhir:name/fhir:family/@value/string()}</surname>
                <forename>{$p/fhir:name/fhir:given/@value/string()}</forename>
                <birth when="{$p/fhir:birthDate/@value}">{helper:iso2date($p/fhir:birthDate/@value)}</birth>
            </persName>            
        </subject>
    let $opener := 
        <opener  xmlns="http://www.tei-c.org/ns/1.0">
            {$obase}
            {$tei-subject}
        </opener>
    (:
    let $lll := util:log-system-out($body)
    :)
    return
        <body xmlns="http://www.tei-c.org/ns/1.0">
            <div class="letter">
                {$header}
                {$opener}
                { for $d in $body
                  return
                    if ($d/@class and $d/@class='header')
                    then ()
                    else $d
                }
            </div>
        </body>
};

declare function helper:iso2date($iso)
{
    let $toks := tokenize($iso, '-')
    return
        string-join(($toks[3],$toks[2],$toks[1]),'.')
};

declare function helper:conditions($lt as item(),
      $coll as xs:string
    , $file as xs:string
    , $subject, $ass
    ) as xs:string*
{
    (: diagnosis :)
    let $old := r-condition:conditionsXML(
             'kikl-spz','u-admin', 'import-bot'
            , '1', '*'
            , '', ''
            , substring-after($subject/fhir:reference/@value,'nabu/patients/')
            , ''
            , 'active'
            , ''
            , ''
            , 'full'
            , 'cat'
            )
(: 
let $lll := util:log-app('TRACE','apps.nabu',$old)
:)
    let $dxs  := $lt//tei:list[@type='dxlist']//tei:name
    let $cnds := for $dx in $dxs
        let $icd    := substring-after($dx/@nymRef, '#icd10-')
        let $dxtext := $dx/string()


let $lll := util:log-app('TRACE','apps.nabu',$icd)
let $lll := util:log-app('TRACE','apps.nabu',$dxtext)

        return
            if (helper:isNewCondition($old,$icd,$dxtext))
            then
                let $date   := $lt//tei:opener/tei:dateline/tei:date/@when/string()
                let $source   := concat($coll, '/', $file)
                let $note := ""
                let $condition :=
                    condition:fillTemplate(
                             "active","Aktiv"
                            , "unknown", "unbekannt"
                            ,"diagnosis","unknown"
                           , $icd,"",$dxtext
                           , $subject
                           , $date, $date
                           , $ass
                           , $ass
                           , "http://eNahar.org/nabu/system#nabu-report-source",$source,$source
                           ,$note)
                (:
          $csc as xs:string
        , $csd as xs:string
        , $vsc as xs:string
        , $vsd as xs:string 
        , $category as xs:string
        , $severity as xs:string
                let $lll := util:log-app('TRACE','apps.nabu',$condition)
                :)
                let $store :=
                    r-condition:putConditionXML(document {$condition}, "kikl-spz", "u-admin", "import-bot")
                return 
                    'n'
            else
                'o'
    return
        $cnds
};

declare function helper:isNewCondition($old, $icd as xs:string?, $dxtext as xs:string) as xs:boolean
{
    if ($icd and string-length($icd)>0)
    then count($old[starts-with(fhir:Condition/fhir:code//fhir:code/@value,$icd)]) = 0
    else string-length($dxtext)>0 and count($old/fhir:Condition[fhir:code/fhir:text/@value = $dxtext]) = 0
};

declare function helper:name2display($name as element(fhir:name)) as xs:string
{
    concat( string-join($name/fhir:family/@value,' ')
          , ', '
          , $name/fhir:given/@value)
};

declare function helper:users( 
      $family as xs:string
    ) as item()
{
    let $bundle := r-practrole:practRoles('1', '*', $family, '', '', '', '', 'team', 'true')  
    return
        <practitioners xmlns="">
                <count>{$bundle/fhir:count/string()}</count>
                <start>{$bundle/fhir:start/string()}</start>
                <length>{$bundle/fhir:length/string()}</length>
            {
                for $u in $bundle/fhir:entry/fhir:resource/fhir:PractitionerRole
                return
                    <user xmlns="http://hl7.org/fhir">
                        <reference value="{$u/fhir:practitioner/fhir:reference/@value/string()}"/>
                        <display value="{$u/fhir:practitioner/fhir:display/@value/string()}"/>
                    </user>
            }
        </practitioners>
};
 
declare function helper:signees(
          $signees as element(tei:signed)*
        , $url as xs:string
        ) as item()
{
    let $as := for $s in $signees
        let $toks := analyze-string($s/tei:l/tei:name,$dl2tei:regexp-signees)
        let $name := $toks/fn:match//fn:group[@nr=8]/string()
        let $user := if ($name)
            then helper:users($name)
            else ()
let $lll := util:log-app('TRACE','apps.nabu',$user)
        return
            if ($user and count($user/fhir:user) = 1)
            then 
                <author xmlns="http://hl7.org/fhir">
                    { $user/fhir:user/* }
                </author>
            else  
                let $sdis :=  $s/*:l/*:name/string()
                return
                    <author xmlns="http://hl7.org/fhir">
                        { $toks }
                        <display value="{$sdis}"/>
                    </author>
    return
        if (count($as/fhir:reference)>0)
        then
            <authors>
                <ok/>
                { 
                    for $a in $as[./fhir:reference]
                    return
                        $a
                }
            </authors>
        else
            <authors>
                <error>no signee identified</error>
                { $as }
            </authors>
};

declare function helper:validdate(
      $dl as element(tei:dateline)*
    ) as item()
{
    (: invalid: <dateline>Köln, den <date when="1900-01-01">19.03.20199</date>, </dateline> :)
    (: nodate: <dateline/> :)
    if (string-length($dl/string())=0 or $dl/@when="1900-01-01")
    then
    <date>
        <error>no valid date</error>
        { $dl }
    </date>
    else
    <date>
        <ok/>
        { $dl }
    </date>
};

declare function helper:physician(
          $a as element(tei:address)*
        ) as item()
{
    let $toks := analyze-string(string-join($a/tei:addrLine,'#'), $dl2tei:regexp-phys)
(: 
let $lll := util:log-system-out($toks)
:)
    let $name := ($toks/fn:match//fn:group[@nr=8]/string(), '#####')[1]
    let $fnam := ($toks/fn:match//fn:group[@nr=6]/string(), '#####')[1]
    let $plz  := ($toks/fn:match//fn:group[@nr=10]/string(), '')[1]
    let $ps   := r-practitioner:practitioners(
              "1", "*"
            , $name
            , $plz
            , ""
            , ""
            , ""
            , ""
            , "true"
            )
    return
        if (count($ps/fhir:Practitioner) = 1)
        then
            let $p := $ps/fhir:Practitioner
            let $pdis :=  concat($p/fhir:name/fhir:family/@value,', ',$p/fhir:name/fhir:given/@value)
            return
                <physician>
                    <ok/>
                    <recipient xmlns="http://hl7.org/fhir">
                        <reference value="metis/practitioners/{$p/fhir:id/@value/string()}"/>
                        <display value="{$pdis}"/>
                    </recipient>
                </physician>
        else if (count($ps/fhir:Practitioner) > 1)
        then
            if (count($ps/fhir:Practitioner[fhir:address/fhir:postalCode/@value = $plz]) = 1)
            then (: try to match forename :)
                let $p := $ps/fhir:Practitioner[fhir:address/fhir:postalCode/@value = $plz]
                let $pdis :=  concat($p/fhir:name/fhir:family/@value,', ',$p/fhir:name/fhir:given/@value)
                return
                <physician>
                    <ok/>
                    <recipient xmlns="http://hl7.org/fhir">
                        <reference value="metis/practitioners/{$p/fhir:id/@value/string()}"/>
                        <display value="{$pdis}"/>
                    </recipient>
                </physician>
            else
                <physician>
                    <error>too many practitioners</error>
                    <recipient xmlns="http://hl7.org/fhir">
                        { $ps }
                    </recipient>
                </physician>        
        else
                <physician>
                    <error>practitioner not found</error>
                    <recipient xmlns="http://hl7.org/fhir">
                        { $toks }
                    </recipient>
                </physician>
};

declare function helper:subject2patient(
          $subjects as element(tei:subject)*
        ) as item()
{
    if ($subjects and count($subjects) > 0)
    then
        let $ns := count($subjects/tei:persName[.!=''])
        return
        if ($ns > 0)
        then
            let $ps :=
                for $p in $subjects/tei:persName
                let $pat := r-patient:patients("kikl-spz", "u-admin", "1","*", tokenize($p/tei:surname,' ')[1],  "", $p/tei:birth/@when/string(),"official","","true")
                return
                    if (count($pat/fhir:Patient) = 1)
                    then
                        <subject xmlns="http://hl7.org/fhir">
                            <reference value="nabu/patients/{$pat/fhir:Patient/fhir:id/@value/string()}"/>
                            <display value="{helper:name2display($pat/fhir:Patient/fhir:name[fhir:use/@value='official'])}"/>
                        </subject>
                    else 
                        let $pats := $pat/fhir:Patient[matches(fhir:name/fhir:given/@value, $p/tei:forename)]
                        return
                        if (count($pats)=1)
                        then (: try to match forename :)
                            <subject xmlns="http://hl7.org/fhir">
                                <reference value="nabu/patients/{$pats/fhir:id/@value/string()}"/>
                                <display value="{helper:name2display($pats/fhir:name[fhir:use/@value='official'])}"/>
                            </subject>
                        else
                            <subject xmlns="http://hl7.org/fhir">
                                <error>patient not found</error>
                                <fuzzy>
                                {
                                    (: try to match 2 of 3 :)
                                    let $ps :=  r-patient:fuzzy("kikl-spz", "u-admin", "1","*", tokenize($p/tei:surname,' ')[1],  tokenize($p/tei:forename,' ')[1], $p/tei:birth/@when/string())
                                    for $pat in $ps/fhir:Patient
                                    return
                                        <subject xmlns="http://hl7.org/fhir">
                                            <reference value="nabu/patients/{$pat/fhir:id/@value/string()}"/>
                                            <display value="{helper:name2display($pat/fhir:name[fhir:use/@value='official'])}"/>
                                        </subject>
                                }
                                </fuzzy>
                            </subject>
            return
                if (count($ps/fhir:reference) = $ns)
                then
                    <subjects>
                        <ok/>
                        { $ps }
                    </subjects>
                else
                    <subjects>
                        <error>patient not identified </error>
                        { $ps }
                    </subjects>
        else 
            <subjects>
                <error>subject not parsed</error>
                { $subjects }
            </subjects>
    else
            <subjects>
                <error>no subject found</error>
            </subjects>
};
