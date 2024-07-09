xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
(:~
 : listet Patient über 18 aus zeitraum
 :)
let $year := "2020"
let $tmin := $year || "-01-01" || "T00:30:00"
let $tmax := $year || "-12-31" || "T20:00:00"
let $esc := collection('/db/apps/nabuEncounter/data/' || $year)
let $psc := collection('/db/apps/nabuData/data/FHIR/Patients')
let $encs := $esc/fhir:Encounter[fhir:period/fhir:start[@value<$tmax]][fhir:period/fhir:end[@value>$tmin]]
let $ecnt := count($encs)
let $bins := xs:integer(floor($ecnt div 512))
let $ps := for $i in (0 to $bins)
    let $ebin := subsequence($encs,$i*512+1,($i+1)*512)
    let $pbs := for $e in $ebin
        let $start := $e/fhir:period/fhir:start/@value/string()
        return
        <e id="{substring-after($e/fhir:subject/fhir:reference/@value,'nabu/patients/')}"
           date="{if ($start="")
                    then "2222-01-01"
                    else substring($e/fhir:period/fhir:start/@value,1,10)}"/>
let $ll := util:log-app("TRACE","apps.nabu",count($pbs))
    for $pb in $pbs
    let $p := $psc/fhir:Patient[fhir:id[@value=$pb/@id/string()]]
    let $bd := $p/fhir:birthDate/@value/string()
    let $status := $p/fhir:extension[@url='#patient-over-18']/fhir:valueCodeableConcept/fhir:coding/fhir:code/@value/string()
    let $MIType := $p/fhir:extension[@url='#patient-medical-insurance']//fhir:code/@value/string()
    let $MIName := $p/fhir:extension[@url='#patient-medical-insurance']//fhir:display/@value/string()
    return
        if ($bd="")
        then <p text="{$p/fhir:text/*:div/string()}" date="{$pb/@date/string()}" id="{$p/fhir:id/@value/string()}">ERROR</p>
        else if ($bd < xs:string((xs:date($pb/@date) - xs:yearMonthDuration("P18Y"))))
        then <p text="{$p/fhir:text/*:div/string()}" status="{$status}" vt="{$MIType}" vn="{$MIName}" ed="{$pb/@date/string()}" id="{$p/fhir:id/@value/string()}"></p>
        else ()
let $ll := util:log-app("TRACE","apps.nabu",count($ps))
let $pids := distinct-values(for $p in $ps return $p/@id/string())
let $ll := util:log-app("TRACE","apps.nabu",$ps)
let $ll := util:log-app("TRACE","apps.nabu",$pids)
let $p18 := for $id in $pids
      return
          $ps[@id=$id][1]
let $data := 
    <patients-over-18 cnt="{count($p18)}">
    { for $p in $p18
      order by $p/@text/string()
      return
          $p
    }</patients-over-18>
return
    system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabu/statistics/evals","p18-" || $year || ".xml",$data))
