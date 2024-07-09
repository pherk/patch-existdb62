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
import module namespace claml = "http://art-decor.org/ns/terminology/claml" at "xmldb:exist:///db/apps/terminology/claml/api/api-claml.xqm";

(:let $clamlDataCollection := 'atc-data':)

(:let $clamlDataCollection := 'icf-data':)

(:let $clamlDataCollection := 'icd10-data':)

(:let $clamlDataCollection := 'hl7-data':)

(:let $clamlDataCollection := 'loinc-claml':)

let $clamlDataCollection        := if (request:exists()) then request:get-parameter('package',()) else ('icpc-1-nl-data')
return
    claml:createDescriptionsFile($clamlDataCollection)