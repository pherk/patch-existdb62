xquery version "1.0";

import module namespace xmldb = "http://exist-db.org/xquery/xmldb";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace auth  = "http://enahar.org/exist/apps/nabu/auth" at "../modules/auth.xqm";
import module namespace user = "http://enahar.org/exist/apps/nabu/user" at "../user/user.xqm";
import module namespace roles = "http://enahar.org/exist/apps/nabu/roles" at "../user/roles.xqm";
import module namespace config= "http://enahar.org/exist/apps/nabu/config" at "../modules/config.xqm";
import module namespace tasks ="http://enahar.org/exist/apps/nabu/tasks" at "../task/tasks.xqm";
import module namespace forms = "http://enahar.org/exist/apps/nabu/forms" at "../modules/forms.xqm";
import module namespace r-user  ="http://enahar.org/exist/restxq/nabu/user" at "../user/user-routes.xqm";
import module namespace r-task = "http://enahar.org/exist/restxq/nabu/task" at "../task/task-routes.xqm";
(:   http://a:8080/exist/rest/db/apps/h2flow?_query=rest:resource-functions()//rest:resource-function[starts-with(./@xquery-uri,
'/db/apps/h2flow')] :)

let $p := collection($config:nabu-patients)/demographics
let $i := collection($config:nabu-patients)/dataroot/Patienten
(:  prüft ob alle Patienten importiert wurden :)
for $d in $i/P_Nr/string()
return
    if ($p/contact[@paule-id=$d])
    then ()
    else $d
