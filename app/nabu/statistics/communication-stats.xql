xquery version "3.1";
declare namespace fhir= "http://hl7.org/fhir";

declare function local:stat($c,$base)
{
    let $coll := collection(concat($base,'/',$c))
    let $total  := count($coll/fhir:Communication)
    let $in-progress := $coll/fhir:Communictions[fhir:status[@value='in-progress']]
    let $printing    := $coll/fhir:Communication[fhir:status[@value='printing']]
    let $printed     := $coll/fhir:Communication[fhir:status[@value='printed']]
return
    <coll name="{$c}" total="{$total}">
        <in-progress value="{count($in-progress)}"/>
        <printing value="{count($printing)}"/>
        <printed value="{count($printed)}"/>"
    </coll>
};

let $base := '/db/apps/nabuCommunication/data'
let $years := for $year in (2016 to 2021)
        return
            xs:string($year)
let $colls := ($years,'invalid')

return
    <encounters>
{
      local:stat("",$base)
    , for $c in $colls
      return
        local:stat($c,$base)
}
</encounters>