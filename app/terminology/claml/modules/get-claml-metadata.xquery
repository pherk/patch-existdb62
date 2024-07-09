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
let $classificationId := request:get-parameter('classificationId','')
let $language :='nl-NL'
(:let $classificationId := '2.16.840.1.113883.6.73':)



   
let $classificationIndex := doc(concat($get:strTerminology,'/claml/classification-index.xml'))/classificationIndex
let $classification :=$classificationIndex//classification[@id=$classificationId]


let $collection := 
   if (count($classification)>1) then
      if ($classification/@language=$language) then
         concat($classification[@language=$language]/@collection,'/denormalized')
      else(concat($classification[1]/@collection,'/denormalized'))
   else(concat($classification/@collection,'/denormalized'))

let $claml :=collection($collection)//ClaML-denormalized[Identifier/@uid=$classificationId]
return
<info>
{
$claml/Title,
$claml/Meta
}
</info>
(:$classification:)


