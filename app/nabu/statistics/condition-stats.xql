xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";

(: Achtung: legt ohne Index den Server lahm!!! :)
count(collection('/db/apps/nabuCom/data/Conditions')/fhir:Condition[fhir:code/fhir:coding/fhir:system[@value='#nabu-finding']])