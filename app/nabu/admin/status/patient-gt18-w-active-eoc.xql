xquery version "3.0";

declare namespace fhir= "http://hl7.org/fhir";
(:~
 : list and update Patient getting over 18 in year
 :)
let $year := 2024


let $ymin := xs:string($year - 18)
let $ymax := xs:string($year - 17)
let $esc := collection('/db/apps/nabuCom/data/EpisodeOfCares')
let $ps := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:birthDate[@value<$ymax]][fhir:birthDate[@value>=$ymin]]
let $pcnt := count($ps)
let $ll := util:log-app("TRACE","apps.nabu",$pcnt)
let $pse := for $p in $ps
    let $ea := $esc/fhir:EpisodeOfCare[fhir:subject[fhir:reference/@value=concat('nabu/patients/',$p/fhir:id/@value)]][fhir:status/@value='active']
    let $ll := util:log-app("TRACE","apps.nabu",count($ea))
    return
    if (count($ea)>0)
    then
        let $bd := $p/fhir:birthDate/@value/string()
        let $MIType := $p/fhir:extension[@url='#patient-medical-insurance']//fhir:code/@value/string()
        let $MIName := $p/fhir:extension[@url='#patient-medical-insurance']//fhir:display/@value/string()
        return
        if ($p/fhir:extension[@url='#patient-over-18'])
        then 
            let $status := $p/fhir:extension[@url='#patient-over-18']/fhir:valueCodeableConcept/fhir:coding/fhir:code/@value/string()
            return
            <p text="{$p/fhir:text/*:div/string()}" status="{$status}" vt="{$MIType}" vn="{$MIName}" id="{$p/fhir:id/@value/string()}">Has Extension</p>

        else 
            let $upd := system:as-user('admin', 'kikl968',
                (
                  update insert
                    <extension xmlns="http://hl7.org/fhir" url="#patient-over-18-limit">
                        <valueDate value=""/>
                    </extension>
                    following $p/fhir:text
                ,
                  update insert 
                    <extension xmlns="http://hl7.org/fhir" url="#patient-over-18">
                        <valueCodeableConcept>
                            <coding>
                                <code value="unknown"/>
                                <display value="keine Info"/>
                            </coding>
                        </valueCodeableConcept>
                    </extension>
                    following $p/fhir:text
                )
            )
            return
            <p text="{$p/fhir:text/*:div/string()}" status="unknown" vt="{$MIType}" vn="{$MIName}" id="{$p/fhir:id/@value/string()}">Neu in {$year}</p>
    else ()
let $data :=
    <patients-over-18 cnt="{count($pse)}">
    { for $p in $pse
      order by $p/@text/string()
      return
          $p
    }</patients-over-18>
return
    system:as-user('admin', 'kikl968',xmldb:store("/db/apps/nabu/statistics/evals","p18-" || $year || ".xml",$data))
    