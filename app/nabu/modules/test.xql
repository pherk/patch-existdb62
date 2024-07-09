xquery version "3.0";

import module namespace xmldb = "http://exist-db.org/xquery/xmldb";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";

import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";
import module namespace date   = "http://enahar.org/exist/apps/nabu/date"   at "../modules/date.xqm";

import module namespace user   = "http://enahar.org/exist/apps/metis/user"    at "/db/apps/metis/user/user.xqm";
import module namespace r-user = "http://enahar.org/exist/restxq/metis/users" at "/db/apps/metis/user/user-routes.xqm";

import module namespace task   = "http://enahar.org/exist/apps/nabu/task"     at "../task/tasks.xqm";

(: import module namespace doc    = "http://enahar.org/exist/apps/nabu/document"     at "../patient/doc.xqm"; :)
import module namespace r-doc  = "http://enahar.org/exist/restxq/nabu/documents"  at "../patient/doc-routes.xqm";
import module namespace r-encounter = "http://enahar.org/exist/restxq/nabu/encounters" at "../FHIR/Encounter/encounter-routes.xqm";
import module namespace r-appointment = "http://enahar.org/exist/restxq/nabu/appointments" at "../FHIR/Appointment/appointment-routes.xqm";
(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/exist/apps/nabu/xxpath" at "../../modules/xxpath.xqm";

(:   http://a:8080/exist/rest/db/apps/h2flow?_query=rest:resource-functions()//rest:resource-function[starts-with(./@xquery-uri,
'/db/apps/h2flow')] :)
declare namespace fhir   = "http://hl7.org/fhir";
declare copy-namespaces no-preserve, no-inherit;
(:  declare default element namespace "http://hl7.org/fhir"; :)

(: check import of events :)
let $worker  := collection($config:nabu-imports)/dataroot/Abk_Erbringer
let $events  := collection($config:nabu-imports)/dataroot/Termine
let $db-e  := collection($config:nabu-encounters)
let $db-a  := collection($config:nabu-appointments)
let $import-patients :=  collection($config:nabu-imports)/dataroot/Patienten
let $import-wl :=  collection($config:nabu-imports)/dataroot/T_WartelisteNeu
let $dates   := collection($config:nabu-imports)/dataroot/Datum

let $filter := '2015-06-09'
let $status := 'booked'
let $pats := collection($config:nabu-patients)
let $logu   := r-user:userByAlias(xmldb:get-current-user())
let $loguid := $logu/fhir:id/@value/string()
let $myAppointments := r-appointment:appointmentsXML($loguid, 'kikl-spz',
                            'u-gritzmannr', 'arzt', '',
                            $filter || 'T00:00:00', $filter || 'T23:59:59',
                            '1', '*', $status)
    for $a in $myAppointments/fhir:Appointment
    let $aid   := $a/fhir:id/@value/string()
    let $start := format-dateTime(xs:dateTime($a/fhir:start/@value), "[H,2]:[m,2]")
    let $end   := format-dateTime(xs:dateTime($a/fhir:end/@value), "[H,2]:[m,2]")
    let $subject := $a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value='patient']/fhir:actor/fhir:display/@value/string()
    let $service := $a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value!='patient']/fhir:type/fhir:coding/fhir:code/@value/string()
    let $provider:= $a/fhir:participant[fhir:type/fhir:coding/fhir:code/@value!='patient']/fhir:actor/fhir:display/@value/string()
    order by $a/fhir:start/@value/string()
    return
         <tr id="{$aid}">
            <td>{format-date(xs:date(tokenize($a/fhir:start/@value/string(),'T')[1]),"[Y02]-[M01]-[D02]")}</td>
            <td>{$start}</td>
            <td>{$end}</td>
            <td>{$subject}</td>
            <td>{$a/fhir:description/@value/string()}</td>
            <td>{$service}</td>
            <td>{$provider}</td>
         </tr> 


    