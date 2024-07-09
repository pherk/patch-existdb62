xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";

declare function local:copy($element as element()) as element() {
   element {node-name($element)}
      {$element/@*,
          for $child in $element/node()
              return
               if ($child instance of element())
                 then local:copy($child)
                 else $child
      }
};

declare function local:updateBasedOn($r, $cid, $cdisp, $res)
{
    let $upd := if ($r/fhir:basedOn)
        then
            system:as-user("vdba","kikl823!",
                (
                  update value $r/fhir:basedOn/fhir:reference/@value with concat('nabu/careplans/',$cid)
                , update value $r/fhir:basedOn/fhir:display/@value with $cdisp
                )
            )
        else 
            system:as-user("vdba","kikl823!",
                (
                  update insert <basedOn xmlns="http://hl7.org/fhir">
                                    <reference value="{concat('nabu/careplans/',$cid)}"/>
                                    <display value="{$cdisp}"/>
                                </basedOn>
                            following $r/fhir:meta
                )
            )
    return
        $res
};

declare function local:updateRessources(
      $s as xs:string
    , $acc as element(fhir:CarePlan)
    , $dons as element(fhir:CarePlan)*
    , $os as element(fhir:Order)*
    , $es as element(fhir:Encounter)*
    , $ts as element(fhir:Task)*
    ) as item()
{
    let $cid   := $acc/fhir:id/@value/string()
    let $cdisp := $acc/fhir:title/@value/string()
    return
    <updateRessources s="{$s}">
        <acc xmlid="{$acc/@xml:id/string()}" title="{$acc/fhir:title/@value/string()}" nas="{count($acc/fhir:activity)}"/>
        <dons>
        {
            for $d in $dons
            let $did := $d/fhir:id/@value/string()
            return
                <don id="{$did}" xmlid="{$d/@xml:id/string()}" nas="{count($d/fhir:activity)}">
                {
                    for $a in $d/fhir:activity
                    let $type := if ($a/fhir:reference)
                        then substring($a/fhir:reference/fhir:reference/@value, 6,1)
                        else if ($a/fhir:detail)
                        then 'i'
                        else 'error'
                    return
                        switch ($type)
                        case 'o' return
                                    let $oid := substring-after($a/fhir:reference/fhir:reference/@value,'nabu/orders/') 
                                    let $o := $os[fhir:id[@value=$oid]]
                                    let $eos := $es[fhir:appointment/fhir:reference[starts-with(@value,concat('nabu/orders/',$oid))]]
                                    return
                                        <order id="{$oid}" status="{$o/fhir:status/@value/string()}">
                                            { if ($o)
                                            then local:updateBasedOn($o,$cid,$cdisp,<updateOrderBasedOn id="{$oid}"/>)
                                            else <notFound/>
                                            }
                                            { if ($eos)
                                            then
                                                    <updateEncounters>
                                                    {
                                                        for $e in $eos
                                                        return 
                                                            local:updateBasedOn($e,$cid,$cdisp,<updateEncounterBasedOn id="{$e/fhir:id/@value/string()}"/>)
                                                    }
                                                    </updateEncounters>
                                            else <notFound/>
                                            }
                                        </order>
                        case 't' return
                                    let $tid := substring-after($a/fhir:reference/fhir:reference/@value,'nabu/tasks/') 
                                    let $t := $ts[fhir:id[@value=$tid]]
                                    return
                                        <task>
                                        { if ($t)
                                        then local:updateBasedOn($t,$cid,$cdisp,<updateTaskBasedOn id="{$tid}"/>)
                                        else <notFound/>
                                        }
                                        </task>
                        case 'i' return
                                    let $eid := substring-after($a/fhir:outcomeReference/fhir:reference/@value,'nabu/encounters/')
                                    let $ei  := $es[fhir:id[@value=$eid]]
                                    return
                                        <inline type="{$a/fhir:detail/fhir:category/fhir:coding[fhir:system/@value='http://hl7.org/fhir/care-plan-activity-category']/fhir:code/@value}">  
                                        { local:updateBasedOn($ei,$cid,$cdisp,<updateEncounterBasedOn id="{$eid}"/>) }
                                        </inline>
                        default return <error/>
                }
                </don>
        }
        </dons>
    </updateRessources>    
};

declare function local:mergeCPs(
      $acc as element(fhir:CarePlan)
    , $dons as element(fhir:CarePlan)*
    ) as item()
{
    (:
    let $as := for $e in ($acc/fhir:activity, $dons/fhir:activity)
        return
            local:copy($e)
    let $dela := 
        let $nas := count($acc/fhir:activity)
        let $del := system:as-user("vdba","kikl823!", update delete $acc/fhir:activity)
        return
            <deleteActivities acc="{$nas}"/>
            :)
    let $ins := 
        for $a in $dons/fhir:activity
        order by min(for $time in $a/fhir:progress/fhir:time/@value return xs:dateTime($time)) descending
        return
            let $upd :=  system:as-user("vdba","kikl823!", update insert $a into $acc)
            return
                <insertActivity start="{min(for $time in $a/fhir:progress/fhir:time/@value return xs:dateTime($time))}"/>
    let $ups := 
        let $old := $acc/fhir:status/@value
        let $all := distinct-values(($old,$dons/fhir:status/@value))
        let $new := if ('active' = $all)
                then 'active'
                else if (count($all)=1)
                then $old
                else if ('completed' = $all)
                then 'completed'
                else 'cancelled'
        return
            if ($new!=$old)
            then
                let $upds := update value $acc/fhir:status/@value with $new
                return
                    <updateStatus old="{$old}" new="{$new}"/>
            else ()
    let $delcp := 
        let $ncps := count($dons)
        let $del := system:as-user("vdba","kikl823!",
            (
                for $d in $dons
                return
                    update value $d/fhir:status/@value with 'entered-in-error'
            ))
        return
                <deleteCPs  dons="{$ncps}"/>
    return
        <mergeCP id="{$acc/fhir:id/@value/string()}" xmlid="{$acc/@xml:id/string()}">
        <!--    {$dela} -->
            {$ins}
            {$ups}
            {$delcp}
        </mergeCP>
};

let $cps := collection('/db/apps/nabuCom/data/CarePlans')
let $oc  := collection('/db/apps/nabuData/data/FHIR/Orders')
let $tc  := collection('/db/apps/nabuCom/data/Tasks')
let $ec  := collection('/db/apps/nabuEncounter/data')
let $scps := $cps/fhir:CarePlan[starts-with(fhir:title/@value,'Request')][fhir:status[@value="active"]]
let $ss := distinct-values($scps/fhir:subject/fhir:reference/@value)

for $s in $ss[.!='']
(: 
 : let $s := "nabu/patients/p-589263d5-3271-4f51-9e69-551735eb6886" (: order only :)
 : let $s := "nabu/patients/p-21666" (: order, inline :)
 : let $s := "nabu/patients/p-9cfcd3ae-ac60-43fa-82fb-cfa5ccceee9a" (: task only :)
 :)

let $cpss := $cps/fhir:CarePlan[fhir:subject/fhir:reference[@value=$s]][fhir:status[@value=("active","completed","cancelled","draft")]]
return
    if (count($cpss)>1) (: lower to 1 :)
    then
        let $os := $oc/fhir:Order[fhir:subject/fhir:reference[@value=$s]]
        let $es := $ec/fhir:Encounter[fhir:subject/fhir:reference[@value=$s]]
        let $ts := $tc/fhir:Task[fhir:subject/fhir:reference[@value=$s]]
        (: select one :)
        let $acc := let $notRI := $cpss[not(starts-with(fhir:title/@value,('Human','Request')))]      (: not imported or edited :)
            let $first := $notRI[1]/fhir:id/@value
            return
                if (count($notRI)=0)
                then $cpss[1]
                else $cpss[fhir:id[@value=$first]]
        let $dons := for $c in $cpss[fhir:id[@value!=$acc/fhir:id/@value]]
            return
                if (count($c/fhir:activity)=0)
                then $c (: to be deleted :)
                else $c
        return
                let $rupd := local:updateRessources($s, $acc, $dons, $os, $es, $ts)
                let $merge:= local:mergeCPs($acc, $dons)
                return
                    ($rupd,$merge)
    else ()