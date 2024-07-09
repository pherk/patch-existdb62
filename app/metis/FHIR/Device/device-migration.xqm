xquery version "3.0";

module namespace devmigr = "http://enahar.org/exist/apps/metis/device-migration";


declare namespace fhir= "http://hl7.org/fhir";

declare function devmigr:update-0.9(
          $device as element(fhir:Device)
        )
{
    system:as-user('vdba', 'kikl823!',
        (
          update delete $device/fhir:udi
        , update replace $device/fhir:identifier with
            <identifier xmlns="http://hl7.org/fhir">
                <use value="official"/>
                <type value="PRN"/>
                <system value="{concat('#',$device/fhir:identifier/fhir:label)}"/>
                { $device/fhir:identifier/fhir:value }
            </identifier>
        , update value $device/fhir:url/@value with concat('http://',$device/fhir:url/@value)
        ))
};