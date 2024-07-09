xquery version "3.0";

import module namespace dbutil="http://exist-db.org/xquery/dbutil";

(:~ Nabu security - admin user and users group :)
declare variable $metis-users-group := "spz";


declare variable $metis-data   := "/db/apps/metisData/data";
declare variable $metis-tmpls  := $metis-data || "/templates";

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

declare function local:fixPath($path, $perms)
{
   (: sm:chown($path, 'admin'), :)
    sm:chgrp($path, 'spz'),
    sm:chmod($path, $perms)
};

(: You need to run this as an admin user :)
let $data-perms := "rwxrwxr-x"
let $perms      := "rwxr-xr-x"
let $grp   := if (sm:group-exists('spz'))
    then ()
    else sm:create-group('spz')
return
 (:
    dbutil:scan(xs:anyURI("/db/apps/rojbas"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $perms)
        else local:fixPath($collection, $perms)
    }) 
:)
    dbutil:scan(xs:anyURI("/db/apps/metisData/data"), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-perms)
        else local:fixPath($collection, $data-perms)
    })


