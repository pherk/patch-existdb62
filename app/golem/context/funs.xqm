xquery version "3.0";

module namespace refun = "http://enahar.org/exist/apps/golem/functions";

declare namespace golem = "http://enahar.org/ns/1.0/golem";
declare namespace  fhir = "http://hl7.org/fhir";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";


declare function refun:correctedAge(
      $context as element(golem:context)
    ) as xs:dayTimeDuration
{
    xs:dayTimeDuration($context/golem:other/golem:correctedAge/@value)
};

declare function refun:et(
      $context as element(golem:context)
    ) as xs:date
{
    if ($context/golem:other/golem:et)
    then
        xs:date($context/golem:other/golem:et/@value)
    else 
        xs:date($context/golem:other/fhir:birthDate/@value)
};

