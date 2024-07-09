xquery version "1.0";
(:
    Copyright © ART-DECOR Expert Group and ART-DECOR Open Tools
    see https://art-decor.org/mediawiki/index.php?title=Copyright
    
    Author: Gerrit Boers
    
    This program is free software; you can redistribute it and/or modify it under the terms of the
    GNU Lesser General Public License as published by the Free Software Foundation; either version
    2.1 of the License, or (at your option) any later version.
    
    This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
    without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU Lesser General Public License for more details.
    
    The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
:)
import module namespace get ="http://art-decor.org/ns/art-decor-settings" at "../../../art/modules/art-decor-settings.xqm";
(:let $clamlDataCollection := 'atc-data':)
(:let $clamlDataCollection := 'icf-data':)
(:let $clamlDataCollection := 'icd10-data':)
(:let $clamlDataCollection := 'loinc-claml':)

let $clamlDataCollection := 'hl7-data'

let $collections := 
    for $claml in collection(concat($get:strTerminologyData,'/',$clamlDataCollection))//ClaML
    let $denormalizedCollection := concat(substring-before(util:collection-name($claml),'/claml'),'/denormalized')
    return
        $denormalizedCollection
   
for $classification in collection($collections)//ClaML-denormalized
let $currentRootClass := update delete $classification/Class[@name='rootClass']
let $class            :=
    <Class code="rootClass">
    {
        for $subClass in $classification//Class[not(SuperClass)]
        return
        <SubClass subCount="{count($subClass/SubClass)}">
        {
            $subClass/@*,
            $subClass/Rubric[@kind='preferred']
        }
        </SubClass>
    }
        <Rubric kind="preferred">
            <Label xml:lang="nl">{$classification/Title/@name/string()}</Label>
        </Rubric>
        <Rubric kind="description">
            <Label xml:lang="nl">{$classification/Title/text()}</Label>
        </Rubric>
    </Class>
return
    update insert $class following $classification//Title
 
 
