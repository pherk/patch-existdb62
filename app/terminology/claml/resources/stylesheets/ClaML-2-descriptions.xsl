<?xml version="1.0" encoding="UTF-8"?>
<!--
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
--><!-- 
   Stylesheet for creating descriptions file for full text search
--><xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
    <xsl:output method="xml" indent="yes" exclude-result-prefixes="#all" encoding="UTF-8"/>
    <xsl:key name="classCode" match="Class" use="@code"/>
    <!-- <UsageKind name="etiology" mark="+"/> -->
    <xsl:variable name="UsageKinds" select="/ClaML/UsageKinds/UsageKind" as="element()*"/>
    <xsl:template match="/ClaML">
      <!-- descriptions -->
        <descriptions>
           <!-- first classification identifier -->
            <xsl:variable name="classificationId" select="Identifier[1]/@uid"/>
            <xsl:variable name="classificationName" select="Title/@name"/>
         <!-- get descriptions from classes -->
            <xsl:for-each select="Class">
                <!-- assume active concepts if not given -->
                <xsl:variable name="statusCode">
                    <xsl:choose>
                        <xsl:when test="Meta[@name='statusCode']">
                            <xsl:value-of select="(Meta[@name='statusCode']/@value)[1]"/>
                        </xsl:when>
                        <xsl:otherwise>active</xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="superClasses">
                    <xsl:for-each select="SuperClass">
                        <name>
                            <xsl:value-of select="key('classCode',@code)/Rubric[@kind='preferred']/Label"/>
                        </name>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="classCode" select="@code"/>
                <xsl:variable name="usage" select="@usage"/>
                <xsl:variable name="usageMark" select="$UsageKinds[@name=$usage]/@mark"/>
                <xsl:for-each select="Rubric[@kind = ('preferred', 'relatedTerm')]">
                    <xsl:for-each select="Label">
                        <description count="{count(tokenize(.,'\s'))}" length="{string-length(.)}" conceptId="{$classCode}" type="pref" language="{@xml:lang}" superClasses="{string-join($superClasses/name,', ')}" classificationId="{$classificationId}" classificationName="{$classificationName}" statusCode="{$statusCode}">
                            <xsl:if test="$usage">
                                <xsl:attribute name="usageMark" select="$usageMark"/>
                            </xsl:if>
                            <xsl:value-of select="string-join(descendant::text(), ' ')"/>
                        </description>
                    </xsl:for-each>
                </xsl:for-each>
            </xsl:for-each>
        </descriptions>
    </xsl:template>
</xsl:stylesheet>