xquery version "3.1";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

declare function local:deleteEoC($eocs,$pid)
{
    let $eoc := $eocs/fhir:EpisodeOfCare[fhir:subject/fhir:reference[@value=concat('nabu/patients/',$pid)]]
    return
        if ($eoc)
        then
            system:as-user('vdba', 'kikl823!', xmldb:remove("/db/apps/nabuCom/data/EpisodeOfCares",concat($eoc/@xml:id,'.xml')))
        else ()
};

declare function local:deleteCT($cts,$pid)
{
    let $ct := $cts/fhir:CareTeam[fhir:subject/fhir:reference[@value=concat('nabu/patients/',$pid)]]
    return
        if ($ct)
        then
            system:as-user('vdba', 'kikl823!', xmldb:remove("/db/apps/nabuCom/data/CareTeams",concat($ct/@xml:id,'.xml')))
        else ()
};

let $pats := (
        <patient id="p-ed0da517-85fd-4633-9813-277597500307" name="Hernichel"/>
        , <patient id="p-bfc7ba7f-98c6-4442-8cff-3faf27156fb3" name="Sorbilli"/>
        , <patient id="p-8b0f44eb-bea2-4a31-a430-e169a42b39b5" name="Botten"/>
        , <patient id="p-eea27aa6-372b-41ed-b0ff-309a703ad6ff" name="Sommer">
            <id xmlns="http://hl7.org/fhir" value="c-ad8fcd9e-afe4-4159-a1c3-3e607b00c09a"/>
          </patient>
        , <patient id="p-2680365f-2bf6-4dc9-86a8-1084ce1d7b62" name="Kavur">
            <id xmlns="http://hl7.org/fhir" value="c-68650283-8c9a-4f72-b522-380094ea0853"/>
          </patient>
        , <patient id="p-3e14a94e-49a3-4a13-a5eb-0141792cb49a" name="Puscinski">
            <id xmlns="http://hl7.org/fhir" value="c-a2926fd8-28f2-4517-a3d9-03c907a66aa0"/>
          </patient>
        , <patient id="p-b5e601ba-6c8d-4ef5-a14e-bdebf1a44b24" name="Sobisz">
    <id xmlns="http://hl7.org/fhir" value="c-5546c4f7-9af4-4523-b4d1-ce03b6e8de04"/>
</patient>
)
let $ec := collection('/db/apps/nabuData/data/FHIR/Patients')
let $cts := collection('/db/apps/nabuCom/data/CareTeams')
let $eocs := collection('/db/apps/nabuCom/data/EpisodeOfCares')

let $realm := 'kikl-spz'
let $now := current-dateTime()
for $pid in $pats/@id/string()
let $patient := $ec/fhir:Patient[fhir:id[@value=$pid]]

let $deleoc := local:deleteEoC($eocs, $pid)
let $delct  := local:deleteCT($cts, $pid)

return
    $pid