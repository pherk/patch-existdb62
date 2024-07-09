xquery version "3.0";
module namespace protocol = "http://enahar.org/exist/apps/nabu/protocol";

import module namespace tei2fo = "http://enahar.org/lib/tei2fo";
import module namespace teic   = "http://enahar.org/lib/teic";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://enahar.org/lib/xxpath";

import module namespace config = "http://enahar.org/exist/apps/nabu/config" at "../../modules/config.xqm";
import module namespace r-user = "http://enahar.org/exist/restxq/metis/users"      at "/db/apps/metis/FHIR/user/user-routes.xqm";
import module namespace r-protocol = "http://enahar.org/exist/restxq/nabu/protocols" at "/db/apps/nabu/FHIR/Task/protocol-routes.xqm";
import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients" at "/db/apps/nabu/FHIR/Patient/patient-routes.xqm";


declare namespace   ev= "http://www.w3.org/2001/xml-events";
declare namespace   xf= "http://www.w3.org/2002/xforms";
declare namespace  xdb= "http://exist-db.org/xquery/xmldb";
declare namespace html= "http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace  tei= "http://www.tei-c.org/ns/1.0";




