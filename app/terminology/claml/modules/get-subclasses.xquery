xquery version "1.0";
(:
    Copyright © ART-DECOR Expert Group and ART-DECOR Open Tools
    see https://art-decor.org/mediawiki/index.php?title=Copyright
    
    Author: Gerrit Boers, Alexander Henket
    
    This program is free software; you can redistribute it and/or modify it under the terms of the
    GNU Lesser General Public License as published by the Free Software Foundation; either version
    2.1 of the License, or (at your option) any later version.
    
    This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
    without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU Lesser General Public License for more details.
    
    The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
:)
import module namespace get   ="http://art-decor.org/ns/art-decor-settings" at "../../../art/modules/art-decor-settings.xqm";
import module namespace claml = "http://art-decor.org/ns/terminology/claml" at "../api/api-claml.xqm";

(:let $mode                   := if (request:exists()) then request:get-parameter('mode','html') else ('html'):)
let $mode                   := 'xml'
let $statusCodes            := tokenize(normalize-space(request:get-parameter('statusCode','active')),'\s')
let $classificationId       := if (request:exists()) then request:get-parameter('classificationId','') else ()
let $code                   := if (request:exists()) then request:get-parameter('code','') else ()
let $language               := if (request:exists()) then request:get-parameter('language','') else ('nl-NL')
(:let $classificationId     := '2.16.840.1.113883.6.73'
let $code                   := '':)

let $preparedClasses        := claml:getPreparedSubClasses($statusCodes, $classificationId, $code, $language)

return
    if ($mode='xml') then (
        <result>{$preparedClasses}</result>
    )
    else (
        response:set-header('Content-Type','text/html; charset=utf-8'),
        claml:classToHtml(<result>{$preparedClasses}</result>)
    )