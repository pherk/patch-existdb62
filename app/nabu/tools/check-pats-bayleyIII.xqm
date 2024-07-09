xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

(: 
 : check patients 2-2;6 years old with more than one Encounter
 :)

declare function local:hasParticipants(
          $cts as item()+
        ) as xs:boolean
{
    let $ps := $cts/fhir:participant
    return
        count($ps)>1 or (count($ps)=1 and $ps/fhir:period/fhir:start!=$ps/fhir:period/fhir:end)
};

declare function local:hasEncountersButNoBayleyIII(
          $es as item()*
        , $ne
        ) as xs:boolean
{
    if (count($es)>=$ne)
    then if ($es/fhir:participant/fhir:actor/fhir:reference/@value="metis/practitioners/u-beldowitschr" or matches($es/fhir:reason/fhir:text/@value,'Bayley'))
        then false()
        else true()
    else false()
};

let $psc  := collection('/db/apps/nabuData/data/FHIR/Patients')
let $ctsc := collection('/db/apps/nabuCom/data/CareTeams')
let $esc  := collection('/db/apps/nabuEncounter/data/2016') |
             collection('/db/apps/nabuEncounter/data/2017') |
             collection('/db/apps/nabuEncounter/data/2018') |
             collection('/db/apps/nabuEncounter/data/planned')
let $ps := $psc/fhir:Patient[fhir:birthDate[@value>'2016-01-01'][@value<'2016-06-30']]
return

<treffer von="{count($ps)}">
{
    for $p in $ps[fhir:active[@value='true']]
    let $pid := $p/fhir:id/@value/string()
    let $pref := concat('nabu/patients/',$pid)
    let $cts := $ctsc/fhir:CareTeam[fhir:subject[fhir:reference/@value=$pref]][fhir:status[@value="active"]]
    let $es := $esc/fhir:Encounter[fhir:subject[fhir:reference[@value=$pref]]][fhir:status[@value=("finished","planned")]]
    order by $p/fhir:birthDate/@value/string()
    return
        if (local:hasEncountersButNoBayleyIII($es,3))
        then
            <patient name="{concat($p/fhir:name[fhir:use/@value='official']/fhir:family/@value, ', ', $p/fhir:name[fhir:use/@value='official']/fhir:given/@value, ', *', $p/fhir:birthDate/@value,' : ')}"/>
        else ()

}
</treffer>
