xquery version "3.1";

declare namespace fhir= "http://hl7.org/fhir";

declare function local:subscales($tables)
{
<table>
    {
for $t in $tables
let $no := local-name($t/*[1])
order by $no
return
    let $agerange := $t/*[1]/F1/string()
    let $toks := tokenize($agerange,'[,;-]')
    let $low := xs:int($toks[1])*30 + xs:int($toks[2])
    let $high := xs:int($toks[3])*30 + xs:int($toks[4])
    let $rows := for $row in subsequence($t/*,3)
        return
            local:subscalerow($row,$t/*[2])
    return
    <subtable>
            <id value="{concat('A1:',replace($agerange,',',';'))}"/>
            <age>
                <low value="{$low}"/>
                <high value="{$high}"/>
            </age>
            <gender value="unisex"/>
            { $rows }
    </subtable>
    }
</table>
};

declare function local:subscalerow(
      $row as item()
    , $idrow as item()
    ) as element(row)
{
    <row>
        {
            for $n in (1 to count($idrow/*))
            return
                if ($n=1)
                then
                    let $sub := $row/*[1]/string()
                    return
                        <subscale value="{$sub}"/>
                else
                    let $id := $idrow/*[$n]
                    let $range := local:range($row/*[local-name(.)=local-name($id)])
                    return
                        <raw>
                            <id value="{$id}"/>
                            <low value="{$range[1]}"/>
                            <high value="{if ($range[2]) then $range[2] else $range[1]}"/>
                        </raw>
        }
    </row>
};

declare function local:range($val)
{
    tokenize($val,'-')    
};

declare function local:devage($t)
{
    let $idrow := $t/*[1]
    let $id := local-name($idrow)
    return
        <table>
            <id value="{$id}"/>   
        { 
            for $row in subsequence($t/*,2)
            return
            local:devagerow($row,$idrow)
        }
        </table>
};

declare function local:devagerow($row, $idrow)
{
    <row>
        {
            for $n in (1 to count($idrow/*))
            return
                if ($n=1)
                then
                    let $devage := $row/*[1]/string()
                    return
                        <devage value="{$devage}"/>
                else
                    let $id := $idrow/*[$n]
                    let $range := local:range($row/*[local-name(.)=local-name($id)])
                    return
                        <raw>
                            <id value="{$id}"/>
                            <low value="{$range[1]}"/>
                            <high value="{if ($range[2]) then $range[2] else $range[1]}"/>
                        </raw>
        }
    </row>
};

declare function local:cstables(
      $tables as item()*
    )
{
    for $t in $tables
    let $idrow := $t/*[1]
    let $id := local-name($idrow)
    order by $id
    return
        <table>
            <id value="{$id}"/>   
        { 
            for $row in subsequence($t/*,2)
            return
            local:csrow($row,$idrow)
        }
        </table>
};

declare function local:csrow($row, $idrow)
{
    <row>
        {
            for $n in (1 to count($idrow/*))
            return
                if ($n=1)
                then
                    let $scale := $row/*[1]/string()
                    return
                        <scale value="{$scale}"/>
                else
                    let $id := $idrow/*[$n]
                    return
                        <output>
                            <id value="{$id}"/>
                            <value value="{$row/*[local-name(.)=local-name($id)]}"/>
                        </output>
        }
    </row>
};

let $subtables   := collection('/db/apps/golem/data/import/BayleyIII')/subtable
let $devagetable := collection('/db/apps/golem/data/import/BayleyIII')/table[exists(develop-age)]
let $cstables    := collection('/db/apps/golem/data/import/BayleyIII')/table[not(develop-age)]

let $realm := 'kikl-spz'
let $loguid := 'u-admin'
let $lognam := 'Admin'

return
    <tables>
    {
      local:subscales($subtables)
    , local:devage($devagetable)
    , local:cstables($cstables)
    }
    </tables>