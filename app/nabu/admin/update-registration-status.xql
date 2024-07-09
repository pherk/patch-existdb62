xquery version "3.1";

(:~
 : update-registration-status
 : 
 : selects all active 'registration' goals
 : checks Anmeldebogen, Anforderung, planned or finished encounter
 : sets lifecycleStatus and achievementStatus accordingly
 : 

 :  : xquery version "1.0";

(:~
 : Simple XQuery example without HTML templating. The entire app is contained in one file.
:)
import module namespace request="http://exist-db.org/xquery/request";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../modules/config.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

declare function local:main() as node()?
{
    session:create(),
    return
	    <p>Dauert ein paar Minuten</p>
};

<html>
    <head>
        <title>Number Guessing</title>
        <style type="text/css">
            body {{ width: 400px; }}
            label {{ width: 120px; display: block; float: left; }}
        </style>
    </head>
    <body>
        <h1>Anmeldung - Status aktualisieren</h1>
        <form action="{session:encode-url(request:get-uri())}">
            <label>Aktualisieren!</label>
            <input type="submit"/>
        </form>
        { local:main() }
    </body>
</html>
 :)
import module namespace r-goal = "http://enahar.org/exist/restxq/nabu/goals" at "/db/apps/nabu/FHIR/Goal/goal-routes.xqm";
import module namespace r-eoc  = "http://enahar.org/exist/restxq/nabu/eocs" at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare-routes.xqm";

declare namespace fhir= "http://hl7.org/fhir";

declare function local:allEncsCancelledByPat(
      $es as element(fhir:Encounter)+
      ) as xs:boolean
{
    let $ss := distinct-values($es/fhir:status/@value)
    let $scs := distinct-values(for $e in $es
                return 
                    if ($e/fhir:statusHistory//fhir:code/@value=('noshow','cancelled-pat'))
                    then 'true'
                    else 'false')
    return
        count($ss)=1 and $ss='cancelled' and count($scs)=1 and $scs='true'
};

declare function local:updateGoal(
      $id as xs:string
    , $glcs as xs:string
    , $gas  as xs:string
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
    let $snam  := $eoc/fhir:patient/fhir:display/@value/string()
    let $start0 := substring($eoc/fhir:period/fhir:start/@value,1,10)
    let $start := if ($start0="") then current-dateTime() else $start0
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
                and ($es and local:allEncsCancelledByPat($es)))
            then 'finished'
            else 'order'
(:~
 :  patienten, die eine Anforderung und
 :  Termin bekommen haben, aber den nicht wahrgenommen oder canceln haben lassen
 :  können auf 'finished'/'Abbruch o.w.T.' gesetzt werden, die EoC auf finished 
 :) 
        else if ($glcs='accepted')
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
        case 'infos' return ""
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
        if ($lcs!=$glcs or $as!=$gas)
        then
            let $res := r-goal:updateTwoStatus($id,'kikl-spzn','u-admin','admin',$lcs,$as,$sd)
            return
                if ($res='error')
                then 
                    let $lll := util:log-app("ERROR", "apps.nabu",<updated pid="{$pid}" gid="{$id}" name="{$snam}" status="error" info="r-goal"/>)
                    return 'error'
                else if ($rstatus=('cancelled','finished'))
                then 'finished'
                else ()
                    
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
    let $sref := $g/fhir:subject/fhir:reference/@value/string()
    let $sdis := $g/fhir:subject/fhir:display/@value/string()
    let $lll := util:log-app("TRACE","apps.nabu",$sdis)
    let $gid := $g/fhir:id/@value/string()
    let $glcs := $g/fhir:lifecycleStatus/@value/string()
    let $gas  := $g/fhir:achievementStatus/fhir:coding[fhir:system/@value="http://hl7.org/fhir/ValueSet/goal-achievement"]/fhir:code/@value/string()
    let $eoc  := $eocs/../fhir:EpisodeOfCare[fhir:patient[fhir:reference/@value=$sref]]
    let $os   := $ocs/../fhir:Order[fhir:subject/fhir:reference[@value=$sref]]
    let $es   := $ecs/../fhir:Encounter[fhir:subject[fhir:reference/@value=$sref]]
    let $eoca  : = $eoc/../fhir:EpisodeOfCare[fhir:status[@value=('proposed','planned','active','waitlist','on-hold')]]
    let $eocc  : = $eoc/../fhir:EpisodeOfCare[fhir:status[@value=('cancelled','finished')]]
    return
        if (count($eoca)=1 or $eocc)
        then if (local:updateGoal($gid,$glcs,$gas,$sref,$sdis,$eoca,$eocc,$os,$es,$today)='finished')
            then (: set EoC finished, if Goal cancelled :)
                if (count($eoca)=1)
                then r-eoc:updateStatus((), $eoca/fhir:id/@value/string(),'kikl-spzn','u-admin','admin','finished')            
                else ()
            else ()
        else if (count($eoca)>1)
        then
            <updated pid="{$sref}" gid="{$gid}" name="{$sdis}" status="error" info="with dup eoc[active]"/>
        else
            <updated pid="{$sref}" gid="{$gid}" name="{$sdis}" status="error" info="no eoc[active]"/>
return
<registration-active all="{count($gs)}">
    (:
    <upds n="{count($upds)}">
        <achieved>{count($upds[@status='achieved'])}</achieved>
        <planned>{count($upds[@status='planned'])}</planned>
        <order>{count($upds[@status='order'])}</order>
        <infos>{count($upds[@status='infos'])}</infos>
        <cancelled>{count($upds[@status=('cancelled','finished')])}</cancelled>
    </upds>
    :)
    <error>
    { $upds[@status='error'] }
    </error>
</registration-active>