xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

(:
 : family
 : '[\(\)]' 
 : ' falsch', ' FALSCH'
 : ' DOPPELT'
 : '\ '
 : given
 : ' I+$'
 : 'Poli POLI'
 : ' $'
 :)
let $os := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[./fhir:name/fhir:given[matches(@value,' +$')]]
return
<name-problems>
      {
for $o in $os
order by $o/fhir:name[fhir:use[@value='official']]/fhir:family/@value/string()
return
    <patient id="{$o/@xml:id/string()}"><name>{concat($o/fhir:name[fhir:use[@value='official']]/fhir:family/@value, ', ', $o/fhir:name[fhir:use[@value='official']]/fhir:given/@value, ', *', $o/fhir:birthDate/@value,' : ')}</name></patient>
      }
</name-problems>