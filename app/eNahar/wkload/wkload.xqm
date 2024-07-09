xquery version "3.1";

module namespace wkload    = "http://enahar.org/exist/apps/enahar/wkload";

import module namespace xqtime = "http://enahar.org/lib/xqtime";

declare namespace fhir = "http://hl7.org/fhir";

declare variable $wkload:encounters := collection('/db/apps/nabuEncounter/data/planned');

declare function wkload:workloadPerDayXML(
          $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $arefs as xs:string+
        , $group as xs:string*
        , $schedule as xs:string*
        , $tmin as xs:dateTime
        , $tmax as xs:dateTime
        , $status as xs:string*
        ) as element(workload)
{
        let $matched00 := $wkload:encounters/fhir:Encounter[fhir:participant/fhir:individual[fhir:reference/@value = $arefs]]
        let $matched0 := $matched00/../fhir:Encounter[fhir:period/fhir:start[@value>=$tmin]][fhir:period/fhir:end[@value<=$tmax]]
        let $matched1 := $matched0/../fhir:Encounter[fhir:status[@value=$status]]
        let $matched : = if ($schedule!='')
            then $matched1[fhir:type/fhir:coding[fhir:system/@value="#encounter-type"]/fhir:code/@value = $schedule]
            else $matched1

        let $nofd  := xs:integer(floor(($tmax - $tmin) div xs:dayTimeDuration('P1D')))
        let $lll := util:log-app('TRACE', 'apps.eNahar', concat('Workload for ', count($arefs), ' individuals: ', count($matched),' - ',$tmin,':',$tmax))
return
<workload>
    {
        for $d in (0 to $nofd)
        let $start := $tmin + xs:dayTimeDuration('P1D') * ($d)
        let $end   := $tmin + xs:dayTimeDuration('P1D') * ($d+1)
        let $encs := $matched/../fhir:Encounter[fhir:period/fhir:start[@value>=$start]][fhir:period/fhir:end[@value<=$end]]
        return
            <day>
                <date value="{tokenize($start,'T')[1]}"/>
                {
                    for $s in distinct-values($encs/fhir:type/fhir:coding[fhir:system[@value="#encounter-type"]]/fhir:code/@value)
                    let $inSched := $encs[fhir:type/fhir:coding[fhir:system[@value="#encounter-type"]]/fhir:code/@value = $s]
                    let $nofE    := count($inSched)
                    let $dur     := for $i in $inSched
                                return xs:dateTime($i/fhir:period/fhir:end/@value/string()) - xs:dateTime($i/fhir:period/fhir:start/@value/string())
                    let $startMin:= (: xxpath:lowest(function($a){xs:dateTime($a/fhir:period/fhir:start/@value/string())},$inSched) :)
                            min($inSched/fhir:period/fhir:start/@value/string())
                    let $endMax  := (: xxpath:highest(function($a){xs:dateTime($a/fhir:period/fhir:end/@value/string())},$inSched) :)
                            max($inSched/fhir:period/fhir:end/@value/string())
                    let $tot     := sum($dur) div xs:dayTimeDuration('PT1M')
                    let $real    := (xs:dateTime($endMax) - xs:dateTime($startMin)) div xs:dayTimeDuration('PT1M')
                    (:~
                     : min max of schedule not yet considered in benchmarks
                     : bookedQuotient actually assumes one(!) compact workblock per day;
                     : TODO PH
                     :)
                    order by $s
                    return  <schedule name="{$s}">
                                <nOfEvents value="{$nofE}"/>
                                <range start="{$startMin}" end="{$endMax}"/>
                                <bookedWorkload value="{$tot}"/>
                                <bookedDuration value="{$real}"/>
                                <bookedQuotient value="{$tot div $real}"/>
                                {
                                for $a in distinct-values($encs/fhir:participant/fhir:individual/fhir:reference/@value/string())
                                let $encsWithIndividual := $inSched/../fhir:Encounter[fhir:participant/fhir:individual[fhir:reference/@value=$a]]
                                return 
                                    if (count($encsWithIndividual)>0)
                                    then
                                        let $events := 
                                                for $e in $encsWithIndividual
                                                order by $e/fhir:period/fhir:start/@value/string()
                                                return
                                                    xqtime:new($e/fhir:period/fhir:start/@value, $e/fhir:period/fhir:end/@value, $e/fhir:id/@value)
                                        let $aNofE   := count($encsWithIndividual)
                                        let $aDur    := for $i in $encsWithIndividual
                                                return xs:dateTime($i/fhir:period/fhir:end/@value/string()) - xs:dateTime($i/fhir:period/fhir:start/@value/string())
                                        let $aStartMin:= min($encsWithIndividual/fhir:period/fhir:start/@value/string())
                                        let $aEndMax := max($encsWithIndividual/fhir:period/fhir:end/@value/string())
                                        let $aTot    := sum($aDur) div xs:dayTimeDuration('PT1M')
                                        let $aReal   := (xs:dateTime($aEndMax) - xs:dateTime($aStartMin)) div xs:dayTimeDuration('PT1M')
                                        return
                                            <actor ref="{$a}" group="{$group}">
                                                <nOfEvents value="{$aNofE}"/>
                                                <range start="{$aStartMin}" end="{$aEndMax}"/>
                                                <bookedWorkload value="{$aTot}"/>
                                                <bookedDuration value="{$aReal}"/>
                                                <bookedQuotient value="{$aTot div $aReal}"/>
                                                { $events }
                                            </actor>
                                    else ()
                                }
                            </schedule>
                }
            </day>
    }
</workload>
};