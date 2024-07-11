xquery version "3.1";
(:~
 : Utility functions and XFORMS for MetisID
 : 
 : @author Peter Herkenrath
 : @version 1.0
 : @date 2020-06-29
 : 
 :)
module namespace prpass ="http://enahar.org/exist/apps/metis/prpass";

declare namespace  ev  ="http://www.w3.org/2001/xml-events";
declare namespace  xf  ="http://www.w3.org/2002/xforms";
declare namespace xdb  ="http://exist-db.org/xquery/xmldb";
declare namespace html ="http://www.w3.org/1999/xhtml";
declare namespace fhir = "http://hl7.org/fhir";
(:~
 : show xform for password change
 : 
 : @return html 
 :)
declare function prpass:changePasswd(
        $account as element(fhir:PractitionerRole))
{

let $uref := $account/fhir:practitioner/fhir:reference/@value/string()
let $uid  := substring-after($uref,'metis/practitioners/')
let $uname  :=  $account/fhir:practitioner/fhir:display/@value/string()
let $header := concat("Passwort für: ", $uname)
let $restxq-passwd   := concat('/exist/restxq/metis/PractitionerRole/', $uid, '/passwd')
let $realm := "metis/organizations/kikl-spz"
return
(<div style="display:none;">
    <xf:model id="m-passwd">
         <xf:instance id="i-passwd" xmlns="">        
            <data>
                <oldPassword/>
                <newPassword/>
                <confirmPassword/>
            </data>
        </xf:instance>
        
        <xf:submission id="s-submit-passwd"
                				   ref="instance('i-passwd')"
								   method="put"
								   replace="none"
								   resource="{$restxq-passwd}">
			<xf:header>
                <xf:name>Content-Type</xf:name>
                <xf:value>application/xml</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>loguid</xf:name>
                <xf:value>{ $uid }</xf:value>
            </xf:header>
            <xf:header>
                <xf:name>realm</xf:name>
                <xf:value>{$realm}</xf:value>
            </xf:header>
            <xf:message ev:event="xforms-submit-error" level="modal">cannot submit passwd!</xf:message>
        </xf:submission>
        
        <xf:bind ref="instance('i-passwd')/oldPassword" required="true()" constraint=". != ''"/>
        <xf:bind ref="instance('i-passwd')/newPassword" required="true()" constraint=". != ''"/>
        <xf:bind ref="instance('i-passwd')/confirmPassword" required="true()" constraint=". = ../newPassword"/>   

    </xf:model>
</div>,
<div id="xforms">
    <h2>{$header}</h2>
    <p><strong>Nur drei Regeln:</strong>
     <ol>
        <li>Das neue Passwort muss sich vom alten Passwort unterscheiden.</li>
        <li>Das neue Passwort muss mindestens 6 Zeichen lang sein und mindestens eine Ziffer und einen Buchstaben enthalten;
            erlaubt sind noch !@#$%.<br/>
            Das Ganze als regexp: ^(?=.*\d+)(?=.*[a-zA-Z])[0-9a-zA-Z!@#$%]{6,10}$</li>
        <li>Das neue Passwort muss identisch wiederholt werden.</li>
    </ol>
    </p>
    <table>
        <tr>
            <td colspan="4">
                { prpass:mkPasswdGroup() }
            </td>
        </tr>
        <tr>
            <td>
                <xf:trigger class="svUpdateMasterTrigger">
                    <xf:label>Cancel</xf:label>
                    <xf:load ev:event="DOMActivate" resource="/exist/apps/metis/index.html"/> 
                </xf:trigger>
            </td>
            <td>
                <xf:trigger class="svSaveTrigger">
                    <xf:label>Submit</xf:label>
                    <xf:hint>This button will submit the user password.</xf:hint>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="s-submit-passwd"/>
                        <xf:load resource="/exist/apps/metis/index.html"/>
                    </xf:action>
                </xf:trigger>
            </td>
            <td></td>
        </tr>
    </table>
</div>    
)
};

declare %private function prpass:mkPasswdGroup() {
    <xf:group class="svFullGroup">
       <table>                                                                                       
        <tr>                                                                                         
          <td>                                                                                       
             <h3>Passwort ändern?</h3>                                                       
          </td>                                                                                      
        </tr>                                                                                        
        <tr>                                                                                         
          <td>                                                                                       
             <strong>Altes Passwort</strong>                                                         
          </td>                                                                                      
          <td>                                                                                       
             <xf:secret ref="instance('i-passwd')/oldPassword"></xf:secret>                          
          </td>                                                                                      
        </tr>                                                                                        
        <tr>                                                                                         
          <td>                                                                                       
             <strong>Neues Passwort</strong>                                                         
          </td>                                                                                      
          <td>                                                                                       
             <xf:secret ref="instance('i-passwd')/newPassword"></xf:secret>                          
          </td>
        </tr>
        <tr>                                                                                         
          <td>                                                                                       
             <strong>Password bestätigen</strong>                                                    
          </td>                                                                                      
          <td>                                                                                       
             <xf:secret ref="instance('i-passwd')/confirmPassword"></xf:secret>                      
          </td>                                                                                      
        </tr>                                                                                        
      </table>  
    </xf:group>
};


