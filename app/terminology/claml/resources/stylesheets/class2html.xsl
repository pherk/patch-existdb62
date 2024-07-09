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
    DISCLAIMER
    Deze stylesheet en de resulterende html weergave van xml berichten zijn uitsluitend bedoeld voor testdoeleinden.
    Zij zijn uitdrukkelijk niet bedoeld voor gebruik in de medische praktijk.
    
    Auteur: Gerrit Boers
    Copyright: Nictiz
    
    Boxover javascript door http://boxover.swazz.org
    (BoxOver is free and distributed under the GNU license)
--><xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:hl7="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" exclude-result-prefixes="hl7" version="2.0">
    <xsl:output method="html" exclude-result-prefixes="#all" encoding="UTF-8"/>
    <xsl:param name="serverUrl"/>
    
    <!-- temporary solution for looking up label text for Rubric kind -->
    <xsl:variable name="rubricKindLabels">
        <RubricKind name="preferred"/>
        <RubricKind name="preferredLong"/>
        <RubricKind name="text"/>
        <RubricKind name="introduction"/>
        <!--<RubricKind name="definition">
            <Display xml:lang="nl">Definitie</Display>
        </RubricKind>
        <RubricKind name="description">
            <Display xml:lang="nl">Omschrijving</Display>
        </RubricKind>
        <RubricKind name="relatedTerm">
            <Display xml:lang="nl">Neventermen</Display>
        </RubricKind>
        <RubricKind name="remark">
            <Display xml:lang="nl">Opmerkingen</Display>
        </RubricKind>
        <RubricKind name="inclusion">
            <Display xml:lang="nl">Inclusies</Display>
        </RubricKind>
        <RubricKind name="exclusion">
            <Display xml:lang="nl">Exclusies</Display>
        </RubricKind>
        <RubricKind name="modifierlink"/>
        <RubricKind name="includeDescendants">
            <Display xml:lang="nl">Subklassen</Display>
        </RubricKind>
        <RubricKind name="asteriskHead">
            <Display xml:lang="nl">Asterisk</Display>
        </RubricKind>
        <RubricKind name="asteriskCategory">
            <Display xml:lang="nl">Asterisk Categorieën</Display>
        </RubricKind>
        <RubricKind name="coding-hint">
            <Display xml:lang="nl">Aanwijzingen</Display>
        </RubricKind>
        <RubricKind name="footnote">
            <Display xml:lang="nl">Voetnoot</Display>
        </RubricKind>
        <RubricKind name="note"/>-->
    </xsl:variable>
    <xsl:variable name="classificationId" select="/Class/@classificationId"/>
    <xsl:template match="/">
        <html>
            <head>
                <!-- Javascript voor tonen/verbergen van elementen
                     toggled is de id van het te tonen/verbergen element
                     toggler de id van het element dat als trigger dient
                -->
                <script type="text/javascript">
                    function toggle(toggled,toggler) {
                    if (document.getElementById) {
                    var currentStyle = document.getElementById(toggled).style;
                    var togglerStyle = document.getElementById(toggler).style;
                    if (currentStyle.display == "block"){
                    currentStyle.display = "none";
                    togglerStyle.backgroundImage = "url(../css/trClosed.gif)";
                    } else {
                    currentStyle.display = "block";
                    togglerStyle.backgroundImage = "url(../css/triangleOpen.gif)";
                    }
                    return false;
                    } else {
                    return true;
                    }
                    }
                </script>
                <style type="text/css" media="print, screen">
                    body{
                        font-family: Verdana, Arial, sans-serif;
                        font-size: 12px;
                    }
                    h2{
                        font-size:18px;
                        font-weight:bold;
                        margin-left:0px;
                        margin-right:0px;
                        margin-top:4px;
                        margin-bottom:8px;
                        background-color:#ece9e4;
                        color:#e16e22;
                        width:auto;
                    }
                    h3{
                        background-color:inherit;
                        font-size:1.1em;
                        font-weight:bold;
                        padding-right:1em;
                        padding-top:0em;
                        padding-bottom:0em;
                        margin-top:1em;
                        margin-bottom:0em;
                        border-bottom:solid 1px #d7b0c6;
                    }
                    table{
                        width:100%;
                        border-spacing:0px;
                        font-family: Verdana, Arial, sans-serif;
                        font-size: 12px;
                    }
                    p.heading{
                        width:100%;
                        border-spacing:0px;
                        font-family: Verdana, Arial, sans-serif;
                        font-size: 12px;
                        font-weight:bold;
                    }
                    td{
                        text-align:left;
                        vertical-align:top;
                    }
                    td.parent{
                        text-align:center;
                        vertical-align:top;
                        padding-left:1em;
                        padding-right:1em;
                        padding-top:0em;
                        padding-bottom:0em;
                    }
                    td.child{
                        text-align:left;
                        vertical-align:top;
                        padding-left:1em;
                        padding-right:1em;
                        padding-top:0.3em;
                        padding-bottom:0.3em;
                    }
                    td.vertical-line{
                        text-align:center;
                        vertical-align:middle;
                    }
                    div.navigate{
                        border-radius:5px 5px;
                        -moz-border-radius:5px;
                        -webkit-border-radius:5px;
                        box-shadow:5px 5px 5px rgba(0, 0, 0, 0.1);
                        -webkit-box-shadow:5px 5px rgba(0, 0, 0, 0.1);
                        -moz-box-shadow:5px 5px rgba(0, 0, 0, 0.1);
                        background:#ebe7e1;
                        border:1px solid #e6aa83;
                        padding:0.5em;
                        width:80%;
                        margin:auto;
                    }
                    div.navigate-child{
                        border-radius:5px 5px;
                        -moz-border-radius:5px;
                        -webkit-border-radius:5px;
                        box-shadow:3px 3px 3px rgba(0, 0, 0, 0.1);
                        -webkit-box-shadow:3px 3px rgba(0, 0, 0, 0.1);
                        -moz-box-shadow:3px 3px rgba(0, 0, 0, 0.1);
                        background:#ebe7e1;
                        border:1px solid #e6aa83;
                        padding:0.2em;
                        padding-left:1em;
                        width:75%;
                        margin:auto;
                    }
                    div.concept{
                        border-radius:5px 5px;
                        -moz-border-radius:5px;
                        -webkit-border-radius:5px;
                        box-shadow:5px 5px 5px rgba(0, 0, 0, 0.1);
                        -webkit-box-shadow:5px 5px rgba(0, 0, 0, 0.1);
                        -moz-box-shadow:5px 5px rgba(0, 0, 0, 0.1);
                        background:#ebe7e1;
                        border:1px solid #e6aa83;
                        padding:0.5em;
                        margin:auto;
                    }
                    div.grp{
                        border-radius:5px 5px;
                        -moz-border-radius:5px;
                        -webkit-border-radius:5px;
                        background:#e3dfd9;
                        border:1px solid #e6aa83;
                        padding:0.2em;
                        padding-left:0.5em;
                        margin-left:1em;
                        margin-bottom:0.5em;
                    }
                    div.syn{
                        border-radius:5px 5px;
                        -moz-border-radius:5px;
                        -webkit-border-radius:5px;
                        background:#dad6d0;
                        padding:0.2em;
                        padding-left:0.5em;
                        margin-top:0.5em;
                        margin-bottom:0.5em;
                    }
                    span.subcount{
                        border-radius:5px 5px;
                        -moz-border-radius:5px;
                        -webkit-border-radius:5px;
                        background:#dad6d0;
                        margin-right:0.2em;
                        padding-left:0.2em;
                        padding-right:0.2em;
                        float:right;
                    }
                    span.codespan{
                        border-radius:5px 5px;
                        -moz-border-radius:5px;
                        -webkit-border-radius:5px;
                        background:#dad6d0;
                        margin-right:0.2em;
                        padding-left:0.2em;
                        padding-right:0.2em;
                        float:left;
                    }
                    td.normal{
                        text-align:left;
                        vertical-align:top;
                        padding-left:15px;
                        display:block;
                    }
                    td.indent{
                        text-align:left;
                        vertical-align:top;
                        padding-left:15px;
                    }</style>
            </head>
            <body>
                <xsl:apply-templates/>
            </body>
        </html>
    </xsl:template>
    <xsl:template match="Class">
        <xsl:variable name="statusCode" select="Meta[@name='statusCode']" as="element()?"/>
        <table>
            <!-- superclasses -->
            <tr>
                <td>
                    <table>
                        <tr>
                            <xsl:for-each select="SuperClass">
                                <td class="parent">
                                    <a href="{string-join(('ViewClass?classificationId=',$classificationId,'&amp;code=',@code),'')}">
                                        <div class="navigate">
                                            <xsl:value-of select="string-join((@code,@usageMark,' ',Rubric[@kind='preferred']/Label),'')"/>
                                        </div>
                                    </a>
                                </td>
                            </xsl:for-each>
                        </tr>
                        <tr>
                            <xsl:for-each select="SuperClass">
                                <td class="vertical-line"> | </td>
                            </xsl:for-each>
                        </tr>
                    </table>
                </td>
            </tr>
            <!-- focus class -->
            <tr>
                <td>
                    <div class="concept">
                        <table>
                            <tr>
                                <td>
                                    <h2>
                                        <xsl:if test="$statusCode">
                                            <img src="{$serverUrl}img/node-s{$statusCode/@value}.png" alt="{$statusCode/@value}" title="{$statusCode/@value}"/>
                                        </xsl:if>
                                        <xsl:value-of select="string-join((@code,@usageMark,' ',Rubric[@kind='preferred']/Label),'')"/>
                                    </h2>
                                    <p/>
                                    <xsl:if test="Meta">
                                        <table>
                                            <tr>
                                                <td>
                                                    <h3>
                                                        <i>Meta</i>
                                                    </h3>
                                                    <div>
                                                        <xsl:for-each-group select="Meta" group-by="@name">
                                                            <div style="float:left;margin-right: 1em;">
                                                                <xsl:value-of select="current-grouping-key()"/>
                                                                <xsl:text>: </xsl:text>
                                                            </div>
                                                            <xsl:for-each select="current-group()/.">
                                                                <div>
                                                                    <xsl:value-of select="@value"/>
                                                                </div>
                                                            </xsl:for-each>
                                                        </xsl:for-each-group>
                                                    </div>
                                                </td>
                                            </tr>
                                        </table>
                                    </xsl:if>
                                    <xsl:for-each-group select="Rubric" group-by="@kind">
                                        <xsl:if test="@kind!='preferred' and @kind!='asteriskHead'">
                                            <table>
                                                <tr>
                                                    <td>
                                                        <h3>
                                                            <xsl:choose>
                                                                <xsl:when test="$rubricKindLabels/RubricKind[@name=current-grouping-key()]/Display">
                                                                    <xsl:value-of select="$rubricKindLabels/RubricKind[@name=current-grouping-key()]/Display"/>
                                                                </xsl:when>
                                                                <xsl:when test="current-group()/Display">
                                                                    <xsl:value-of select="(current-group()/Display)[1]"/>
                                                                </xsl:when>
                                                                <xsl:otherwise>
                                                                    <xsl:value-of select="current-grouping-key()"/>
                                                                </xsl:otherwise>
                                                            </xsl:choose>
                                                        </h3>
                                                        <xsl:for-each select="current-group()">
                                                            <xsl:apply-templates select="Label"/>
                                                        </xsl:for-each>
                                                    </td>
                                                </tr>
                                            </table>
                                        </xsl:if>
                                    </xsl:for-each-group>
                                </td>
                            </tr>
                        </table>
                    </div>
                </td>
            </tr>
            <xsl:if test="SubClass">
                <tr>
                    <td class="vertical-line">|</td>
                </tr>
            </xsl:if>
            <!-- subclasses -->
            <xsl:for-each select="SubClass">
                <tr>
                    <td class="child">
                        <div class="navigate-child">
                            <a href="{string-join(('ViewClass?classificationId=',$classificationId,'&amp;code=',@code),'')}">
                                <xsl:value-of select="string-join((concat(@code,@usageMark),Rubric[@kind='preferred']/Label),' ')"/>
                            </a>
                            <xsl:if test="@subCount&gt;0">
                                <span class="subcount">
                                    <xsl:value-of select="@subCount"/>
                                </span>
                            </xsl:if>
                        </div>
                    </td>
                </tr>
            </xsl:for-each>
        </table>
    </xsl:template>
    <xsl:template match="IncludeDescendants">
        <xsl:for-each select="//SubClass">
            <br/>
            <a href="{string-join(('ViewClass?classificationId=',$classificationId,'&amp;code=',@code),'')}">
                <xsl:value-of select="@code"/>
                <xsl:value-of select="@usageMark"/>
            </a>
            <xsl:value-of select="string-join((' ',Rubric[@kind='preferred']/Label),'')"/>
        </xsl:for-each>
    </xsl:template>
    <xsl:template match="Label">
        <xsl:choose>
            <xsl:when test="Para">
                <xsl:apply-templates/>
            </xsl:when>
            <xsl:when test="Fragment[@type='list']">
                <ul>
                    <xsl:apply-templates/>
                </ul>
            </xsl:when>
            <xsl:otherwise>
                <div>
                    <xsl:apply-templates/>
                </div>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="Para">
        <p class="{@class}">
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="p">
        <p>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="b">
        <b>
            <xsl:apply-templates/>
        </b>
    </xsl:template>
    <xsl:template match="i">
        <i>
            <xsl:apply-templates/>
        </i>
    </xsl:template>
    <xsl:template match="ol">
        <ol>
            <xsl:apply-templates/>
        </ol>
    </xsl:template>
    <xsl:template match="li | Fragment[@type = 'list']">
        <li>
            <xsl:apply-templates/>
        </li>
    </xsl:template>
    <xsl:template match="Reference">
        <xsl:variable name="link">
            <xsl:choose>
                <xsl:when test="ends-with(.,'.-')">
                    <xsl:value-of select="string-join(('ViewClass?classificationId=',$classificationId,'&amp;code=',substring-before(.,'.-')),'')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="string-join(('ViewClass?classificationId=',$classificationId,'&amp;code=',.),'')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <a href="{$link}">
            <xsl:value-of select="."/>
        </a>
    </xsl:template>
    <xsl:template match="Term">
        <xsl:choose>
            <xsl:when test="@class='bold'">
                <b>
                    <xsl:apply-templates/>
                </b>
            </xsl:when>
            <xsl:when test="@class='organism'">
                <i>
                    <xsl:apply-templates/>
                </i>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>