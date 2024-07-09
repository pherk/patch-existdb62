xquery version "3.0";
import module namespace r-practrole      = "http://enahar.org/exist/restxq/metis/practrole"
                       at "/db/apps/metis/FHIR/PractitionerRole/practitionerrole-routes.xqm";
declare namespace fhir= "http://hl7.org/fhir";

let $aliasold := "lombardol"
let $aliasnew := ""
let $uold := r-practrole:userByAlias($aliasold)//fhir:practitioner/fhir:reference/@value/string()
let $unew := if ($aliasnew="")
    then ""
    else r-practrole:userByAlias($aliasnew)//fhir:practitioner/fhir:reference/@value/string()

let $os := collection('/db/apps/nabuData/data/FHIR/Orders')/fhir:Order[fhir:detail[fhir:actor[fhir:reference[@value=$uold]]][fhir:status[@value="active"]]]
return
    if ($uold!="" and $unew!="")
    then
        let $do := for $o in $os
                let $as := $o/fhir:detail/fhir:actor[fhir:reference[@value=$uold]]
                for $a in $as
                    return
                    ($a,system:as-user("vdba", "kikl823!",
                        (
                          update replace $a/fhir:reference with <reference xmlns="http://hl7.org/fhir" value="{$unew}"/>
                        , update replace $a/fhir:display with <display xmlns="http://hl7.org/fhir" value="{$aliasnew}"/>
                        )))
        return <move-order>{string-join(("moved",count($os),"orders to",$aliasnew)," ")}</move-order>
    else if ($uold!="")
    then
        let $do := for $o in $os
                let $as := $o/fhir:detail/fhir:actor[fhir:reference[@value=$uold]]
                for $a in $as
                    return
                    ($a,system:as-user("vdba", "kikl823!",
                        (
                          update replace $a/fhir:reference with <reference xmlns="http://hl7.org/fhir" value=""/>
                        , update replace $a/fhir:display with <display xmlns="http://hl7.org/fhir" value=""/>
                        )))
        return <move-order>{string-join(("moved",count($do),"orders to ",$aliasnew)," ")}</move-order>
    else <move-order>ERROR: user(s) not found</move-order>