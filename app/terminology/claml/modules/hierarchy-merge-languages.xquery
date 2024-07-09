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
let $primaryFileName := 'icd102010en-hierarchy.xml'
let $secondaryFileName := 'ICD-10-v2006-def-nl-hierarchy.xml'

let $primary :=doc(concat('/db/apps/terminology/claml/hierarchy/',$primaryFileName))
let $secondary :=doc(concat('/db/apps/terminology/claml/hierarchy/',$secondaryFileName))

let $primaryNotInSecondary :=
    for $class in $primary//Class
    return
        if (not($secondary//Class[@code=$class/@code])) then
            $class
        else()
        
        let $secondaryNotInPrimary :=
    for $class in $secondary//Class
    return
        if (not($primary//Class[@code=$class/@code])) then
            $class
        else()

return
$secondaryNotInPrimary
