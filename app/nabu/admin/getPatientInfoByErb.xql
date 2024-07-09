xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $besuch :=
(
      7043699
    , 7043735
    , 7043904
    , 7045114
    , 7023138
    , 7048414
   )

let $year := '2023'
let $pc := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:active[@value="true"]]
let $ec := collection('/db/apps/nabuEncounter/data/' || $year)/fhir:Encounter
let $cc := collection('/db/apps/nabuCom/data/Conditions')/fhir:Condition
let $infos :=
    for $id in distinct-values($besuch)
    let $p := $pc/../fhir:Patient[fhir:identifier[fhir:value/@value=$id]]

    return

    if (count($p)=1)
    then
        let $pref := concat("nabu/patients/",$p/fhir:id/@value)
        let $eps := $ec/../fhir:Encounter[fhir:subject[fhir:reference/@value=$pref]][fhir:status[@value='finished']]
        let $cs := $cc/../fhir:Condition[fhir:subject[fhir:reference/@value=$pref]][fhir:code/fhir:coding[fhir:system[@value="http://hl7.org/fhir/sid/icd-10-de"]]]
        let $ccs := $cs/../fhir:Condition[fhir:verificationStatus[@value='confirmed']]
        return
            <info id="{$id}" name="{$p/fhir:text/*:div/*:div}">
            { if (count($eps)>0)
              then
                for $e in $eps/../fhir:Encounter
                let $reason := if ($e/fhir:basedOn/fhir:display/@value=('spontan','Request Import','Human-friendly name for the CarePlan ...'))
                    then $e/fhir:reason/fhir:text/@value
                    else $e/fhir:basedOn/fhir:display/@value
                order by $e/fhir:period/fhir:start/@value
                return
                    <e date="{$e/fhir:period/fhir:start/@value}"
                       e="{$e/fhir:participant/fhir:actor/fhir:display/@value}"
                       s="{$e/fhir:participant/fhir:type/fhir:coding/fhir:display/@value}"
                       r="{$reason}"></e>
              else
                <e>Kein Besuch</e>
            }
            { if (count($ccs)>0)
              then
                  for $c in $ccs
                  return
                      <dx icd="{$c/fhir:code/fhir:coding[fhir:system[@value="http://hl7.org/fhir/sid/icd-10-de"]]/fhir:code/@value}">{$c/fhir:code/fhir:text/@value}</dx>
              else if (count($cs) > 0)
              then
                  let $scs :=  for $c in $cs
                        order by $c/fhir:assertDate/@value
                        return
                            $c
                  return
                      for $c in subsequence($scs,1,5)
                      return
                      <dxu icd="{$c/fhir:code/fhir:coding[fhir:system/@value="http://hl7.org/fhir/sid/icd-10-de"]/fhir:code/@value}">{$c/fhir:code/fhir:text/@value}</dxu>
              else
                <dx>Keine Diagnose</dx>
            }
            </info>
    else if (count($p)>1)
    then
        <dub>{$p}</dub>
    else
        <info id="{$id}">Keine ORBIS PID</info>
let $erbs := distinct-values($infos/e/@e)
return
<faelle>
    {
        for $erb in $erbs[not(.=("EEG1","EEG2"))]
        return
            <erbringer name="{$erb}">
            {
            for $i in $infos[e[@e=$erb]]
            order by $i/@id/string()
            return
                $i
            }
            </erbringer>
    ,   <keinePID>
        {
            for $i in $infos[not(e)]
            order by $i/@id/string()
            return
                $i
        }
        </keinePID>
    ,   <keinBesuch>
        {
            for $i in $infos[e[not(@e)]]
            order by $i/@id/string()
            return
                $i
        }
        </keinBesuch>
    }
</faelle>
