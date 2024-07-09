xquery version "3.1";
declare namespace fhir= "http://hl7.org/fhir";

(:  aus goal-infos.xml
    <registrationStatus>
        <code label-de="alle" value="all" ls="active-only" as=""/>
        <code label-de="NeuAnmeldung" value="new" ls="proposed" as="in-progress"/>
        <code label-de="Anmeldebogen" value="infos" ls="accepted" as="in-progress"/>
        <code label-de="Anforderung" value="order" ls="active" as="improving"/>
        <code label-de="Termin geplant" value="planned" ls="active" as="achieved"/>
        <code label-de="Termin finished" value="achieved" ls="completed" as="sustaining"/>
        <code label-de="Abbruch o.T." value="cancelled" ls="completed" as="not-attainable"/>
        <code label-de="Cancelled" value="entered-in-error" ls="cancelled" as="not-attainable"/>
    </registrationStatus>
:)
declare function local:create_histograms(
      $gs as element(fhir:Goal)*
    , $lcs as xs:string+
    , $y as xs:integer
    , $m as xs:integer
    , $nbins as xs:integer)
{
    for $s in $lcs
    let $gss := $gs[fhir:lifecycleStatus[@value=$s]]
    return 
        <status s="{$s}" cnt="{count($gss)}">
        {
            local:bins($gss,$y,$m,$nbins)
        }
        </status>
};

declare function local:bins(
      $gs as element(fhir:Goal)*
    , $y as xs:integer
    , $m as xs:integer
    , $nbins as xs:integer)
{
    let $bins := for $g in $gs
        let $gy := xs:integer(tokenize($g/fhir:startDate/@value,'-')[1])
        let $gm := xs:integer(tokenize($g/fhir:startDate/@value,'-')[2])
        return
            if ($gy<$y and $gm<$m)
            then <bin y="{$gy}" m="0">{$g}</bin>
            else
                 <bin y="{$gy}" m="{$gm}">{$g}</bin>
    for $b in (0 to $nbins - 1)
    let $bm := if ($b=0)
        then 0
        else ($m+$b - 1) mod 12 + 1
    return
        <month  m="{$bm}" cnt="{count($bins[@m=$bm])}">
        {
            if (($bm < $m) or $bm > $m)
            then
                local:showAccepted($bins[@m=$bm]/fhir:Goal[fhir:lifecycleStatus[@value='accepted']])
            else ()
        }
        </month>
};

declare function local:showAccepted($ags as element(fhir:Goal)*)
{
    for $ag in $ags
    order by $ag/fhir:startDate/@value/string()
    return
        <p name="{$ag/fhir:subject/fhir:display/@value/string()}" start="{substring($ag/fhir:startDate/@value,1,10)}"/>
};

let $cat := 'registration'
let $lcs := ('proposed','accepted','active')
let $base := '/db/apps/nabuCom/data/Goals'
let $gcs := collection($base)
let $gs := $gcs/fhir:Goal[fhir:category/fhir:coding[fhir:code/@value=$cat]][fhir:lifecycleStatus[@value=$lcs]]

let $today := current-date()
let $cy := tokenize($today,'-')[1]
let $cm := tokenize($today,'-')[2]
let $nbins := 13
let $start := concat(xs:string(xs:integer($cy) - 1), '-', xs:string(xs:integer($cm) + 1))
let $end := concat($cy,'-',$cm)
return
    <goals category="{$cat}" lcs="{$lcs}" all="{count($gs)}" nbins="{$nbins}" year="{$cy}" start="{$start}" end="{$end}">
    {
        local:create_histograms($gs,$lcs,xs:integer($cy),xs:integer($cm),$nbins)
    }
    </goals>