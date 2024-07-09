xquery version "3.1";

import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "/apps/metis/FHIR/Practitioner/practitioner-routes.xqm";

declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";

let $users := collection('/db/apps/metisData/data/FHIR/Practitioners')/fhir:Practitioner[fhir:role/fhir:coding/fhir:code[@value='kikl-spz']][fhir:active/@value='true']

return

<team>
    {
for $u in $users
order by $u/fhir:name[fhir:use/@value='official']/fhir:family/@value
return
    <mensch name="{concat( string-join($u/fhir:name[fhir:use/@value='official']/fhir:family/@value,' ')
                        , ', '
                        ,$u/fhir:name[fhir:use/@value='official']/fhir:given/@value)}"
        tel="{   if ($u/fhir:telecom)
                then string-join($u/fhir:telecom/fhir:value/@value, '; ')
                else ''
            }"/>
    }
</team>
