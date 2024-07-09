xquery version "3.0";
module namespace rec = "http://enahar.org/exist/apps/golem/context";

import module namespace recnd      = "http://enahar.org/exist/apps/golem/conditions"     at "/db/apps/golem/context/conditions.xqm";

import module namespace r-patient  = "http://enahar.org/exist/restxq/nabu/patients"      at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";
import module namespace r-eoc      = "http://enahar.org/exist/restxq/nabu/eocs"          at "/db/apps/nabu/FHIR/EpisodeOfCare/episodeofcare-routes.xqm";
import module namespace r-careteam = "http://enahar.org/exist/restxq/nabu/careteams"     at "/db/apps/nabu/FHIR/CareTeam/careteam-routes.xqm";
import module namespace r-qr       = "http://enahar.org/exist/restxq/nabu/questionnaireresponses" at "/db/apps/nabu/FHIR/QuestionnaireResponse/questresponse-routes.xqm";

declare namespace golem = "http://enahar.org/ns/1.0/golem";
declare namespace  fhir = "http://hl7.org/fhir";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";

declare variable $rec:pd-neons-id     := "neo-nachsorge-order-set";
declare variable $rec:q-neons-id      := "q-neons-v2018-01-08";
declare variable $rec:q-bayleyIII-id  := "q-bayleyIII-v2017-08-08";


declare function rec:checkCondition(
        $condition as element(fhir:condition)?
      , $context as element(golem:context)
    ) as xs:boolean
{
    recnd:checkCondition($condition, $context)
};

declare function rec:type(
    $cid as xs:string
    ) as xs:string
{
    if (starts-with($cid,'nabu/patients/'))
    then 'patient'
    else if (starts-with($cid,'nabu/careplans/'))
    then 'careplan'
    else 'patient'
};

declare function rec:getPatientContext(
          $realm as xs:string
        , $loguid as xs:string
        , $lognam as xs:string
        , $cid as xs:string
    ) as element(golem:patient)
{
    let $type  := rec:type($cid)
    let $pat := switch($type)
        case 'patient' return 
                let $pid := if(starts-with($cid,'nabu/patients/'))
                            then substring-after($cid,'nabu/patients/')
                            else $cid
                return
                    r-patient:patientByIDXML(
                                      $pid
                                    , $realm
                                    , $loguid
                                    , $lognam)
        case 'careplan' return ()
        default return ()
    let $pid := $pat/fhir:id/@value/string()
    return
        if ($pid)
        then
            <patient xmlns="http://enahar.org/ns/1.0/golem">
                <type value="patient"/>
                <subject xmlns="http://hl7.org/fhir">
                    <reference value="{concat('nabu/patients/',$pid)}"/>
                    <display value="{if ($pid) then r-patient:formatFHIRName($pat) else ''}"/>
                </subject>
                { $pat }
            </patient>
        else
            <patient xmlns="http://enahar.org/ns/1.0/golem">
                <type value="patient"/>
                <error>{concat('Patient not found: ', $cid)}</error> 
            </patient>
            
};

declare function rec:getAdditionalPatientContext(
          $realm as xs:string
        , $loguid as xs:string
        , $lognam as xs:string
        , $pid as xs:string
        , $pdid as xs:string
    ) as element(golem:other)
{
    let $other := if ($pdid = $rec:pd-neons-id)
        then (: qr for neons :)
                let $res := r-qr:questionnaireResponsesXML(
                                      $realm
                                    , $loguid
                                    , $lognam
                                    , $rec:q-neons-id
                                    , $pid
                                    , ("active","completed","amended")
                                    , "full"
                                    )
                let $pca := $res/fhir:QuestionnaireResponse//fhir:item[fhir:linkId[@value="pca-weeks"]]/fhir:answer/fhir:valueInteger
                let $et  := $res/fhir:QuestionnaireResponse//fhir:item[fhir:linkId[@value="et"]]/fhir:answer/fhir:valueDate
                return
                    (
                        if ($pca/@value!="")
                        then 
                            <pca xmlns="http://enahar.org/ns/1.0/golem" value="{$pca/@value/string()}"/>
                        else
                            <pca xmlns="http://enahar.org/ns/1.0/golem" value=""/>
                    ,   if ($et/@value!="")
                        then 
                            <et xmlns="http://enahar.org/ns/1.0/golem" value="{$et/@value/string()}"/>
                        else
                            <et xmlns="http://enahar.org/ns/1.0/golem" value=""/>
                    )
        else
            (
              <pca xmlns="http://enahar.org/ns/1.0/golem" value="40"/>
            , <et xmlns="http://enahar.org/ns/1.0/golem" value=""/>
            )
    let $eoca := r-eoc:eocsXML(
                      $realm
                    , $loguid
                    , $lognam
                    , (), ()
                    , $pid
                    , ("active","planned")
                    , "full"
                )/fhir:EpisodeOfCare

    let $cta  := r-careteam:careteamsXML(
                      $realm
                    , $loguid
                    , $lognam
                    , $pid
                    , ("active")
                    , "full"
                )/fhir:CareTeam
    return
        <other xmlns="http://enahar.org/ns/1.0/golem">
            { $other }
            { $eoca }
            { $cta }
        </other>
};

declare function rec:age(
          $pcntxt 
        , $other
    ) as xs:string
{
    let $now := current-date()
    let $bd  := $pcntxt/fhir:Patient/fhir:birthDate/@value/string()
    let $pca := xs:int($other/golem:pca/@value)
    let $age := ($now - xs:date($bd)) div xs:dayTimeDuration('P1D')
    let $cage:=
        if ($pca < 37 and $age < 730)
        then $age + $pca * 7 - 280
        else $age
    return
        xs:string($cage)
};

declare function rec:evalWithPatient(
      $pd as element(fhir:PlanDefinition)
    , $pat as element(golem:patient)?
    , $other as element(golem:other) 
    , $source as element(fhir:source)
    , $basedOn as element(fhir:basedOn)?
    ) as element(golem:context)
{
    let $title := $pd/fhir:title/@value/string()
    let $lll   := util:log-app('TRACE','apps.nabu',$title)
    let $uces  := for $uc in $pd/fhir:useContext
        return
            <uce  xmlns="http://enahar.org/ns/1.0/golem"
               code="{$uc/fhir:code/fhir:code/@value/string()}"
               display="{$uc/fhir:valueCodeableConcept/fhir:coding/fhir:display/@value/string()}"/>
    let $et := rec:et($other/golem:et/@value, $pat/fhir:Patient/fhir:birthDate/@value, $other/golem:pca/@value)
    let $context :=
        <context xmlns="http://enahar.org/ns/1.0/golem">
            <ok/>
            <type value="patient"/>
            <params xmlns="http://hl7.org/fhir">
                    { $pd/fhir:title }
                    { $pd/fhir:description }
                    {
                        if ($basedOn)
                        then
                            $basedOn
                        else
                            <basedOn xmlns="http://hl7.org/fhir">
                                <reference value="{$pd/fhir:id/@value/string()}"/>
                                <display value="{$title}"/>
                            </basedOn>
                    }
                    { $source }
                    { $pat/fhir:subject }
            </params>
            <other>
                {$pat/fhir:Patient/fhir:birthDate}
                <et value="{$et}"/>
                <correctedAge value="{rec:correctedAge($et,$pat/fhir:Patient/fhir:birthDate/@value, $other/golem:pca/@value)}"/>
            </other>
            { $uces }
        </context>
    let $lll   := util:log-app('TRACE','apps.nabu',$context)
    let $rootCondition := $pd/fhir:action/fhir:condition[fhir:language[@value='application/xquery']]
    let $lll   := util:log-app('TRACE','apps.nabu',$rootCondition)
    return
        if (recnd:checkCondition($rootCondition,$context))
        then
            $context
        else    
            <context xmlns="http://enahar.org/ns/1.0/golem">
                <error>
                    <title  xmlns="http://hl7.org/fhir" value="error: Plan not applicable"/>
                    { $rootCondition/fhir:description }
                </error>
                <type value="patient"/>
            </context>
};

declare function rec:et(
      $et as xs:string
    , $bd as xs:string
    , $pca as xs:string
    ) as xs:date
{
    if ($et!='')
    then
        xs:date($et)
    else if ($pca!='')
    then
        xs:date($bd)  + (40 - xs:int($pca)) * xs:dayTimeDuration('P7D')
    else
        xs:date($bd)
};

declare function rec:correctedAge(
      $et as xs:string
    , $bd as xs:string
    , $pca as xs:string
    ) as xs:dayTimeDuration
{
    let $now := current-date()
    return
        if ($et!='')
        then
            ($now - xs:date($et))
        else if ($pca!='')
        then
            ($now - xs:date($bd)) - (40 - xs:int($pca)) * xs:dayTimeDuration("P7D")
        else
            ($now - xs:date($bd))
};