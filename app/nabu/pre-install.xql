xquery version "1.0";

import module namespace config="http://enahar.org/exist/apps/nabu/config" at "modules/config.xqm";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace dbutil="http://exist-db.org/xquery/dbutil";


(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

declare function local:set-collection-resource-permissions($collection as xs:string, $owner as xs:string, $group as xs:string, $permissions as xs:int) {
    for $resource in xdb:get-child-resources($collection) return
        xdb:set-resource-permissions($collection, $resource, $owner, $group, $permissions)
};

declare function local:strip-prefix($str as xs:string, $prefix as xs:string) as xs:string? {
    fn:replace($str, $prefix, "")
};

declare function local:fixPath($path, $perms)
{
  (:  sm:chown($path, 'admin'),
    sm:chgrp($path, 'spz'), :)
    sm:chmod($path, $perms)
};

declare function local:create-resources()
{
let $data-perms := "rwxrwxr-x"
return
if (starts-with($config:nabu-config/configuration/root/string(), "/db")) 
then (: data collection not in app-root :)
    (
    util:log-app('DEBUG', 'nabu', fn:concat("Config: Creating data collection '", $config:nabu-root, "'...")),
    for $col in $config:nabu-data-collections return
    (
        local:mkcol($config:nabu-root, local:strip-prefix($col, fn:concat($config:nabu-root, "/")))
    ),
    util:log-app('DEBUG', 'nabu', "...Config: Uploading initial data..."),
    xdb:store-files-from-pattern($config:metis-users,  $dir, "data/users/*.xml"),
    xdb:store-files-from-pattern($config:nabu-tasks,  $dir, "data/tasks/*.xml"),
    xdb:store-files-from-pattern($config:nabu-templs, $dir, "data/templates/*.xml"),
    util:log-app('DEBUG', 'nabu', "...Config: Done Uploading inital data."),
    util:log-app('DEBUG', 'nabu', "...Config: Fixing data permissions."),
    dbutil:scan(xs:anyURI($config:nabu-root), function($collection, $resource) {
        if ($resource)
        (: and  xmldb:get-mime-type($resource) = "application/xml") then :)
        then local:fixPath($resource, $data-perms)
        else local:fixPath($collection, $data-perms)
    }),
    util:log-app('DEBUG', 'nabu', "Config: Done.")
    )
    else ()
};

(: store the collection configuration :)
local:mkcol("/db/system/config", $target),
xdb:store-files-from-pattern(concat("/system/config", $target), $dir, "*.xconf"),

if (sm:group-exists($config:default-group)) then 
    ()
else 
    sm:create-group($config:default-group),
if (sm:group-exists($config:admin-group)) then
    ()
else
    sm:create-group($config:admin-group, "nabu administrator group"),
if (sm:user-exists($config:default-user[1])) then
    ()
else
    sm:create-account($config:default-user[1], $config:default-user[2], $config:default-group, $config:admin-group)
    
    

