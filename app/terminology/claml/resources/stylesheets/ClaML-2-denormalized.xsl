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
   Stylesheet for creating extract of ClaML file for navigation purposes.
   - Adds the Rubric[@kind=preferred'] to all SubClasses.
   - Element not needed for navigating the hierarchy are removed.
--><xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
    <xsl:output method="xml" indent="yes" exclude-result-prefixes="#all" encoding="UTF-8"/>
    <xsl:param name="language" select="if (/ClaML//@xml:lang) then (/ClaML//@xml:lang)[1] else 'en-US'"/>
    <xsl:key name="classCode" match="Class" use="@code"/>
    <xsl:variable name="UsageKinds" select="/ClaML/UsageKinds/UsageKind" as="element()*"/>
    <xsl:variable name="RubricKinds" select="/ClaML/RubricKinds/RubricKind" as="element()*"/>
    <xsl:template match="/ClaML">
        <!-- make root element different -->
        <ClaML-denormalized>
            <!-- include Meta elements -->
            <xsl:copy-of copy-namespaces="no" select="Meta"/>
            <!-- include Identifier and Title element -->
            <xsl:copy-of copy-namespaces="no" select="Identifier | Title"/>
            <!-- Build rootClass -->
            <Class code="rootClass">
                <xsl:for-each select="Class[not(SuperClass)]">
                    <SubClass subCount="{count(SubClass)}">
                        <xsl:copy-of copy-namespaces="no" select="@*"/>
                        <xsl:copy-of copy-namespaces="no" select="Meta[@name = 'statusCode']"/>
                        <xsl:apply-templates select="Rubric[@kind = 'preferred']"/>
                    </SubClass>
                </xsl:for-each>
                <Rubric kind="preferred">
                    <Label xml:lang="{$language}">
                        <xsl:value-of select="Title/@name"/>
                    </Label>
                </Rubric>
                <Rubric kind="description">
                    <Label xml:lang="{$language}">
                        <xsl:value-of select="Title"/>
                    </Label>
                </Rubric>
            </Class>
            <!-- include all Class elements -->
            <xsl:for-each select="Class">
                <Class code="{@code}" kind="{@kind}">
                    <xsl:if test="@usage">
                        <xsl:variable name="theUsage" select="@usage"/>
                        <xsl:variable name="theUsageMark" select="$UsageKinds[@name = $theUsage]/@mark"/>
                        <xsl:attribute name="usage" select="$theUsage"/>
                        <xsl:attribute name="usageMark" select="$theUsageMark"/>
                    </xsl:if>
                    <!-- include Meta elements -->
                    <xsl:for-each select="Meta">
                        <xsl:copy-of copy-namespaces="no" select="."/>
                    </xsl:for-each>
                    <!-- copy SuperClass elements and include the preferred Label -->
                    <xsl:for-each select="SuperClass">
                        <SuperClass code="{@code}">
                            <xsl:if test="key('classCode', @code)/@usage">
                                <xsl:variable name="theUsage" select="key('classCode', @code)/@usage"/>
                                <xsl:variable name="theUsageMark" select="$UsageKinds[@name = $theUsage]/@mark"/>
                                <xsl:attribute name="usage" select="$theUsage"/>
                                <xsl:attribute name="usageMark" select="$theUsageMark"/>
                            </xsl:if>
                            <xsl:copy-of copy-namespaces="no" select="key('classCode', @code)/Meta[@name = 'statusCode']"/>
                            <xsl:apply-templates select="key('classCode', @code)/Rubric[@kind = 'preferred']"/>
                        </SuperClass>
                    </xsl:for-each>
                    <!-- cope all SubClasses, include the preferred Label and and SubClass count -->
                    <xsl:for-each select="SubClass">
                        <SubClass code="{@code}" subCount="{count(key('classCode',@code)/SubClass)}">
                            <xsl:if test="key('classCode', @code)/@usage">
                                <xsl:variable name="theUsage" select="key('classCode', @code)/@usage"/>
                                <xsl:variable name="theUsageMark" select="$UsageKinds[@name = $theUsage]/@mark"/>
                                <xsl:attribute name="usage" select="$theUsage"/>
                                <xsl:attribute name="usageMark" select="$theUsageMark"/>
                            </xsl:if>
                            <xsl:copy-of copy-namespaces="no" select="key('classCode', @code)/Meta[@name = 'statusCode']"/>
                            <xsl:apply-templates select="key('classCode', @code)/Rubric[@kind = 'preferred']"/>
                        </SubClass>
                    </xsl:for-each>
                    <!-- copy all rubrics-->
                    <xsl:apply-templates select="Rubric"/>
                </Class>
            </xsl:for-each>
        </ClaML-denormalized>
    </xsl:template>
    <xsl:template match="Rubric">
        <xsl:variable name="rubricKind" select="@kind"/>
        <xsl:copy copy-namespaces="no">
            <xsl:copy-of select="@*" copy-namespaces="no"/>
            <xsl:copy-of select="$RubricKinds[@name = $rubricKind]/Display" copy-namespaces="no"/>
            <xsl:copy-of select="node()" copy-namespaces="no"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>