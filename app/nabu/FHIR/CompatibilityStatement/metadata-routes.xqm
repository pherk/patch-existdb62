xquery version "3.1";
(: 
 : Defines the 'metadata' RestXQ endpoints
 :)
module namespace r-capa = "http://enahar.org/exist/restxq/nabu/capabilities";


import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize" at "../../FHIR/meta/serialize-fhir-resources.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

declare variable $r-capa:server  := "http://spz.uk-koeln.de";
declare variable $r-capa:context := "/exist/restxq/";


declare %private function r-capa:rest-response($code as xs:integer, $message as xs:string)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

(:~
 : GET: nabu/metadata
 : List conformance for endpoint
 :  
 : @param   $realm
 : @param   $loguid
 : @param   $lognam
 : @return  bundle <CapabilityStatement/>
 :)
declare
    %rest:GET
    %rest:path("nabu/metadata")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/xml", "text/xml")
function r-capa:metadataXML(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()*
{
    try {
        let $cps := r-capa:capabilities()
    return
        $cps
    } catch * {
        let $lll := util:log-app('ERROR','apps.nabu',concat($err:code,':',$err:description))
        return
        r-capa:rest-response(404, 'error: metadata not retrieved')
    }
};
(:~
 : GET: nabu/metadata
 : List conformance for endpoint
 :  
 : @param   $realm
 : @param   $loguid
 : @param   $lognam
 : @return  bundle <CapabilityStatement/>
 :)
declare
    %rest:GET
    %rest:path("nabu/metadata")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:produces("application/json")
function r-capa:metadataJSON(
      $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()*
{
    try {
        let $cps := r-capa:capabilities()
    return
        serialize:resource2json($cps,false(),"4.3")
    } catch * {
        let $lll := util:log-app('ERROR','apps.nabu',concat($err:code,':',$err:description))
        return
        r-capa:rest-response(404, 'error: metadata not retrieved')
    }
};

declare %private function r-capa:capabilities()
{
<CapabilityStatement xmlns="http://hl7.org/fhir">
  <url value="http://10.2.3.4/nabu"/>
  <name value="Ntwo Haskell"></name>
  <title value="Ntwo Haskell"></title>
  <status value="draft"></status>
  <experimental value="true"></experimental>
  <date value="2023-03-22T08:00:00"></date>
  <publisher value="eNahar.org"></publisher>
  <contact>
    <name value="System Administrator"></name>
    <telecom>
      <system value="email"></system>
      <value value="peter.herkenrath@uk-koeln.de"></value>
    </telecom>
  </contact>
  <jurisdiction>
    <coding>
      <system value="urn:iso:std:iso:3166"></system>
      <code value="DEU"></code>
      <display value="Deutschland"></display>
    </coding>
  </jurisdiction>
  <purpose value="FHIR server for nSPZ UKK"></purpose>
  <copyright value="MAAT"></copyright>
  <kind value="instance"></kind>
  <software>
    <name value="EHR"></name>
    <version value="0.00.020.2134"></version>
    <releaseDate value="2012-01-04"></releaseDate>
  </software>
  <implementation>
    <description value="Main EHR at SPZ UKK"></description>
    <url value="http://10.2.3.4/fhir"></url>
    <custodian>
      <reference value="nabu/practitioners/u-pmh"></reference>
      <display value="Herkenrath, Peter"></display>
    </custodian>
  </implementation>
  <fhirVersion value="4.0.1"></fhirVersion>
  <format value="xml"/> 
  <format value="json"/> 
  <rest>
    <mode value="server"></mode>
    <documentation value="Main endpoint for Nabu2.0"></documentation>
    <security>
        <cors value="true"/>
        <service>
            <coding>
                <system value="http://hl7.org/fhir/restful-security-service"/>
                <code value="Basic"/>
            </coding>
        </service>
    </security>
    <compartment value="http://enahar.org/nabu/CompartmentDefinition/patient"></compartment>
  </rest>
</CapabilityStatement>
};