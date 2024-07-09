xquery version "3.0";
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
module namespace claml      = "http://art-decor.org/ns/terminology/claml";

import module namespace get         = "http://art-decor.org/ns/art-decor-settings" at "../../../art/modules/art-decor-settings.xqm";
import module namespace adserver    = "http://art-decor.org/ns/art-decor-server" at "../../../art/api/api-server-settings.xqm";

declare namespace expath            = "http://expath.org/ns/pkg";

declare variable $claml:root                        := repo:get-root();
declare variable $claml:denormalizationStylesheet   := xs:anyURI(concat('xmldb:exist://',$get:strTerminology,'/claml/resources/stylesheets/ClaML-2-denormalized.xsl'));
declare variable $claml:descriptionsStylesheet      := xs:anyURI(concat('xmldb:exist://',$get:strTerminology,'/claml/resources/stylesheets/ClaML-2-descriptions.xsl'));
declare variable $claml:classHtmlStylesheet         := xs:anyURI(concat('xmldb:exist://',$get:strTerminology,'/claml/resources/stylesheets/class2html.xsl'));

declare function claml:getPackages() as element(package)* {
    for $package in xmldb:get-child-collections($get:strTerminologyData)
    return
        if (collection(concat($get:strTerminologyData,'/',$package))//ClaML) then
            <package>{$package}</package>
        else ()
};

declare function claml:createDescriptionsFile($package as xs:string) as element(result) {
    if (empty($package)) then
        <result>
            <error>Missing parameter 'package' with any of these packages:</error>
        {
            claml:getPackages()
        }
        </result>
    else (
        <result>
            <success/>
        {
            for $claml in collection(concat($get:strTerminologyData,'/',$package))//ClaML
            let $resultFile                 := concat(substring-before(util:document-name($claml),'.xml'),'-descriptions.xml')
            let $resultCollection           := concat(util:collection-name($claml),'/../descriptions')
            let $mkdir                      := xmldb:create-collection(util:collection-name(util:collection-name($claml)), 'descriptions')
            let $resultContent              := transform:transform($claml,$claml:descriptionsStylesheet,<parameters/>)
            let $update                     := xmldb:store($resultCollection,$resultFile,$resultContent)
            return
                <path>{$update}</path>
        }
        </result>
    )
};

declare function claml:createDenormalizedFile($package as xs:string) as element(result) {
    if (empty($package)) then
        <result>
            <error>Missing parameter 'package' with any of these packages:</error>
        {
            claml:getPackages()
        }
        </result>
    else (
        <result>
            <success/>
        {
            for $claml in collection(concat($get:strTerminologyData,'/',$package))//ClaML
            let $language               := claml:getClassificationIndexMeta($claml/Identifier/@uid)[1]/@language
            let $xsltParameters         :=
                <parameters>
                    <param name="language" value="{$language}"/>
                </parameters>
            let $resultFile                 := concat(substring-before(util:document-name($claml),'.xml'),'-denormalized.xml')
            let $resultCollection           := concat(util:collection-name($claml),'/../denormalized')
            let $mkdir                      := xmldb:create-collection(util:collection-name(util:collection-name($claml)), 'denormalized')
            let $resultContent              := transform:transform($claml,$claml:denormalizationStylesheet,$xsltParameters)
            let $update                     := xmldb:store($resultCollection,$resultFile,$resultContent)
            return
                <path>{$update}</path>
        }
        </result>
    )
};

declare function claml:getClassificationIndexMeta($classificationId as xs:string) as element(classification)? {
let $classificationIndex    := doc(concat($get:strTerminology,'/claml/classification-index.xml'))/classificationIndex
return
    $classificationIndex//classification[@id=$classificationId]
};

declare function claml:getPreparedClass($classificationId as xs:string, $code as xs:string?, $language as xs:string) as element(Class)? {
    claml:getPreparedClass((), $classificationId, $code, $language)
};

declare function claml:getPreparedClass($statusCodes as xs:string*, $classificationId as xs:string, $code as xs:string?, $language as xs:string) as element(Class)? {
let $classification         := claml:getClassificationIndexMeta($classificationId)

let $classificationPath     := 
    if ($classification[@language=$language]) then
        concat($classification[@language=$language][1]/@collection,'/denormalized')
    else (
        concat($classification[1]/@collection,'/denormalized')
    )

let $classes                := collection($classificationPath)//ClaML-denormalized[Identifier/@uid=$classificationId]

let $class                  :=
    if (string-length($code)=0) then
        $classes/Class[@code='rootClass']
    else (
        $classes/Class[@code=$code]
    )
let $class                  :=
    if (empty($statusCodes)) then
        $class
    else (
        $class[not(Meta[@name='statusCode'])] | $class[Meta[@name='statusCode'][@value=$statusCodes]]
    )

return
    if (empty($class)) then (
        (:nothing to return:)
    ) else (
        <Class code="{$class/@code[not(.='rootClass')]}" classificationId="{$classificationId}">
        {
            $class/@kind | $class/Meta | $class/SuperClass
            ,
            if (empty($statusCodes)) then
                $class/SubClass
            else (
                $class/SubClass[not(Meta[@name='statusCode'])] | $class/SubClass[Meta[@name='statusCode'][@value=$statusCodes]]
            )
            ,
            $class/Rubric
        }
        </Class>
    )
};

declare function claml:getPreparedSubClasses($statusCodes as xs:string*, $classificationId as xs:string, $code as xs:string?, $language as xs:string) as element(Class)* {
let $classification         := claml:getClassificationIndexMeta($classificationId)

let $classificationPath     := 
    if ($classification[@language=$language]) then
        concat($classification[@language=$language][1]/@collection,'/denormalized')
    else (
        concat($classification[1]/@collection,'/denormalized')
    )

let $classes                := collection($classificationPath)//ClaML-denormalized[Identifier/@uid=$classificationId]

let $subclasses             := 
    if (string-length($code)=0) then
        $classes//Class[not(SuperClass)][not(@code='rootClass')]
    else(
        $classes//Class[SuperClass/@code=$code]
    )
let $subclasses             :=
    if (empty($statusCodes)) then
        $subclasses
    else (
        $subclasses[not(Meta[@name='statusCode'])] | $subclasses[Meta[@name='statusCode'][@value=$statusCodes]]
    )

for $class in $subclasses
return
    <Class code="{$class/@code[not(.='rootClass')]}" classificationId="{$classificationId}">
    {
        $class/@kind | $class/Meta | $class/SuperClass
        ,
        if (empty($statusCodes)) then
            $class/SubClass
        else (
            $class/SubClass[not(Meta[@name='statusCode'])] | $class/SubClass[Meta[@name='statusCode'][@value=$statusCodes]]
        )
        ,
        $class/Rubric
    }
    </Class>
};

declare function claml:classToHtml($preparedClass as element(Class)) as element(html) {
let $xsltParameters         :=
    <parameters>
        <param name="serverUrl" value="{adserver:getServerURLArt()}"/>
    </parameters>
    
return
    transform:transform($preparedClass,$claml:classHtmlStylesheet,$xsltParameters)
};

declare function claml:getClaMLIndex() as element(classificationIndex) {
let $collections        := xmldb:get-child-collections($get:strTerminologyData)

return
    <classificationIndex>
    {
        for $child in $collections
        let $languageCollections := xmldb:get-child-collections(concat($get:strTerminologyData,'/',$child))
        let $clamlCount     := 
            for $languageCollection in $languageCollections
            return
                count(collection(concat($get:strTerminologyData,'/',$child,'/',$languageCollection))//ClaML)
        let $clamls         := collection(concat($get:strTerminologyData,'/',$child))//ClaML
        let $packageTitle   := collection(concat($get:strTerminologyData,'/',$child))//expath:package/expath:title/text()
        let $name           := local:cleanupTerminologyName($packageTitle)
        order by lower-case($name)
        return
            if ($clamls) then
                <group collection="{$child}" name="{$name}" isGroup="{every $count in $clamlCount satisfies $count>1}">
                {
                    for $claml in $clamls
                    let $language   := substring-after(substring-before(util:collection-name($claml),'/claml'),concat($get:strTerminologyData,'/',$child,'/'))
                    order by $claml/Title/lower-case(@name)
                    return
                    <classification id="{$claml/Identifier[1]/@uid}"  collection="{concat($get:strTerminologyData,'/',$child,'/',$language)}" package="{$child}" language="{$language}">
                    {
                        $claml/Title/@*,
                        $claml/Title/text()
                    }
                    </classification>
                }
                </group>
            else()
    }
    </classificationIndex>
};

declare function claml:createClaMLIndex() {

let $classifications    := claml:getClaMLIndex()
let $storeIndex         := xmldb:store(concat($get:strTerminology,'/claml'),'classification-index.xml',$classifications)

return
    <result index="{$storeIndex}" codeSystems="{count($classifications//classification)}"/>
};

declare %private function local:cleanupTerminologyName($s as xs:string?) as xs:string? {
    if (empty($s)) then () else (
        replace(replace($s,'\s*[Tt]erminology\s*[Ds]ata\s*-\s*',''),' [Dd]ata$','')
    )
};
