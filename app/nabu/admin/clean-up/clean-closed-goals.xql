xquery version "3.1";


import module namespace r-goal = "http://enahar.org/exist/restxq/nabu/goals" at "/db/apps/nabu/FHIR/Goal/goal-routes.xqm";
import module namespace r-eoc  = "http://enahar.org/exist/restxq/nabu/eocs" at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare-routes.xqm";

declare namespace fhir= "http://hl7.org/fhir";

declare function local:updateGoal(
      $id as xs:string
    , $sref as xs:string
    , $sdis as xs:string
    , $eoca as element(fhir:EpisodeOfCare)*
    , $eocc as element(fhir:EpisodeOfCare)*
    , $os as element(fhir:Order)*
    , $es as element(fhir:Encounter)*
    , $today as xs:string*
    )
{
    let $pid := substring-after($sref,'nabu/patients/')

    let $eoc := ($eoca,$eocc)[1]
    let $snam  := $eoc/fhir:subject/fhir:display/@value/string()
    let $start := substring($eoc/fhir:period/fhir:start/@value,1,10)
    let $due   := xs:date($start) + xs:dayTimeDuration("P180D")
    let $rstatus := if ($eocc  and count($eoca)=0)
        then if ($es and count($es/../fhir:Encounter[fhir:status[@value='finished']]) > 0)
            then 'achieved'
            else $eocc[1]/../fhir:EpisodeOfCare/fhir:status/@value/string()
        else if ($es and count($es/../fhir:Encounter[fhir:status[@value='finished']]) > 0)
        then 'achieved'
        else if ($es and count($es/../fhir:Encounter[fhir:status[@value='planned']]) > 0)
        then 'planned'
        else if ($os and count($os/../fhir:Order[fhir:status[@value!='cancelled']]) > 0)
        then if (count($os)=count($os/../fhir:Order[fhir:status[@value=('completed','cancelled')]]) (: keine offene Anforderung :)
                and 
                count($es)=1 and $es/fhir:status/@value='cancelled' 
                and $es/fhir:statusHistory//fhir:code/@value=('noshow','cancelled-pat'))
            then 'finished'
            else 'order'
(:~
 :  patienten, die eine Anforderung und
 :  Termin bekommen haben, aber den nicht wahrgenommen oder canceln haben lassen
 :  können auf 'finished'/'Abbruch o.w.T.' gesetzt werden, die EoC auf finished 
 :) 
        else if ($eoca and count($eoca/../fhir:EpisodeOfCare/fhir:statusHistory/fhir:extension[@url='#eoc-workflow-change']/fhir:valueCodeableConcept/fhir:coding[fhir:code/@value='registration-form'])>0)
        then 'infos'
        else 'new'
    let $lcs := switch($rstatus)
        case 'new' return 'proposed'
        case 'infos' return 'accepted'
        case 'order' return 'active'
        case 'planned' return 'active'
        case 'achieved' return 'completed'
        case 'cancelled' return 'cancelled'
        case 'finished' return 'completed'
        default return 'proposed'
    let $as := switch($rstatus)
        case 'new' return 'in-progress'
        case 'infos' return 'in-progress'
        case 'order' return 'improving'
        case 'planned' return 'achieved'
        case 'achieved' return 'sustaining'
        case 'cancelled' return 'not-achieved'
        case 'finished' return 'not-achieved'
        default return 'in-progress'
    let $asd := switch($rstatus)
        case 'new' return 'in Arbeit'
        case 'infos' return 'in Arbeit'
        case 'order' return 'Besserung'
        case 'planned' return 'erreicht'
        case 'achieved' return 'nachhaltig erreicht'
        case 'cancelled' return 'nicht erreicht'
        case 'finished' return 'Abbruch o.w.T.'
        default return 'in Arbeit'
    let $sd := switch($rstatus)
        case 'new' return $start
        case 'infos' return min(for $e in $eoca/../fhir:EpisodeOfCare[fhir:statusHistory/fhir:extension[@url='#eoc-workflow-change']/fhir:valueCodeableConcept/fhir:coding[fhir:code/@value='registration-form']]
                                return
                                    substring($e/fhir:period/fhir:start/@value,1,10))
        case 'order' return min(for $o in $os/../fhir:Order[fhir:status[@value!='cancelled']]
                                return
                                    substring($o/fhir:date/@value,1,10))

        case 'planned' return min(for $e in $es/../fhir:Encounter[fhir:status[@value='planned']]
                                return
                                    substring($e/fhir:period/fhir:start/@value,1,10))
        case 'achieved' return min(for $e in $es/../fhir:Encounter[fhir:status[@value='finished']]
                                return
                                    substring($e/fhir:period/fhir:start/@value,1,10))
        default return $today
    return
        if ($rstatus!='new')
        then
            (:
            let $res := r-goal:updateTwoStatus($id,'kikl-spzn','u-admin','admin',$lcs,$as,$sd)
            return
            
                if ($res='error')
                then 
                    let $lll := util:log-app("ERROR", "apps.nabu",<updated pid="{$pid}" gid="{$id}" name="{$sdis}" status="error" info="r-goal"/>)
                    return 'error'
                else if ($rstatus=('cancelled','finished')
                then 'finished'
                else ()
                :)
            $rstatus
                    
        else ()
};


let $ecs  := collection('/db/apps/nabuEncounter/data')/fhir:Encounter
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')/fhir:EpisodeOfCare

let $ocs  := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order
let $today := adjust-date-to-timezone(current-date(),())
(: Alle offenen Anmeldungen :)
let $gs := collection('/db/apps/nabuCom/data/Goals')/fhir:Goal[fhir:category/fhir:coding[fhir:code/@value='registration']][fhir:lifecycleStatus[@value=('proposed','planned','accepted','on-hold','active')]]
let $upds :=
    for $g in $gs
    let $gid := $g/fhir:id/@value/string()
    let $sref := $g/fhir:subject/fhir:reference/@value/string()
    let $sdis := $g/fhir:subject/fhir:display/@value/string()
    let $eoc  := $eocs/../fhir:EpisodeOfCare[fhir:subject[fhir:reference/@value=$sref]]
    let $os   := $ocs/../fhir:Order[fhir:subject/fhir:reference[@value=$sref]]
    let $es   := $ecs/../fhir:Encounter[fhir:subject[fhir:reference/@value=$sref]]
    let $eoca  : = $eoc/../fhir:EpisodeOfCare[fhir:status[@value=('proposed','planned','active','waitlist','on-hold')]]
    let $eocc  : = $eoc/../fhir:EpisodeOfCare[fhir:status[@value=('cancelled','finished')]]
    return
        if (count($eoca)=1 or $eocc)
        then if (local:updateGoal($gid,$sref,$sdis,$eoca,$eocc,$os,$es,$today)='finished')
            then (: set EoC finished, if Goal cancelled :)
            (:
                r-eoc:updateStatus((), $eoc/fhir:id/@value/string(),'kikl-spzn','u-admin','admin','finished')            
                :)
                <updated pid="{$sref}" gid="{$gid}" name="{$sdis}" status="finished"/>
            else ()
        else 
            <updated pid="{$sref}" gid="{$gid}" name="{$sdis}" status="error" info="with dup active eoc"/>

let $data := 
<registration-active all="{count($gs)}">
    <upds n="{count($upds)}">
        <achieved>{count($upds[@status='achieved'])}</achieved>
        <planned>{count($upds[@status='planned'])}</planned>
        <order>{count($upds[@status='order'])}</order>
        <infos>{count($upds[@status='infos'])}</infos>
        <cancelled>{count($upds[@status=('cancelled','finished')])}</cancelled>
    </upds>
    <cancelled>
    { $upds[@status=('cancelled','finished')] }
    </cancelled>
    <error>
    { $upds[@status='error'] }
    </error>
</registration-active>

return
    system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabu/admin","update-goals-" || $today || ".xml",$data))