xquery version "3.0";

(:~
 : Defines the RestXQ endpoints for user and rbac model
 : the app specific user data are stored within apps
 : 
 : @author Peter Herkenrath
 : @version 0.6
 :)

module namespace r-user="http://enahar.org/exist/restxq/metis/users";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";
import module namespace ical   = "http://enahar.org/lib/ical";

import module namespace config="http://enahar.org/exist/apps/metis/config" at "../../modules/config.xqm";
import module namespace r-group = "http://enahar.org/exist/restxq/metis/groups"  at "../Group/group-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "../Practitioner/practitioner-routes.xqm";

declare namespace xdb ="http://exist-db.org/xquery/xmldb";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare namespace fo     ="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  ="http://exist-db.org/xquery/xslfo";

declare %private function r-user:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};



(:~
 : GET: /metis/users/{$uid}/perms
 : @uid user id
 : @return <permissions xml:id="{$uid}"><perm>...</perm></permissions>
 :)
declare 
    %rest:GET
    %rest:path("metis/users/{$uid}/perms")
    %rest:produces("application/xml")
function r-user:perms($uid as xs:string*) as item()
{
    if ($uid!='')
    then 
        let $groups:= r-group:roles("1","*","","","")
        let $user  := r-practitioner:practitionerByID($uid, 'kikl-spz', $uid, 'true')
        let $roles := distinct-values($user//fhir:role/fhir:coding/fhir:code/@value)
        let $ups   := for $g in $groups/fhir:Group[fhir:code/fhir:text/@value=$roles]
                return
                    $g/fhir:characteristics[fhir:code/fhir:coding/fhir:system/@value="#metis-permission"][fhir:valueBoolean/@value]/fhir:code/fhir:coding/fhir:code/@value
        return
            <permissions xml:id="{$uid}">
                <perm>basic</perm>
                {
                    for $p in distinct-values($ups)
                    return
                        <perm>{$p}</perm>
                }
            </permissions>
    else <permissions/>
};
        (:  :)

(:~
 : GET: /metis/users/{$uid}/group
 : 
 : @uid user id
 : @return xs:string*
 : 
 : TODO move to Group
 :)
declare
    %rest:GET
    %rest:path("metis/users/{$uid}/group")
    %rest:produces("application/xml", "text/xml")
function r-user:group($uid as xs:string*)
{
    let $u := r-practitioner:practitionerByID($uid, 'kikl-spz', 'u-admin', 'true')
    return
        if ($u)
        then $u/fhir:role[1]/fhir:coding/fhir:code/@value/string()
        else r-user:rest-response(404, 'user not found. Ask the admin.')
};

(:~
 : GET: /metis/roles/{$uid}/roles
 : maps group as role into roles
 : @uid user id
 : @return <roles/>
 :)
declare
    %rest:GET
    %rest:path("metis/users/{$uid}/roles")
    %rest:query-param("realm", "{$realm}", "kikl-spz")
    %rest:query-param("loguid", "{$loguid}", "")
    %rest:produces("application/xml", "text/xml")
function r-user:rolesByID(
      $uid as xs:string*
    , $realm as xs:string*
    , $loguid as xs:string*
    ) as item()*
{
    let $user := r-practitioner:practitionerByID($uid, $realm, $loguid, 'true')
    return
        if ($user/fhir:id)
        then 
            let $rs := distinct-values($user/fhir:role/fhir:coding/fhir:code/@value)
            let $auth := $realm = $rs
            return
                if ($auth)
                then
                    <roles>{
                        for $r in $rs
                        return
                            <role>{$r}</role>
                    }</roles>
                else
                    r-user:rest-response(404, 'user not in realm. Ask the admin.')
        else r-user:rest-response(404, 'user not found. Ask the admin.')
};

(:~
 : GET: /metis/users/{$uid}
 : 
 : @param $uid user id
 : @return <user/>
 : 
 : @deprecated soon TODO use practitioner instead
 : TODO assert that id is user
 :)
declare 
    %rest:GET
    %rest:path("metis/users/{$uid}")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-user:userByID(
    $uid as xs:string*
    , $format as xs:string*) as item()
{
    let $u := r-practitioner:practitionerByID($uid, 'kikl-spz', 'u-admin','true')
    return
        if (count($u/fhir:id)=1)
        then
            switch($format)
            case 'ref'  return
                <practitioners xmlns="">
                    <count>1</count>
                    <start>1</start>
                    <length>1</length>
                {
                    let $unam := r-user:name2display($u/fhir:name[fhir:use/@value='official'])
                    return
                        <user xmlns="http://hl7.org/fhir">
                            <reference value="{concat('metis/practitioners/',$u/*:id/@value/string())}"/>
                            <display value="{$unam}"/>
                        </user>
                }
                </practitioners>
            default return $u
        else
            $u
};

(:~
 : GET: /metis/users/{$alias}/alias
 : Search user using identifier alias
 : 
 : @param $alias
 : @return <user/>
 :  
 : @deprecated soon TODO use practitioner instead
 :)
declare 
    %rest:GET
    %rest:path("metis/users/{$alias}/alias")
    %rest:produces("application/xml", "text/xml")
function r-user:userByAlias($alias as xs:string*) as item()
{
    r-practitioner:practitionerByIdentifier($alias, 'kikl-spz', 'u-admin', "http://eNahar.org/nabu/system#metis-account", 'true')
};

(: 
 : JSON functions as Javascript rest end points
:)

(:~
 : GET: /metis/users?role=...&name=...
 : 
 : @param $name name of user
 : @param $org  organization
 : @param $role role (default: kikl-spz)
 : 
 : @return json array
 :)
declare 
    %rest:GET
    %rest:path("metis/users")
    %rest:query-param("start",  "{$start}",  "1")      
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("name",   "{$family}", "")
    %rest:query-param("org",    "{$org}",    "")    
    %rest:query-param("role",   "{$role}",   "kikl-spz")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")
function r-user:usersJSON($start as xs:string*, $length as xs:string*,
    $family as xs:string*, 
    $org as xs:string*, 
    $role as xs:string*) as item()
{
    let $hits := r-practitioner:practitioners($start, $length, $family, '', $org, $role, '', 'team', 'true')
    (: get roles from role name 
    let $rhits:= if ($role='roles')
            then let $roles := r-group:roles('1,', '*', $org, $family, ())/role
                for $r in $roles
                order by lower-case($r/@label/string())
                return
                <json:value xmlns:json="http://www.json.org" json:array="true">
                    <id>{$r/@value/string()}</id>
                    <text>{$r/@label/string()}</text>
                </json:value>  
            else ()
    :)
    return
    <json:array xmlns:json="http://www.json.org">
    {
        for $u in $hits//fhir:Practitioner
        let $uid := $u/fhir:id/@value/string()
        let $name := concat(
                  string-join($u/fhir:name[fhir:use/@value='official']/fhir:family/@value, ' ')
                , ', '
                , $u/fhir:name[fhir:use/@value='official']/fhir:given/@value)
        order by lower-case($name)
        return

        <json:value xmlns:json="http://www.json.org" json:array="true">
            <id>{$uid}</id>
            <text>{$name}</text>
        </json:value>
    }
    </json:array>
};


(:~
 : GET: /metis/users
 : Search user using family name and/or org field
 : 
 : @param $start  ( 1)
 : @param $length (10)
 : @param $family ()
 : @param $role   ()
 : @param $org    ()
 : @return  bundle practitioner
 :)
declare 
    %rest:GET
    %rest:path("metis/users")
    %rest:query-param("name",   "{$family}",   "")
    %rest:query-param("role",   "{$role}",   "kikl-spz")
    %rest:query-param("org",    "{$org}",   "")
    %rest:query-param("_format","{$format}" , "full")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-user:users( 
    $family as xs:string*,
    $role as xs:string*,
    $org as xs:string*,
    $format as xs:string*) as item()
{
    let $users := r-practitioner:practitioners('1', '*', $family, '', $org, $role, '', 'team', 'true')  
    return
           <practitioners xmlns="">
                <count>{$users/count/string()}</count>
                <start>{$users/start/string()}</start>
                <length>{$users/length/string()}</length>
            {
                switch($format)
                case 'ref'  return
                    for $u in $users/fhir:Practitioner
                    let $unam := r-user:name2display($u/fhir:name[fhir:use/@value='official'])
                    return
                        <user xmlns="http://hl7.org/fhir">
                            <reference value="{concat('metis/practitioners/',$u/*:id/@value/string())}"/>
                            <display value="{$unam}"/>
                        </user>
                case 'compact'  return
                    for $u in $users/fhir:Practitioner
                    let $unam := r-user:name2display($u/fhir:name[fhir:use/@value='official'])
                    let $roles := string-join($u/fhir:role/fhir:coding/fhir:code/@value,' ')
                    return
                        <user xmlns="http://hl7.org/fhir">
                            <reference value="{concat('metis/practitioners/',$u/fhir:id/@value/string())}"/>
                            <display value="{$unam}"/>
                            <roles value="{$roles}"/>
                            <realm value="{$role}"/>
                        </user>
                default return $users
            }
            </practitioners>
};

(:~
 : name2display
 : formats fhir name element
 : 
 : @param $name     name property
 : @return xs:string 
 :)
declare function r-user:name2display(
          $name as element(fhir:name)
        ) as xs:string
{
    let $family := string-join($name/fhir:family/@value,' ')
    return
        if ($name/fhir:given/@value='')
        then $family
        else
            concat( $family, ', ', $name/fhir:given/@value)
};

(:~
 : GET: /metis/users/birthdates
 : Search user using family name and/or org field
 : 
 : @param $start  ( 1)
 : @param $length (10)
 : @param $family ()
 : @param $org    ()
 : @return  birthdays as PDF
 :)
declare 
    %rest:GET
    %rest:path("metis/users2birthdates")
    %rest:query-param("start",  "{$start}",  "1")      
    %rest:query-param("length", "{$length}", "*")
    %rest:query-param("name",   "{$family}",   "")
    %rest:query-param("org",    "{$org}",   "")
    %rest:produces("application/pdf")
    %output:method("binary")
function r-user:userBirthDates($start as xs:string*, $length as xs:string*, 
    $family as xs:string*, $org as xs:string*)
{
    let $facets := 
        <facets xmlns="">
            <facet name="name"      method="matches" path="fhir:name/fhir:family/@value"></facet>
            <facet name="birthdate" method="matches" path="fhir:birthDate/@value"></facet>
        </facets>
    let $users := r-practitioner:practitioners($start, $length, $family, '', $org, 'kikl-spz', '', 'team', 'true')
    let $data := for $u in $users/fhir:Practitioner[fhir:birthDate/@value!='']
                order by substring($u/fhir:birthDate/@value,6)
                return $u
    let $result := 
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    {   teic:header("Geburtstagsliste") }
        <text xml:lang="en">
            <body xmlns="http://www.tei-c.org/ns/1.0">
                <div>
                    <table rows="{count($data)}" cols="4:4:1"> <!-- cols attribute specifies column-width in cm, FO hack -->
                        <head>Geburtstagsliste</head>
                    {
                        for $m in (1 to 12)
                        for $r at $i in $data[$m = xs:integer(tokenize(fhir:birthDate/@value,'-')[2])]
                        let $toks := tokenize($r/fhir:birthDate/@value,'-')
                        return
                            if ($m=1 and $toks[3]='01') (: do not show 01.01.xxxx :)
                            then ()
                            else <row role="data">
                                    <cell role="label">{if ($i=1) then $ical:infos/*:monat[@value=$m]/@label/string() else ''}</cell>
                                    <cell role="data">{concat($r/fhir:name/fhir:family/@value,', ', $r/fhir:name/fhir:given/@value)}</cell>
                                    <cell role="data">{concat($toks[3],'.',$toks[2])}</cell>
                                </row>
                    }
                    </table>
                </div>
            </body>
        </text>
    </TEI>
    let $fo  := tei2fo:report($result)

    let $pdf := xslfo:render($fo, "application/pdf", ())
    return
    (   <rest:response>
            <http:response status="200">
                <http:header name="Content-Type" value="application/pdf"/>
                <http:header name="Content-Disposition" value="attachment;filename=birthdates.pdf"/>
            </http:response>
         </rest:response>
    , $pdf)

};



(:~
 : PUT: /metis/users/{$uid}/passwd
 : Update an existing password.
 : 
 : @param $uid
 : @return
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("/metis/users/{$uid}/passwd")
    %rest:header-param("realm",  "{$realm}")
    %rest:header-param("loguid", "{$loguid}")
    %rest:header-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-user:changePasswdXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    , $uid as xs:string*
    )
{
    let $opw  := $content//oldPassword
    let $npw  := $content//newPassword
    let $cpw  := $content//confirmPassword
    let $isAuth := if ($uid = $loguid)
        then 'basic' = r-user:perms($uid)/perm
        else 'perm_updateAccount' = r-user:perms($loguid)/perm
    return
        if ($isAuth and r-user:isValidPW($opw,$npw,$cpw))
        then try {
            let $userAlias := r-practitioner:practitionerByID($uid, 'kikl-spz', 'u-admin','true')/fhir:identifier[fhir:system/@value="http://eNahar.org/nabu/system#metis-account"]/fhir:value/@value/string()
            let $logAlias  := r-practitioner:practitionerByID($loguid, 'kikl-spz', 'u-admin','true')/fhir:identifier[fhir:system/@value="http://eNahar.org/nabu/system#metis-account"]/fhir:value/@value/string()
            let $sys       := system:as-user('admin', 'kikl968', sm:passwd($userAlias, $npw)) 
            return
                r-user:rest-response(200, 'password successfully stored.')
        } catch * {
                r-user:rest-response(401, 'unexpected error. Ask the admin.') 
        }
        else    r-user:rest-response(401, 'invalid password or permission denied. Ask the admin.') 
};

declare %private function r-user:isValidPW($opw as xs:string, $npw as xs:string, $cpw as xs:string) as xs:boolean
{
    ($opw!='' and $npw!='' and $cpw!='' and $opw!=$npw and $npw=$cpw)
};

(:~
 : DELETE: Delete an user identified by its uid.
 : 
 : @param $uid
 : @return
 :)
declare
    %rest:DELETE
    %rest:path("metis/users/{$uid}")
function r-user:delete-user($uid as xs:string*) {
    let $log := util:log-system-out('RESTXQ: delete-user: nyi')
    return
        r-user:rest-response(501, 'nyi. Ask the admin.')
};

