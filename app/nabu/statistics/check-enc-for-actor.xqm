xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";
import module namespace r-encounter = "http://enahar.org/exist/restxq/nabu/encounters" at "/db/apps/nabu/FHIR/Encounter/encounter-routes.xqm";

(:~
 : Script zum Auflisten von Patienten, die ein Erbringer in Zeitraum betreut hat.
 : Macht nebenbei auch ein wenig Statistik zu Patienten/Terminen pro VK,
 : berücksichtigt dabei keine besonderen Abwesenheiten oder VK-Änderungen
 : 
 : @version 0.9
 : @date 2019-01-28
 : @createdBy pmh
 :)
let $actors := map {
    (: Ärzte :)
      "Bossier" : ("Bossier, Christiane", "u-bossierc", 0.2)
    , "Cirak" : ("Cirak, Sebahattin", "c-9220f48e-69a1-4c7c-96eb-22e6c459f798", 0.25)
    , "Dafsari" : ("Dafsari, Hormos", "c-3928168b-b5f3-40cb-a15c-7e799820ce1d", 1.0)
    , "Duran" : ("Duran, Ibrahim", "c-1650", 0.2)
    , "Ellerich" : ("Ellerich, Karl Joachim" , "c-1789", 0.1)
    , "Fazeli" : ("Fazeli, Walid", "c-9470196f-5c17-416c-9a21-db8530cf6cfd", 1.0)
    , "Giersdorf": ("Giersdorf, Matthias" , "u-tscheschem", 0.8)
    , "Herkenrath" : ("Herkenrath, Peter", "u-pmh", 0.5)
    , "Jopp" : ("Jopp, Gabriele", "u-joppg", 0.75)
    , "Lombardo": ("Lombardo, Lisa" , "c-5b4b3c71-775f-4ee8-a8fa-27a5e0a425eb", 1.0)
    , "Koy"   : ("Koy, Anne", "c-7094fe4a-6113-4c49-8874-997c3c1cc4ce", 0.5)
    , "Martakis" : ("Martakis, Kyriakos", "u-martakisk", 0.25)
    , "Sherzada" : ("Sherzada, Roman", "c-bd10341b-4266-4329-80d8-b2d2a106c321", 1.0)
    , "Trepper-Börner" : ("Trepper-Börner, Sarah", "c-dba19d06-79ae-457c-b2e0-ffad698c7d5e", 0.4)
    , "vKR" : ("von Kleist-Retzow, Jürgen-Christoph", "u-vkr", 0.25)
    , "Wunram" : ("Wunram, Heidi", "u-wunramh", 0.5)
    , "Zerlett" : ("Zerlett, Carolin", "c-d24693be-5ee3-4fc7-b95f-2ba95e481e73", 1.0)
    (: Psychologen :)
    , "Bartz" : ("Bartz, Ulrike", "u-bartzu", 0.31)
    , "Blatz" : ("Blatz, Lisa", "c-90e5765a-adea-4f1d-a012-d19a39f77cfc", 0.31)
    , "Düchting" : ("Düchting, Christoph", "u-duechtingc", 0.77)
    , "Grittner" : ("Grittner, Bettina", "u-grittnerb", 0.5)
    , "Kloidt" : ("Kloidt, Birgit", "u-kloidtb", 0.73)
    , "Kranz" : ("Kranz, Gesa", "c-722aac88-c5e5-4f84-8432-a8eaf1743fc7", 0.42)
    , "Müller" : ("Müller, Nina", "c-51613f9a-3b72-40f7-9cb3-c29f79ea4457", 0.5)
    , "Pozsgai" : ("Pozsgai, Tabea", "c-895a3af4-2e16-4c45-a1dd-0a73b9d9b0df", 0.17)
    , "Schirmer" : ("Schirmer-Petri, Astrid", "u-spa", 0.65)
    , "Schlamann" : ("Schlamann, Pia", "c-58ce7cae-5c32-4e8a-8567-f7e60a72f8c0", 0.39)
    (: Therapeuten :)
    , "Wesemann" : ("Wesemann, Henrike", "u-wesemannh", 0.1)
    }

let $key := "Koy"
let $year := '2023'
let $start := $year || '-01-01'
let $end := $year || '-12-31'
let $dur := (xs:date($end)-xs:date($start)) div xs:dayTimeDuration("P1D") + 1
let $corr := 365 div $dur 

let $actor := map:get($actors,$key)
let $uid :=  $actor[2]
let $aref := concat('metis/practitioners/',$uid)
let $adisp := $actor[1]
let $res := r-encounter:encountersXML("kikl-spzn","u-admin","admin", "1", "*"
    , $uid
    , "", "", ""
    , $start
    , $end
    , "finished"
    , "date:asc"
    )


let $prefs := distinct-values($res/fhir:Encounter/fhir:subject/fhir:reference/@value)
let $patients := for $p in $prefs
        let $eForP := $res/fhir:Encounter[fhir:subject[fhir:reference/@value=$p]]  (: [fhir:type//fhir:code[@value="amb-spz-moto"]] :)
        let $id := substring-after($p,'nabu/patients/')
        let $display := $eForP[1]/fhir:subject/fhir:display/@value/string()
        order by $display
        return
            <patient display="{$display}">
            {
                for $e in $eForP
                order by $e/fhir:period/fhir:start/@value/string()
                return
                    <event date="{$e/fhir:period/fhir:start/@value/string()}"/> 
            }
            </patient>
return
    <patient-list>
        <params>
            <start value="{$start}"/>
            <end value="{$end}"/>
            <actor>
                <reference value="{$aref}"/>
                <display value="{$adisp}"/>
            </actor>
            <vk>{$actor[3]}</vk>
        </params>
        <info>
            <npat value="{count($patients)}"/>
            <nevents value="{count($res/fhir:Encounter)}"/>
            <dur value="{$dur}"/>
            <e2vk value="{(count($res/fhir:Encounter) div $actor[3]) * $corr}"/>
        </info>
        { $patients }
    </patient-list>
    
 
    