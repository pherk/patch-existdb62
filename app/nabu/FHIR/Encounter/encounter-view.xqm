xquery version "3.1";
module namespace enc-view = "http://enahar.org/exist/apps/nabu/encounter-view";


import module namespace r-practrole = "http://enahar.org/exist/restxq/metis/practrole"   at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";

declare namespace fhir= "http://hl7.org/fhir";

(:~
 : show encounters in fullcalendar
 : 
 : @return html
 :)
declare function enc-view:view()
{
    let $status := 
        (
          <status>planned</status>
        , <status>arrived</status>
        , <status>triaged</status>
        , <status>in-progress</status>
(:      ,   <status>cancelled</status> :)
        )
    let $date   := adjust-date-to-timezone(current-date(),())
    let $logu   := r-practrole:userByAlias(xmldb:get-current-user())
    let $prid   := $logu/fhir:id/@value/string()
    let $uref   := $logu/fhir:practitioner/fhir:reference/@value/string()
    let $uid    := substring-after($uref,'metis/practitioners/')
    let $unam   := $logu/fhir:practitioner/fhir:display/@value/string()
    let $group  := 'spz-arzt'
    let $realm := "metis/organizations/kikl-spzn"
    let $head  := 'Besuche - Termine' 
return
<div>
   <h2>Termin-Kalender</h2>
    <table class="svTriggerGroup">
        <tr>
            <td colspan="2">
                <label for="service-hack" class="">Service:</label>
                <select class="app-select" name="service-hack">
                    <option></option>
                </select>
            </td><td colspan="2">
                <label for="actor-hack" class="">Erbringer:</label>
                <select class="app-select" name="actor-hack">
                    <option value="{$uid}">{$unam}</option>
                </select>
            </td>
        </tr>
    </table>
    <div id="calendar"></div>
    <script type="text/javascript" defer="defer" src="FHIR/Encounter/viewencs.js"/>
</div>
};
