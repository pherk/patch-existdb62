xquery version "3.0";

module namespace practmigr = "http://enahar.org/exist/apps/metis/practitioner-migration";

declare namespace fhir= "http://hl7.org/fhir";

declare function practmigr:migrate-1.0-7(
          $p as element(fhir:Practitioner)
        )
{
    let $sp := $p/fhir:specialty/fhir:*
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              for $r in $p/fhir:role
              return
                  update delete $r
            , if ($sp)
              then update replace $p/fhir:specialty with
                   <qualification xmlns="http://hl7.org/fhir">
                    <code>
                        { $sp }
                    </code>
                    <period>
                        <start value=""/>
                        <end value=""/>
                    </period>
                    <issuer>
                        <reference value=""/>
                        <display value=""/>
                    </issuer>
                   </qualification>
               else ()
            ))
    return
        $p
};

declare function practmigr:migrate-1.0-6(
          $p as element(fhir:Practitioner)
        )
{
    
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
                for $i in $p/fhir:identifier[fhir:label]
                let $type := <type xmlns="http://hl7.org/fhir" value="{$i/fhir:label/@value/string()}"/>
                return
                    update replace $i/fhir:label with $type
            ))
    return
        $p
};

declare function practmigr:migrate-1.0-5(
          $p as element(fhir:Practitioner)
        , $vid
        )
{
    if ($vid > 0)
    then
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
             update value $p/fhir:meta/fhir:versionId/@value with $vid
            ))
    return
        $vid
    else
        $vid

};

declare function practmigr:migrate-1.0-4(
          $p as element(fhir:Practitioner)
        )
{
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update replace $p/fhir:meta/fhir:versionID with 
                            <versionId xmlns="http://hl7.org/fhir" value="{$p/fhir:meta/fhir:versionID/@value/string()}"/>
            ))
    return
        $p
};

declare function practmigr:migrate-1.0-3(
          $p as element(fhir:Practitioner)
        )
{
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update delete $p/fhir:lastModified
            , update delete $p/fhir:lastModifiedBy
            ))
    return
        $p
};

declare function practmigr:migrate-1.0-2(
          $p as element(fhir:Practitioner)
        )
{
    let $upd :=
        system:as-user('vdba', 'kikl823!',
            (
              update insert <lastUpdated xmlns="http://hl7.org/fhir" value="{$p/fhir:lastModified/@value/string()}"/>
                            into $p/fhir:meta
            , update insert <extension xmlns="http://hl7.org/fhir" url="http://eNahar.org/nabu/url#lastUpdatedBy">
                                <valueReference>
                                    <reference value="{$p/fhir:lastModifiedBy/fhir:reference/@value/string()}"/>
                                    <display value="{$p/fhir:lastModifiedBy/fhir:display/@value/string()}"/>
                                </valueReference>
                            </extension>
                            into $p/fhir:meta
            ))
    return
        $p
};
