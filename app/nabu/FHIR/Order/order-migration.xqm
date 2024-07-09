xquery version "3.0";

module namespace ordermigr = "http://enahar.org/exist/apps/nabu/order-migration";

import module namespace careplan = "http://enahar.org/exist/apps/nabu/careplan" at "/db/apps/nabu/FHIR/CarePlan/careplan.xqm";

declare namespace fhir= "http://hl7.org/fhir";

(:~
 : adds props from Appointment 
 : v0.9
 :)
declare function ordermigr:update-0.9-5($order as element(fhir:Order))
{
        system:as-user('vdba', 'kikl823!',
            (
              update insert 
                <serviceCategory xmlns="http://hl7.org/fhir">
                    <coding>
                        <system value="http://hl7.org/fhir/service-category"/>
                        <code value="34"/>
                        <display value="KiKl-SPZn"/>
                    </coding>
                    <text value="KiKl-SPZn"/>
                </serviceCategory>
                following $order/fhir:basedOn
            , update insert 
                <serviceType xmlns="http://hl7.org/fhir">
                    <coding>
                        <system value="http://hl7.org/fhir/service-type"/>
                        <code value="202"/>
                        <display value="Neuropädiatrie"/>
                    </coding>
                    <text value="Neuropädiatrie"/>            
                </serviceType>
                following $order/fhir:basedOn
            , update insert 
                <specialty xmlns="http://hl7.org/fhir">
                    <coding>
                        <system value="http://snomed.info/sct"/>
                        <code value="309334002"/>
                        <display value="Neuropädiater"/>
                    </coding>
                    <text value="Neuropädiater"/>            
                </specialty>
                following $order/fhir:basedOn
            , update insert 
                <appointmentType xmlns="http://hl7.org/fhir">
                    <coding>
                        <system value="http://hl7.org/fhir/v2/0276"/>
                        <code value="ROUTINE"/>
                        <display value="Routine"/>
                    </coding>
                    <text value="Routine"/>
                </appointmentType>
                following $order/fhir:basedOn
            ))
};

(:~
 : migrates Order/detail to new actor
 :)
declare function ordermigr:update-actor(
      $order as element(fhir:Order)
    , $arole as xs:string
    , $aid as xs:string
    , $narole as xs:string
    , $naid as xs:string*
    , $nadisp as xs:string*
    )
{
    let $aref  := concat('metis/practitioners/',$aid)
    let $naref := concat('metis/practitioners/',$naid)
    return
        (: 
        $order/fhir:detail[fhir:status[@value="active"]][fhir:actor[fhir:role[matches(@value,$arole)]][fhir:reference[@value=$aref]]]
        :)
    
        system:as-user('vdba', 'kikl823!',
            (
                for $d in $order/fhir:detail[fhir:status[@value="active"]][fhir:actor[fhir:role[matches(@value,$arole)]][fhir:reference[@value=$aref]]]
                return
                    (
                      update value $d/fhir:actor/fhir:role/@value with $narole
                    , if ($naid)
                      then
                        (update value $d/fhir:actor/fhir:reference/@value with $naref
                        , update value $d/fhir:actor/fhir:display/@value with $nadisp
                        )
                      else
                        (update value $d/fhir:actor/fhir:reference/@value with ""
                        , update value $d/fhir:actor/fhir:display/@value with ""
                        )
                    )
            ))
};

(:~
 : migrates pre Nabu 0.8 to v3.0.1 
 : pre 0.8
 :)
declare function ordermigr:update-0.8($order as element(fhir:Order))
{
        system:as-user('vdba', 'kikl823!',
            (
              update replace $order/fhir:meta/fhir:versionID with
                <versionId xmlns="http://hl7.org/fhir" value="{$order/fhir:meta/fhir:versionID/@value/string()}"/>
            , update replace $order/fhir:extension[@url='#order-status'] with
            <extension xmlns="http://hl7.org/fhir" url="#order-status">
                <valueCodeableConcept>
                    <coding>
                        <system value="#order-status"/>
                        <code value="{$order/fhir:extension[@url='#order-status']//fhir:code/@value/string()}"/>
                        <display value="{$order/fhir:extension[@url='#order-status']//fhir:display/@value/string()}"/>
                    </coding>
                    <text value="{$order/fhir:extension[@url='#order-status']//fhir:text/@value/string()}"/>
                </valueCodeableConcept>
            </extension>
            ))
};
(:~
 : migrates Order 0.8 to 0.8-26
 : status value-set change for compatiblity with Request FHIR 3.0.1 
 : insert status in details analog to the status in Appointment 
 : and update value from Encounter
 : TODO: eliminate extension e.g. analog to RequestGroup
 :)
declare function ordermigr:update-0.8-26($order as element(fhir:Order), $eps as element(fhir:Encounter)*)
{
    let $new-status := switch($order/fhir:extension[@url='#order-status']//fhir:code/@value/string())
        case 'new'       return 'draft'
        case 'assigned'  return 'requested'
        case 'accepted'  return 'accepted'
        case 'resolved'  return 'completed'
        case 'closed'    return 'completed'
        case 'cancelled' return 'cancelled'
        default          return 'unknown'
    return
        system:as-user('vdba', 'kikl823!',
            (
              update insert  <status xmlns="http://hl7.org/fhir" value="{$new-status}"/> following 
                   $order/fhir:extension[@url='#order-status']
            , update delete $order/fhir:extension[@url='#order-status']
            ,
              for $d in $order/fhir:detail
              let $dstatus := switch($d/fhir:proposal/fhir:acq/@value)
                case 'closed' return 'completed'
                default return 'requested'
              return
                update insert <status xmlns="http://hl7.org/fhir" value="{$dstatus}"/> following $d/fhir:proposal
            ,
              for $e in $eps
              let $estatus := switch($e/fhir:status/@value)
                case 'planned' return 'accepted'
                case 'tentative' return 'accepted'
                case 'finished' return 'completed'
                case 'cancelled' return'cancelled'
                default return 'unknown'
              let $d := $order/fhir:detail[@id=substring-after(tokenize($e/fhir:appointment/fhir:reference/@value,'\?')[2],'detail=')]
              return
                update value $d/fhir:status/@value with $estatus
            ))
};

declare function ordermigr:update-0.8-26-1($order as element(fhir:Order))
{
        system:as-user('vdba', 'kikl823!',
            (
              for $d in $order/fhir:detail
              let $dstatus := switch($d/fhir:proposal/fhir:acq/@value)
                case 'closed' return 'completed'
                default return 'proposed'
              return
                update insert <status xmlns="http://hl7.org/fhir" value="{$dstatus}"/> following $d/fhir:proposal
            ))
};

declare function ordermigr:update-0.8-26-2($order as element(fhir:Order), $eps as element(fhir:Encounter)*)
{
        system:as-user('vdba', 'kikl823!',
            (
              for $e in $eps
              let $estatus := switch($e/fhir:status/@value)
                case 'planned' return 'accepted'
                case 'tentative' return 'accepted'
                case 'finished' return 'completed'
                case 'cancelled' return'cancelled'
                default return 'unknown'
              let $d := $order/fhir:detail[@id=substring-after(tokenize($e/fhir:appointment/fhir:reference/@value,'\?')[2],'detail=')]
              return
                update value $d/fhir:status/@value with $estatus
            ))
};
declare function ordermigr:update-0.8-26-3($order as element(fhir:Order))
{
        let $status := $order/fhir:extension//fhir:code/@value/string()
        return
        system:as-user('vdba', 'kikl823!',
            (
              update delete $order/fhir:extension
            , update insert  <status xmlns="http://hl7.org/fhir" value="{$status}"/> following 
                   $order/fhir:detail
            ))
};


declare function ordermigr:update-0.8-26-4($realm, $author, $order as element(fhir:Order))
{
    let $lll := util:log-app('TRACE','apps.nabu',$order)
    let $cp  := careplan:getCP($order/fhir:subject, $realm, $author, 'Request Import', $order)
    let $lll := util:log-app('TRACE','apps.nabu',$cp)
    return
        if ($order/fhir:basedOn)
        then
            system:as-user('vdba', 'kikl823!',
                (
                  update replace $order/fhir:basedOn/fhir:reference/@value with concat('nabu/careplans/',$cp/fhir:id/@value)
                , update replace $order/fhir:basedOn/fhir:display/@value with $cp/fhir:title/@value/string()
                , if ($order/fhir:description)
                    then ()
                    else update insert <description xmlns="http://hl7.org/fhir" value="{$order/fhir:reason/fhir:text/@value/string()}"/>
                            following $order/fhir:status
                ))
        else
            system:as-user('vdba', 'kikl823!',
                (
                  update insert 
                        <basedOn xmlns="http://hl7.org/fhir">
                            <reference value="{concat('nabu/careplans/',$cp/fhir:id/@value)}"/>
                            <display value="{$cp/fhir:title/@value/string()}"/>                
                        </basedOn>
                     following $order/fhir:meta
                , if ($order/fhir:description)
                    then ()
                    else update insert <description xmlns="http://hl7.org/fhir" value="{$order/fhir:reason/fhir:text/@value/string()}"/>
                            following $order/fhir:status
                ))
};
