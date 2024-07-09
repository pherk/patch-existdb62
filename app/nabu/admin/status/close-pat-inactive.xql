xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
(:~
 : list and update Patient inactive 
 :)
let $year := 2020
let $deadline := xs:string(current-date() - xs:yearMonthDuration("P3Y"))

let $ymin := xs:string($year) || "-01-01"
let $ymax := xs:string($year) || "-12-31"
let $esc := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $ctsc := collection('/db/apps/nabuCom/data/CareTeams')
let $asc := collection('/db/apps/nabuEncounter/data')
let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:birthDate[@value<$ymax]][fhir:birthDate[@value>=$ymin]]
let $pcnt := count($ps)
let $ll := util:log-app("TRACE","apps.nabu",$pcnt)
let $pse := for $p in $ps
    let $pid := concat('nabu/patients/',$p/fhir:id/@value)
    let $ea := $esc/fhir:EpisodeOfCare[fhir:subject[fhir:reference/@value=$pid]][fhir:status/@value='active']
    return
    if (count($ea)>0)
    then
        let $as := $asc/fhir:Encounter[fhir:subject[fhir:reference/@value=$pid]][fhir:status/@value='finished']
        let $asLast3years := $as/../fhir:Encounter[fhir:period/fhir:start/@value > $deadline]
        return
        if (count($asLast3years)>0)
        then ()
        else 
            let $cta := $ctsc/fhir:CareTeam[fhir:subject[fhir:reference/@value=$pid]][fhir:status/@value='active']
            let $upd := system:as-user('admin', 'kikl968',
                (
                  update value $ea/fhir:status/@value with 'finished'
                , if (count($cta)>0) then
                    update value $cta/fhir:status/@value with 'inactive'
                else ()
                )
            )
            return
                <p text="{$p/fhir:text/*:div/string()}" id="{$p/fhir:id/@value/string()}">closed</p>
    else ()
let $data :=
    <patients-eoc-closed all="{$pcnt}" cnt="{count($pse)}">
    { for $p in $pse
      order by $p/@text/string()
      return
          $p
    }</patients-eoc-closed>
return
    system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabu/statistics/evals","pat-eoc-closed-with-bd-in-" || $year || ".xml",$data))