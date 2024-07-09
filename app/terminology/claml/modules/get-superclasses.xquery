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
(:let $classification := request:get-parameter('classification','')
let $code := request:get-parameter('code',''):)
let $classification := 'ATC-NL'
let $request := 'N05BA06 N05BA21'
let $codes := tokenize($request,'\s')
let $classifications :=
   <classifications>
   {
      for $child in xmldb:get-child-collections($get:strTerminologyData)
      let $title := collection(concat($get:strTerminologyData,'/',$child))//ClaML/Title
      return
      if ($title) then
      <classification collection="{$child}">
      {$title}
      </classification>
      else()
   }
   </classifications>

let $collection := 
   if (string-length($classification)>0) then
      concat($get:strTerminologyData,'/',$classifications/classification[Title/@name=$classification]/@collection,'/hierarchy')
   else(
      concat($get:strTerminologyData,'/',$classifications/classification[1]/@collection,'/hierarchy')
   )

let $parents :=  collection($collection)//Class[SubClass/@code=$codes]


return
<parents>
{
   for $parent in $parents
   where  every $id in $codes satisfies $id=$parent/SubClass/@code
   return
   $parent
}
</parents>


