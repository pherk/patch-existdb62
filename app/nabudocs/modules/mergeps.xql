xquery version "3.1";


declare variable  $local:regexp-procs :=
    string-join(
    (
       "^(.*(EEG|ERG|VEP|SEP|MRT)[^:]?):$"
    ,  "^(Achse [IV]+)"
    ), '|');
    
declare function local:mergeps($ps as item()*)
{
    if (count($ps)>0)
    then
        reverse(local:mergeps2(head($ps),tail($ps),()))
    else
        ()
};

declare function local:mergeps2($h as item(),$t as item()*,$acc as item()*)
{
    if (local-name($h)='p' and local-name(head($t))='p')
    then
        (: merge if missing stop or proc label in $h :)
        let $tuple := local:merge2ps($h,head($t))
        let $nt    := (tail($tuple),tail($t))
        let $nacc  := (head($tuple),$acc)
        return
            if (count($nt)>0)
            then
                local:mergeps2(head($nt),tail($nt),$nacc)
            else
                $nacc
    else
        if (count($t)>0)
        then
            local:mergeps2(head($t),tail($t), ($h, $acc))
        else
            ($h,$acc)
};

declare function local:merge2ps(
      $h as item()
    , $t as item()+
    ) as item()+
{
    if (ends-with($h,'.'))
    then
        ($h,$t)
    else if (ends-with($h,':'))
    then
        (
          <p xmlns="http://www.tei-c.org/ns/1.0" >
            <span>{local:procedure($h)}</span>
            <span>{normalize-space(head($t))}</span>
          </p>
        , tail($t)
        )        
    else
        (
          <p xmlns="http://www.tei-c.org/ns/1.0">
          { concat($h,' ',head($t))}
          </p>
        , tail($t)
        )
};
declare function local:procedure($s as xs:string*)
{
    let $ns := normalize-space($s)
    let $toks := analyze-string($ns, $local:regexp-procs)
(: 
    let $lll := util:log-app("DEBUG","nabu",$toks)
:)
    return
        if ($toks/fn:match)
        then
            if ($toks/fn:match//*:group)
            then <name type="fhir:procedure" nymRef="{concat('#procedure-',$toks/fn:match//fn:group[@nr=2])}"><strong>{$ns}:</strong></name>
            else
                <name type="MAS" nymRef="{concat('#mas-axis-',$toks/fn:match//fn:group[@nr=3])}"><strong>{$ns}:</strong></name>
        else $ns
};

let $ps :=
<div xmlns="http://www.tei-c.org/ns/1.0" >
                        <p>Eickholt, Emil, geboren 25.03.2003</p>
                        <p>Sehr geehrte Frau Kollegin,</p>
                        <p>ich berichte über die ambulante EEG-Kontrolle vom 26.03.2015.</p>
                        <list type="dxlist" rend="gloss">
                            <label>
                                <hi rend="bold">Diagnosen:</hi>
                            </label>
                            <item>
                                <name type="diagnosis" nymRef="">Generalisierte Epilepsie mit Absencen und Photosensibilität</name>
                            </item>
                        </list>
                        <list type="txlist" rend="gloss">
                            <label>
                                <hi rend="bold">Therapien:</hi>
                            </label>
                            <item>
                                <name type="fhir:procedure" nymRef="">Petnidan 2 x 250 mg</name>
                            </item>
                        </list>
                        <p>Bei nur geringer <strong>Gewichtszunahme</strong> bewegt sich die Petnidandosierung weiterhin am unteren</p>
                        <p>therapeutischen Bereich. Anfallsverdächtige Zustände sind nicht beobachtet worden lt. Mutter. Insgesamt geht es dem Junge gut. Es wird jedoch über Interaktionsstörungen mit Mitschülern in der Schule berichtet. Es erfolge eine Moderation durch den örtlichen Sozialarbeiter.</p>
                        <p>EEG:</p>
                        <p>Altersgerecht differenzierte Grundaktivität ohne konstante Seitendifferenz, Herdbefund. Einmalig abortiver Ausbruch bei Augenschluss. Im Vergleich zum Vor-EEG von 2014 weitere Abnahme der Zahl der ETP-Ausbrüche. Auf eine Fotostimulation wurde heute planmäßig verzichtet.</p>
                        <p>Beim Wohlbefinden wird die niedrige Petnidan-Dosierung fortgesetzt. Ein Absetzen ist in</p>
                        <p>1 – 2 Jahren vor der eigentlichen Pubertätsphase geplant. Routinekontrolle in 1 Jahr.</p>
</div>
return
    local:mergeps($ps/*)