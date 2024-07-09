
xquery version "3.0";


import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";

import module namespace r-appointment  = "http://enahar.org/exist/restxq/nabu/appointments"  at "../FHIR/Appointment/appointment-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "/db/apps/metis/Practitioner/practitioner-routes.xqm";
import module namespace r-organization = "http://enahar.org/exist/restxq/metis/organizations"  at "/db/apps/metis//Organization/organization-routes.xqm";
import module namespace r-patient      = "http://enahar.org/exist/restxq/nabu/patients"  at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";
import module namespace r-encounter    = "http://enahar.org/exist/restxq/nabu/encounters"  at "/db/apps/nabu/FHIR/Encounter/encounter-routes.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare namespace ss     = "urn:schemas-microsoft-com:office:spreadsheet";


declare function local:quartal($date as xs:string) as node()
{
    let $y := tokenize($date,'-')[1]
    let $m := xs:integer(tokenize($date,'-')[2])
    let $quartal := 
        if ($m>0 and $m<4)       then <quartal name="Q1" tmin="{$y || '-01-01T00:00:00'}" tmax="{$y || '-03-31T23:59:59'}"/>
        else if ($m>3 and $m<7)  then <quartal name="Q2" tmin="{$y || '-04-01T00:00:00'}" tmax="{$y || '-06-30T23:59:59'}"/>
        else if ($m>6 and $m<10) then <quartal name="Q3" tmin="{$y || '-07-01T00:00:00'}" tmax="{$y || '-09-30T23:59:59'}"/>
        else if ($m>9 and $m<13) then <quartal name="Q4" tmin="{$y || '-10-01T00:00:00'}" tmax="{$y || '-12-31T23:59:59'}"/>
        else <quartal name="4Q" tmin="2014-01-01T00:00:00" tmax="2014-12-31T23:59:59"/>
    return
        $quartal
};

(: check import of events 
let $worker  := collection($config:nabu-imports)/dataroot/Abk_Erbringer
let $events  := collection($config:nabu-imports)/dataroot/Termine
let $db-e  := collection($config:nabu-encounters)
let $db-a  := collection($config:nabu-appointments)
let $import-patients :=  collection($config:nabu-imports)/dataroot/Patienten
let $import-wl :=  collection($config:nabu-imports)/dataroot/T_WartelisteNeu
let $dates    := collection($config:nabu-imports)/dataroot/Datum
let $contacts := collection($config:nabu-root)//contact
let $pats := collection($config:nabu-patients)/fhir:Patient
:)
let $diab := subsequence(collection($config:nabu-imports)/ss:Workbook/ss:Worksheet/ss:Table/ss:Row, 1, 750)
let $oids := distinct-values($diab/ss:Cell[1]/ss:Data/string())
let $pids := for $oid in $oids
    let $d  := $diab[ss:Cell[1]/ss:Data=$oid][1]
    let $fn := tokenize($d/ss:Cell[3]/ss:Data,',')[1]
    let $gn := tokenize($d/ss:Cell[3]/ss:Data,',')[2]
    let $bd := tokenize($d/ss:Cell[4]/ss:Data,'T')[1]
    let $pp := r-patient:patients('','','1','1',$fn, $bd,'')
    return
        if ($pp/count=1)
        then <patid name="{concat($fn,', ',$gn)}" bd="{$bd}" oid="{$oid}" pid="{$pp/fhir:Patient/fhir:id/@value/string()}"/>
        else ()
let $spz := for $p in $pids
    let $fds  := $diab[ss:Cell[1]/ss:Data=$p/@oid/string()]
    let $pe := r-encounter:encountersBySubject($p/@pid/string(), "", "", "1", "*", "2014-01-01T00:00:00", "2014-12-31T23:59:58","finished")
    return
        if ($pe/count>0)
        then
            <patient>
                {$p}
        {
            for $f in $fds
            let $fd := tokenize($f/ss:Cell[5]/ss:Data,'T')[1]
            let $dq := local:quartal($fd)/@name/string()
            return
                <ddmp datum="{$fd}" fnr="{$f/ss:Cell[2]/ss:Data/string()}">
                {
                    for $e in $pe/fhir:Encounter
                    let $pdat := $e/fhir:period/fhir:start/@value/string()
                    let $pq := local:quartal($pdat)/@name/string()
                    where $dq = $pq
                    return
                        <spz besuch="{$pdat}"/>
                }
                </ddmp>
        }
            </patient>
        else ()
return 
    $spz