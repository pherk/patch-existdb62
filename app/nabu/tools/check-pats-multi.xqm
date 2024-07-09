xquery version "3.0";

let $os := collection('/db/apps/nabuData/data/FHIR/Patients')/*:Patient[.//*:name/*:given[matches(@value,' [I]+$')]]
return
<name-problems>
      {
for $o in $os
order by $o/*:name/*:family/@value/string()
return
    <patient id="{$o/*:id/@value}"><name>{concat($o/*:name/*:family/@value, ', ', $o/*:name/*:given/@value, ', *', $o/*:birthDate/@value,' : ')}</name></patient>
      }
</name-problems>