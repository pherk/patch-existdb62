xquery version "3.1";

module namespace tree = "http://enahar.org/exist/apps/nabudocs/tree";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace fhir= "http://hl7.org/fhir";
declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function tree:menue($loguid,$lognam,$realm)
{
(<div style="display:none;">
      <xf:model id="modelID" ev:event="" functions="" schema="">
         <xf:instance xmlns="" id="instanceData">
            <group id="mainGroup">
               <group id="group1" fold="0" category="Category One">
                  <item id="item1">Enter Data</item>
                  <item id="item2">Enter Data</item>
                  <item id="item3">Enter Data</item>
                  <group id="group2" fold="0" category="Category Two">
                     <item id="item4">Enter Data</item>
                     <item id="item5">Enter Data</item>
                     <group id="group3" fold="0" category="Category Three">
                        <item id="item6">Enter Data</item>
                        <item id="item7">Enter Data</item>
                        <item id="item8">Enter Data</item>
                     </group>
                     <item id="item9">Enter Data</item>
                  </group>
               </group>
            </group>
         </xf:instance>
         <xf:instance xmlns="" id="foldedNodes">
            <foldednodes>
               <nodelist/>
            </foldednodes>
         </xf:instance>

         <xf:bind nodeset="descendant::*" relevant="not(contains(instance('foldedNodes')/*:nodelist, current()/parent::*/@id))"/>
      </xf:model>
<!--
      <style type="text/css">
         @namespace xhtml url("http://www.w3.org/1999/xhtml");
         @namespace xf url("http://www.w3.org/2002/xforms");
         xf|*:disabled {
         display: none;
         }
      </style>
-->
   </div>
,
   <div>

      <div class="header">Folding Test</div>

      <xf:group id="mainGroup">
         <xf:output ref="instance('foldedNodes')/*:nodelist">
            <xf:label>ID List</xf:label>
         </xf:output>
         <xf:repeat ref="instance('instanceData')/descendant::*:group" id="repeatGroup">
            <xf:output class="outputInline" value="concat(substring('&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;',1,3 * count(current()/ancestor::*)), '&#160;&#160;&#160;&#160;&#160;')"/>
            <xf:trigger>
               <xf:label>
                  <xf:output value="if (contains(instance('foldedNodes')/*:nodelist, ./@id)) then '+' else '-'"/>
               </xf:label>
               <xf:action ev:event="DOMActivate">
                  <xf:setvalue ref="instance('foldedNodes')/*:nodelist" value="if (contains(instance('foldedNodes')/*:nodelist, instance('instanceData')/descendant::*:group[position()=index('repeatGroup')]/@id)) then concat(substring-before(instance('foldedNodes')/*:nodelist, instance('instanceData')/descendant::*:group[position()=index('repeatGroup')]/@id) else substring-after(instance('foldedNodes')/*:nodelist, instance('instanceData')/descendant::*:group[position()=index('repeatGroup')]/@id)), concat(instance('foldedNodes')/*:nodelist, instance('instanceData')/descendant::*:group[position()=index('repeatGroup')]/@id)"/>
               </xf:action>
            </xf:trigger>
            <xf:output class="outputInline" ref="./@category"/>
            <xf:repeat ref="./item" id="repeatItem">
               <xf:output class="outputInline" value="concat(substring('&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;',1,3 * count(current()/ancestor::*)), '&#160;&#160;&#160;&#160;&#160;')"/>
               <xf:output class="outputInline" ref="./@id">
                  <xf:label>id: </xf:label>
               </xf:output>
               <xf:input class="inputInline" ref=".[name() = 'item' or name() = 'file']">
                  <xf:label>data: </xf:label>
               </xf:input>
            </xf:repeat>
         </xf:repeat>
      </xf:group>
    </div>
)
};