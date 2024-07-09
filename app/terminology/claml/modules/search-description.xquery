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
import module namespace adsearch       = "http://art-decor.org/ns/terminology/search" at "../../api/api-terminology-search.xqm";

let $classificationId   := if (request:exists()) then request:get-parameter('classificationId','') else ('2.16.840.1.113883.6.3.2')
let $searchLanguage     := if (request:exists()) then request:get-parameter('language','nl-NL') else ('nl-NL')
let $searchString       := if (request:exists()) then util:unescape-uri(request:get-parameter('string',''),'UTF-8') else ()
let $statusCodes        := if (request:exists()) then tokenize(normalize-space(request:get-parameter('statusCode','active')),'\s') else ()
let $searchScope        := if (request:exists()) then tokenize(normalize-space(request:get-parameter('scope','description')),'\s') else ()
(:let $classification   :='':)
(:let $searchString     :='ana eig':)

return
    adsearch:searchClamlConcept($classificationId, $searchLanguage, $searchString, $adsearch:maxResults, $statusCodes, $searchScope)