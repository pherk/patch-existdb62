xquery version "3.0";

(: 
 : functions for analyzing order shopping cart
 :)
module namespace cart = "http://enahar.org/exist/apps/enahar/cart";
import module namespace math = "http://exist-db.org/xquery/math";
import module namespace date   = "http://enahar.org/exist/apps/enahar/date"   at "../modules/date.xqm";
declare namespace fhir= "http://hl7.org/fhir";

declare variable $cart:otest :=
    <Order xmlns="http://hl7.org/fhir" xml:id="o-3831da2e-8578-41e3-9a92-2a70b3fb62b1">
        <id value="o-3831da2e-8578-41e3-9a92-2a70b3fb62b1"/>
        <meta>
            <versionID value="0"/>
        </meta>
        <lastModifiedBy>
            <reference value="metis/practitioners/u-admin"/>
            <display value="importBot"/>
        </lastModifiedBy>
        <lastModified value="2015-05-24T12:07:14.328+02:00"/>
        <when>
            <coding>
                <system value="#order-when"/>
                <code value=""/>
                <display value="normal"/>
            </coding>
            <text value="normal"/>
            <schedule>
                <event value="2016-06-13T08:00:00"/>
            </schedule>
        </when>
        <identifier/>
        <date value="2016-03-19T00:00:00"/>
        <subject>
            <reference value="p-21693"/>
            <display value="Graca, Darren Miguel *2009-03-14"/>
        </subject>
        <source>
            <reference value="metis/practitioners/u-admin"/>
            <display value="ImportBot"/>
        </source>
        <target>
            <role value="spz-ateam"/>
            <reference value=""/>
            <display value=""/>
        </target>
        <reason>
            <coding>
                <system value="#encounter-reason"/>
                <code value="appointment"/>
                <display value="Ambulanter Besuch"/>
            </coding>
            <text value="Ambulanter Besuch"/>
        </reason>
        <authority>
            <reference value="metis/organizations/kikl-spz"/>
            <display value="SPZ Kinderklinik"/>
        </authority>
        <detail id="111">
            <process value="false"/>
            <info value=" nur Dienstags WV meta"/>
            <actor>
                <role value="spz-arzt"/>
                <reference value="metis/practitioners/u-pmh"/>
                <display value="Herkenrath, Peter"/>
                <required value="true"/>
            </actor>
            <schedule>
                <reference value="enahar/schedules/amb-spz-arzt"/>
                <display value="Ambulanz"/>
            </schedule>
            <spec>
                <combination value="11"/>
                <interdisciplinary value="false"/>
                <begin value="3m"/>
                <daytime value="any"/>
                <dow value="any"/>
                <duration value="30"/>
            </spec>
            <proposal>
                <start value=""/>
                <end value=""/>
            </proposal>
            <reorder value="false"/>
            <status value="active"/>
        </detail>
        <detail id="1">
            <process value="true"/>
            <info value=" nur Dienstags WV meta"/>
            <actor>
                <role value="spz-arzt"/>
                <reference value="metis/practitioners/u-pmh"/>
                <display value="Herkenrath, Peter"/>
                <required value="true"/>
            </actor>
            <schedule>
                <reference value="enahar/schedules/amb-spz-arzt"/>
                <display value="Ambulanz"/>
            </schedule>
            <spec>
                <combination value="2"/>
                <interdisciplinary value="true"/>
                <begin value="3m"/>
                <daytime value="any"/>
                <dow value="any"/>
                <duration value="30"/>
            </spec>
            <proposal>
                <start value=""/>
                <end value=""/>
            </proposal>
            <reorder value="false"/>
            <status value="active"/>
        </detail>
        <detail id="2">
            <process value="true"/>
            <info value=" nur Dienstags WV meta"/>
            <actor>
                <role value="spz-eeg"/>
                <reference value="metis/practitioners/u-eeg"/>
                <display value="EEG"/>
                <required value="true"/>
            </actor>
            <schedule>
                <reference value="enahar/schedules/fun-spz-eeg"/>
                <display value="EEG"/>
            </schedule>
            <spec>
                <combination value="1"/>
                <interdisciplinary value="true"/>
                <begin value="3m"/>
                <daytime value="any"/>
                <dow value="any"/>
                <duration value="90"/>
            </spec>
            <proposal>
                <start value=""/>
                <end value=""/>
            </proposal>
            <reorder value="false"/>
            <status value="active"/>
        </detail>
        <detail id="3">
            <process value="true"/>
            <info value=" nur Dienstags WV meta"/>
            <actor>
                <role value="spz-arzt"/>
                <reference value="metis/practitioners/u-pmh"/>
                <display value="Herkenrath"/>
                <required value="true"/>
            </actor>
            <schedule>
                <reference value="enahar/schedules/amb-spz-arzt"/>
                <display value="SPZ Arzt"/>
            </schedule>
            <spec>
                <combination value="3"/>
                <interdisciplinary value="false"/>
                <begin value="6m"/>
                <daytime value="any"/>
                <dow value="any"/>
                <duration value="30"/>
            </spec>
            <proposal>
                <start value=""/>
                <end value=""/>
            </proposal>
            <reorder value="false"/>
            <status value="active"/>
        </detail>
        <status value="active"/>
    </Order>;
    
(:~
 : analyzeCart
 : analyzes the order specs of selected details (cart)
 : 
 : @param $order
 : 
 : @return <cart/>
 :)
declare function cart:analyze(
      $order as element(fhir:Order)
    , $mode as xs:string
    , $limit as xs:string
    ) as item()
{
    let $lll := util:log-app('TRACE','apps.eNahar', concat("cart: analyzing ... (", $mode, '-', $limit, ')'))
    return
        if (count($order/fhir:detail) = count(distinct-values($order/fhir:detail/@id)))
        then
            let $dsToProc:= $order/fhir:detail[fhir:process/@value/string()="true"][fhir:status[@value=('active','requested')]]
            let $rtp := cart:runtimePrognosis($dsToProc)
            return
                if ($rtp/error)
                then
                    <cart>
                        { $rtp/error }
                        { $rtp/hint }
                    </cart>
                else
                    let $sameday := $dsToProc[fhir:spec/fhir:interdisciplinary/@value='true']
                    let $other   := if (count($sameday)=1)
                        then ($sameday,$dsToProc[fhir:spec/fhir:interdisciplinary/@value='false'])
                        else $dsToProc[fhir:spec/fhir:interdisciplinary/@value='false']
                    let $today := xs:dateTime(concat(adjust-date-to-timezone(current-date(),()),'T00:00:00')) + xs:dayTimeDuration("P1D")
                    let $epoch := dateTime(xs:date(tokenize($order/fhir:date/@value,'T')[1]),xs:time("00:00:00"))
                    let $swdur := xs:dayTimeDuration('P1D') * xs:int($rtp/duration)
                    return
                        <cart>
                            <epoch>{$epoch}</epoch>
                            { $rtp }
                            { cart:sameDay($sameday,$swdur,$epoch,$today)  }
                            { cart:simple($other,$swdur,$epoch,$today) }
                            { <mode>{if ($mode='') then 'normal' else $mode}</mode> }
                        </cart>
        else
            <cart>
                <error>Detail-IDs nicht eindeutig</error>
                <hint>Bitte ein Detail löschen und neu anlegen</hint>
            </cart>
};

(:~
 : prognosis
 : checks rules, estimate runtime, return search params
 : 
 : @param $orders
 : 
 : @return <param/>
 :)
declare %private function cart:runtimePrognosis($details as element(fhir:detail)*) as item()
{
    let $lll := util:log-app('TRACE','apps.eNahar',"cart: runtime prognosis ...")
    return
    if (count($details) = 0)
    then
        <rtp>
            <error>kein Detail zur Bearbeitung selektiert</error>
        </rtp>
    else if (count($details) > 4)
    then
        <rtp>
            <error>mehr als 4 Details selektiert</error>
            <hint>Suchraum zu groß bzw. Suche dauert zu lang</hint>
        </rtp>
    else if (count($details)=1)
    then
        cart:one($details)
    else
        cart:morethanone($details)
};

declare %private function cart:one($detail as element(fhir:detail)) as item()
{
    if ($detail/fhir:actor/fhir:reference/@value ='')
    then if ($detail/fhir:schedule/fhir:reference/@value ='')
        then 
            <rtp>
                <critical/>
                <duration>7</duration>
            </rtp>
        else
            <rtp>
                <standard/>
                <duration>14</duration>
            </rtp>
    else if ($detail/fhir:schedule/fhir:reference/@value ='')
        then
            <rtp>
                <standard/>
                <duration>14</duration>
            </rtp>
        else
            <rtp>
                <good/>
                <duration>28</duration>
            </rtp>
};

declare %private function cart:morethanone($detail as element(fhir:detail)+) as item()
{
    if ($detail/fhir:schedule/fhir:reference/@value ='')
    then 
        <rtp>
            <error>Kalender nicht angegeben</error>
        </rtp>
    else if ($detail/fhir:actor/fhir:reference/@value =''  and $detail/fhir:actor/fhir:role/@value=('spz-arzt','spz-psych'))
        then 
            <rtp>
                <critical/>
                <duration>7</duration>
            </rtp>
        else
            <rtp>
                <standard/>
                <duration>14</duration>
            </rtp>
};

(:~
 : analyzeSameDay
 : analyzes order specs of appointments scheduled for the same day (aka KombiTermin)
 : at the moment only sequental or parallel appointments allowed
 : 
 : @param $sameday    details scheduled for the same day
 : 
 : @return <sameday/>
 :)
declare %private function cart:sameDay(
          $sameday as element(fhir:detail)*
        , $swdur
        , $epoch
        , $today
        ) as item()*
{
    if (count($sameday)>1)
    then
        let $mode :=
            if (count(distinct-values($sameday/fhir:spec/fhir:combination/@value))=1)
            then    <interdisciplinary/>
            else    <sequential/>
        let $sorted-ids :=
            for $sd in $sameday
            order by $sd/fhir:spec/fhir:combination/@value/string()
            return
                <id>{$sd/@id/string()}</id>
        let $period :=
            let $start := cart:clipDate(cart:calcNextDueDate($sameday, $epoch),$today)
            let $end   := $start + $swdur + xs:dayTimeDuration("PT20H")
            return
                <period>
                    <start>{$start}</start>
                    <end>{$end}</end>
                </period>
        return
            <sameday>
                { $mode }
                { $sorted-ids }
                { $period }    
            </sameday>
    else ()
};

(:~
 : other
 : analyzes order specs of appointments not scheduled for the same day (aka KombiTermin)
 : at the moment it simply enumerates ids 
 : 
 : @param $other    details
 : 
 : @return <other/>
 :)
declare %private function cart:simple(
          $other as element(fhir:detail)*
        , $swdur
        , $epoch
        , $today
        ) as element(simple)*
{
    if (count($other)>0)
    then 
        for $o in $other
        let $start := cart:clipDate(cart:calcNextDueDate($o, $epoch),$today)
        let $end   := $start + $swdur + xs:dayTimeDuration("PT20H")
        return
        <simple id="{$o/@id/string()}">
            <period>
                <start>{$start}</start>
                <end>{$end}</end>
            </period>
        </simple>
    else ()
};

(:~
 : precedes
 : preceding order detail, if any
 : 
 : @param $details
 : @return id
 :)
declare function cart:precedes($details as element(fhir:detail)*) as xs:string?
{
    $details[fhir:actor/fhir:role/@value=('spz-eeg','spz-epnlg')][1]/@id
};

declare %private function cart:clipDate($date as xs:dateTime, $epoch as xs:dateTime) as xs:dateTime
{
    if ($date>$epoch)
    then $date
    else $epoch
};

(:~
 : calcNextDueDate
 : take the nearest due date from list of details
 : tries to convert detail/spec/begin, default current-dateTime()
 :  
 : @param $details
 : 
 : @return xs:dateTime
 :)
declare %private function cart:calcNextDueDate($details as element(fhir:detail)*, $epoch as xs:dateTime) as xs:dateTime
{
    let $begins := distinct-values($details/fhir:spec/fhir:begin/@value)
    return
    try {
        let $due := for $d in $begins
        let $lll := util:log-app('TRACE','apps.eNahar',$d)
            return
                date:easyDateTime($d, $epoch)
        return
            if (count($due)>0)
            then min($due)
            else $epoch
    } catch * {
        $epoch
    }
};
