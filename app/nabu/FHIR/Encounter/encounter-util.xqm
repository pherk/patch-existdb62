xquery version "3.1";
(: 
 : Encounter collection utils
 : 
 : Encounters are distributed in 
 :        subdirs per year (2004-2022)
 :   plus planned (status=('planned','tentative))
 :   plus invalid (invalid date)
 : 
 : @since 0.9
 : @version 0.9.0
 : @author Peter Herkenrath (Copyright 2018)
 : 
 :)

module namespace encutil = "http://enahar.org/exist/apps/nabu/encounter-util";

declare variable $encutil:base    := '/db/apps/nabuEncounter/data';
declare variable $encutil:planned := '/db/apps/nabuEncounter/data/planned';

(: 
 : select (sub-) collections for efficiency
 : 
 : TODO comparing $status order dependant
 :)
declare function encutil:collections(
      $status as xs:string*
    , $tmin as xs:string
    , $tmax as xs:string
    , $base as xs:string
    ) as xs:string*
{
    let $planned := ('planned','tentative')
    let $hasplanned := if ($status=$planned)
            then concat($base,'/planned')
            else ()
    let $onlyplanned :=
            every $s in $status
            satisfies
                $s=$planned
    let $openrange := $tmin='' and $tmax=''
    let $years := if ($onlyplanned)
        then ()
        else if ($openrange)
        then $base
        else
            let $ymin := if ($tmin!='')
                then let $y := xs:integer(substring($tmin,1,4))
                    return max(($y,2004))
                else 2004
            let $ymax := if ($tmax!='')
                then let $y := xs:integer(substring($tmax,1,4))
                    return min(($y,2021))
                else 2021
            let $inc := 0
            for $y in ($ymin to ($ymax+$inc))
            return
                concat($base,'/',$y)
    let $lll := util:log-app('TRACE','apps.nabu',string-join(($status,$tmin,$tmax,$onlyplanned,$openrange,$hasplanned,$years),':'))
    return
        ($hasplanned,$years)
};