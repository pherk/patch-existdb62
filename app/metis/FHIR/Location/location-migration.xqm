xquery version "3.0";

module namespace locmigr = "http://enahar.org/exist/apps/metis/location-migration";


declare namespace fhir= "http://hl7.org/fhir";

declare function locmigr:update-0.9(
          $loc as element(fhir:Location)
        )
{
    let $type := $loc/fhir:extension[@url='#room-type']/fhir:valueCode/@value/string()
    let $disp := switch($type)
        case 'ub' return 'UB-Raum'
        case 'aux' return 'Aux'
        case 'admin' return 'Büro'
        default return 'unknown'
    return
    system:as-user('vdba', 'kikl823!',
        (
          update insert 
                <alias xmlns="http://hl7.org/fhir" value="{$loc/fhir:description}"/>
            following $loc/fhir:name
        , update insert 
                <mode xmlns="http://hl7.org/fhir" value="insatnce"/>
            following $loc/fhir:description
        , update replace $loc/fhir:extension[@url='#room-type'] with
            <type>
                <coding>
                    <system value="http://hl7.org/fhir/ValueSet/v3-ServiceDeliveryLocationRoleType"/>
                    <code value="{$type}"/>
                    <display value="{$disp}"/>
                </coding>
                <text value="{$disp}"/>                
            </type>
        , update replace $loc/fhir:identifier with
            <identifier xmlns="http://hl7.org/fhir">
                <use value="official"/>
                <type value="PRN"/>
                <system value="#medfac"/>
                { $loc/fhir:identifier/fhir:value }
            </identifier>
        , update value $loc/fhir:managingOrganization/fhir:reference/@value with "metis/organizations/kikl-spzn"
        , update value $loc/fhir:managingOrganization/fhir:display/@value with "nSPZ"
        ))
};