xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

(: 
 : check patients with active Orders with more than one Encounter cancelled
 :)


declare function local:hasTrailingCancelledEncounters(
          $es as element(fhir:Encounter)*
        , $fes as element(fhir:Encounter)*
        , $ces as element(fhir:Encounter)*
        , $ne
        , $nc
        ) as xs:boolean
{
    if (count($es)>=$ne and count($ces)>=$nc)
        then
            let $fstarts := for $d in $fes
                            order by $d/fhir:period/fhir:start/@value/string() descending
                                return $d/fhir:period/fhir:start/@value/string()
            let $cstarts := for $d in $ces
                            order by $d/fhir:period/fhir:start/@value/string() descending
                                return $d/fhir:period/fhir:start/@value/string()
            return $fstarts[1] < $cstarts[1]
            
        else false()
};

let $psc  := collection('/db/apps/nabuData/data/FHIR/Patients')
let $osc  := collection('/db/apps/nabuData/data/FHIR/Orders')
let $ctsc := collection('/db/apps/nabuCom/data/CareTeams')
let $esc  := collection('/db/apps/nabuEncounter/data/2018')
let $ps := $psc/fhir:Patient
let $os := $osc/fhir:Order[fhir:status[@value='active']]
return

<treffer pats="{count($ps)}" orders="{count($os)}">
{
    for $o in subsequence($os,1000,1000)
    let $pref := $o/fhir:subject/fhir:reference/@value/string()
    let $pid := substring-after($pref,'nabu/patients/')
    let $p := $psc/fhir:Patient[fhir:id[@value=$pid]]
    let $es := $esc/fhir:Encounter[fhir:subject[fhir:reference[@value=$pref]]]
    let $fes := $esc/fhir:Encounter[fhir:subject[fhir:reference[@value=$pref]]][fhir:status[@value=("finished")]]
    let $ces := $esc/fhir:Encounter[fhir:subject[fhir:reference[@value=$pref]]][fhir:status[@value="cancelled"]][fhir:statusHistory//fhir:code/@value!='cancelled-spz']
    order by $o/fhir:date/@value/string() 
    return
        if (local:hasTrailingCancelledEncounters($es,$fes,$ces,3,3))
        then
            <patient name="{concat($p/fhir:name[fhir:use/@value='official']/fhir:family/@value, ', ', $p/fhir:name[fhir:use/@value='official']/fhir:given/@value, ', *', $p/fhir:birthDate/@value,' : ')}">
            </patient>
        else ()
}
</treffer>
