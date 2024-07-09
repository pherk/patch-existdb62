xquery version "3.0";

import module namespace dbutil="http://exist-db.org/xquery/dbutil";

(:~ Nabu security - admin user and users group :)
declare variable $nabu-admin-user  := "admin";
declare variable $nabu-admin-pw    := "";
declare variable $nabu-pmh-user    := "pmh";
declare variable $nabu-pmh-pw      := "";
declare variable $user-group    := "spz";
declare variable $data-group    := "spz";
declare variable $nabu-root     := "/db/apps/nabu";
declare variable $metis-root    := "/db/apps/metis";
declare variable $eNahar-root   := "/db/apps/eNahar";
declare variable $nabu-data     := "/db/apps/nabuData/data";
declare variable $metis-data    := "/db/apps/metisData/data";
declare variable $eNahar-data   := "/db/apps/eNaharData/data";

declare variable $config-collection  := "/db/system/config";

declare function local:create-admin-user() {
    if (not(xmldb:exists-user( $nabu-admin-user))) then
        xmldb:create-user($nabu-admin-user, $nabu-admin-pw, $metis-users-group, ())
    else
        ()
};

declare function local:create-pmh-user() {
    if (not(xmldb:exists-user($nabu-pmh-user))) then
        xmldb:create-user($nabu-pmh-user, $nabu-pmh-pw, $metis-users-group, ())
    else
        ()
};

declare function local:fixPath($path, $grp, $perms)
{
   (: sm:chown($path, 'admin'), :)
    sm:chgrp($path, $grp),
    sm:chmod($path, $perms)
};

(: You need to run this as an admin user :)
let $data-perms := "rwxrwxr-x"
let $perms      := "rwxrwxr-x"
let $spz   := if (sm:group-exists($user-group))
    then ()
    else sm:create-group($user-group)
let $vdba   := if (sm:group-exists($data-group))
    then ()
    else sm:create-group($data-group)
let $scan1 :=
    dbutil:scan(xs:anyURI("/db/apps/nabu"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $user-group, $perms)
        else local:fixPath($collection, $user-group, $perms)
    }) 
let $scan2 :=
    dbutil:scan(xs:anyURI("/db/apps/metis"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $user-group, $perms)
        else local:fixPath($collection, $user-group, $perms)
    })
let $scan3 :=
    dbutil:scan(xs:anyURI("/db/apps/eNahar"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $user-group, $perms)
        else local:fixPath($collection, $user-group, $perms)
    })
(:
let $scan4 :=
    dbutil:scan(xs:anyURI("/db/apps/nabuData/data/FHIR/Patients"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan5 :=
    dbutil:scan(xs:anyURI("/db/apps/metisData/data"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan2a :=
    dbutil:scan(xs:anyURI("/db/apps/metisHistory"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $user-group, $perms)
        else local:fixPath($collection, $user-group, $perms)
    })
let $scan6 :=
    dbutil:scan(xs:anyURI("/db/apps/eNaharData/data"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan7 :=
    dbutil:scan(xs:anyURI("/db/apps/nabuCom/data/Goals"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan8 :=
    dbutil:scan(xs:anyURI("/db/apps/nabuCom/errors"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    }) 
let $scan9 :=
    dbutil:scan(xs:anyURI("/db/apps/nabuHistory/data"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan10 :=
    dbutil:scan(xs:anyURI("/db/apps/eNaharHistory/data"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan11 :=
    dbutil:scan(xs:anyURI("/db/apps/nabuWorkflow/data"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })

let $scan12 :=
    dbutil:scan(xs:anyURI("/db/apps/nabuEncounter/data/planned"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan13 :=
    dbutil:scan(xs:anyURI("/db/apps/nabuComposition/data"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan14 :=
    dbutil:scan(xs:anyURI("/db/apps/nabuCommunication/data"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
let $scan15 :=
    dbutil:scan(xs:anyURI("/db/apps/nabu/statistics/evals"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-group, $data-perms)
        else local:fixPath($collection, $data-group, $data-perms)
    })
    :)
return
    'permissions fixed'

