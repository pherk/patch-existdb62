xquery version "3.1";
declare namespace fhir= "http://hl7.org/fhir";

declare function local:stat($c,$base)
{
    let $tstart := util:system-time()
    let $coll := collection(concat($base,'/',$c))
    let $tcoll := util:system-time()
    let $total  := count($coll/fhir:Encounter)
    let $finished := $coll/fhir:Encounter[fhir:status/@value='finished']
    let $cancelled:= $coll/fhir:Encounter[fhir:status/@value='cancelled']
    let $planned  := $coll/fhir:Encounter[fhir:status/@value='planned']
    let $tentative:= $coll/fhir:Encounter[fhir:status/@value='tentative']
    let $noshow   := $cancelled[fhir:statusHistory//fhir:code/@value='noshow']
    let $cnclpat  := $cancelled[fhir:statusHistory//fhir:code/@value='cancelled-pat']
    let $cnclspz  := $cancelled[fhir:statusHistory//fhir:code/@value='cancelled-spz']
    let $tend := util:system-time()
    let $runtimems1 := (($tcoll - $tstart) div xs:dayTimeDuration('PT1S'))  * 1000
    let $runtimems2 := (($tend - $tcoll) div xs:dayTimeDuration('PT1S'))  * 1000
    let $lll := util:log-app('TRACE','apps.nabu',concat($runtimems1,' - ', $runtimems2))
return
    <coll name="{$c}">
        <finished total="{count($finished)}"/>
        <cancelled total="{count($cancelled)}" noshow="{count($noshow)}" cnclpat="{count($cnclpat)}" cnclspz="{count($cnclspz)}"/>
        <planned total="{count($planned)}" tentative="{count($tentative)}"/>"
    </coll>
};

let $base := '/db/apps/nabuEncounter/data'
let $years := for $year in (2004 to 2021)
        return
            xs:string($year)
let $colls := ('planned',$years,'rest')

return
    <encounters>
{
      local:stat("",$base)
    , for $c in $colls
      return
        local:stat($c,$base)
}
</encounters>