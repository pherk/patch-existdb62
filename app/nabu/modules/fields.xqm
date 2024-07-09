xquery version "3.0";

module namespace fields="http://enahar.org/exist/apps/nabu/fields";

import module namespace dates="http://enahar.org/exist/apps/nabu/dates" at "dates.xqm";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";

declare variable $fields:t_type_options {
    (
        <option value="question">Anfrage</option>
    ,   <option value="team">Meeting</option>
    ,   <option value="task">ToDo</option>
    ,   <option value="incident">Beschwerde-Vorfall</option>
    ,   <option value="action">Aktion</option>
    )
};

declare variable $fields:t_group_options {
    (
        <option value="at">AmbulanzTeam</option>, 
        <option value="arzt">Arzt</option>,
        <optgroup label="Therapeuten">
            <option value="ergo">Ergotherapie</option>
            <option value="heilp">Heilpädagogik</option>
            <option value="logo">Logopädie</option>
            <option value="physio">Physiotherapie</option>
        </optgroup>,
        <option value="orthoptik">Orthoptik</option>,
        <option value="psych">Psychologe</option>,
        <option value="se">Sekretariat</option>,
        <option value="sa">Sozialdienst</option>,
        <option value="guest">Gast</option>
    )
};

declare variable $fields:t_teaml_options {
    (
        <option value="ateaml">ATeam-Leitung</option>,
        <option value="psychteaml">PsychTeam-Leitung</option>,
        <option value="spzl">SPZ-Leitung</option>
    )
};

declare variable $fields:t_konsil_options {
    (
        <option value="neurokonsil">Neuro-Konsil</option>,
        <option value="psychkonsil">Psych-Konsil</option>
    )
};

declare variable $fields:t_ambulanz_options {
    (
        <optgroup label="Ambulanzen">
            <option value="adipos">Adipositas</option>
            <option value="botox">Botox</option>
            <option value="gba">FG-Nachsorge</option>
            <option value="nch">Neurochirurgie</option>
            <option value="ng">Neurogenetik</option>
            <option value="ortho">Orthopädie</option>
            <option value="psychsom">Psychosomatik</option>
        </optgroup>
    )
};

declare variable $fields:t_funktion_options {
    (
        <optgroup label="Funktionen">
            <option value="eeg">EEG</option>
            <option value="ep">EP</option>
            <option value="nlg">NLG/EMG</option>
            <option value="hs">Hörscreening</option>
        </optgroup>
    )
};

declare variable $fields:t_status_options {
    (
        <option value="open">offen</option>,
        <option value="done">erledigt!</option>,
        <option value="notDone">unerledigt!</option>,
        <option value="closed">geschlossen</option>,
        <option value="reopened">wieder offen</option>
    )
};

declare variable $fields:fields {
    <fields>
        <field><name>t_header</name><type>header</type><title></title><hint>Header des Ticketformulars</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>false</editable>
            <values>
                <text>Task anlegen</text>
                <req_span>* Feld erforderlich</req_span>
            </values>
        </field>
        <field><name>t_qheader</name><type>header</type><title></title><hint>Header des Ticketformulars</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>false</editable>
            <values>
                <text>Anfrage stellen</text>
                <req_span>* Feld erforderlich</req_span>
            </values>
        </field>
        <field><name>t_cloneheader</name><type>header</type><title></title><hint>Header des Ticketformulars</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>false</editable>
            <values>
                <text>Task clonen</text>
                <req_span>* Feld erforderlich</req_span>
            </values>
        </field>
        <field><name>t_updateheader</name><type>header</type><title></title><hint>Header des Ticketformulars</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>false</editable>
            <values>
                <text>Task bearbeiten</text>
                <req_span>* Feld erforderlich</req_span>
            </values>
        </field>
        <field><name>t_updateqheader</name><type>header</type><title></title><hint>Header des Ticketformulars</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>false</editable>
            <values>
                <text>Anfrage bearbeiten</text>
                <req_span>* Feld erforderlich</req_span>
            </values>
        </field>
        <field><name>id</name><type>int</type><title>ID:</title><hint>ID-Nummer des Formulars</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>false</visible><editable>false</editable>
            <values>
                <value>auto</value>
            </values>
        </field>
        <field><name>t_url</name><type>text</type><title>Ticket-API:</title><hint>URL für das Ticket-API</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>false</visible><editable>false</editable>
            <values>
                <value>http://neuro-wiki.uk-koeln.lokal/exist/restxq/tasks/</value>
            </values>
        </field>
        <field><name>t_type</name><type>select</type><title>Ticket-Typ:</title><hint>Typ des Tickets</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <multi>false</multi>
                <default>
                    <option value="task">ToDo</option>
                </default>
                <options>{$fields:t_type_options}</options>
            </values>
        </field>
        <field><name>t_priority</name><type>select</type><title>Priorität:</title><hint>Priorität des Tickets</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <multi>false</multi>
                <default>
                    <option value="high">hoch</option>
                </default>
                <options>
                    <option value="high">hoch</option>
                    <option value="middle">mittel</option>
                    <option value="low">niedrig</option>
                </options>
            </values>
        </field>
        <field><name>t_role</name><type>select</type><title>Queue:</title>
            <hint>Ticketbusterteam</hint>
            <required>true</required><collapsable>true</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <multi>false</multi>
                <default>
                    <option value="">bitte auswählen</option>
                </default>
                <options>
                    {$fields:t_konsil_options},
                    {$fields:t_ambulanz_options},
                    {$fields:t_group_options},
                    {$fields:t_funktion_options},
                    {$fields:t_teaml_options}
                </options>
            </values>
        </field>
        <field><name>submitter_id</name><type>text</type><title>Zuweiser:</title><hint>Zuweiser</hint>
            <required>true</required><collapsable>true</collapsable><pattern></pattern>
            <visible>true</visible><editable>false</editable>
            <values>
                <value>auto</value>
            </values>
        </field>
        <field><name>assignee_id</name><type>text</type><title>Zugewiesen an:</title>
            <hint>zugewiesener Bearbeiter</hint>
            <required>true</required><collapsable>true</collapsable><pattern></pattern>
            <visible>false</visible><editable>true</editable>
            <values><script><![CDATA[
            $(document).ready(function() {
                    $("#assignee_id").select2({
                        width: "220px",
                        placeholder: "bitte wählen",
                        minimumInputLength: 0,
                        ajax: { 
                            url: "/exist/restxq/nabu/users",
                            dataType: 'json',
                            data: function (term, page) {
                                return {
                                    name: term, // search term
                                    start: 1,
                                    length: 10,
                                    role: $('#t_role').val()
                                };
                            },
                            results: function (data, page) { // parse the results into the format expected by Select2.
                            // since we are using custom formatting functions we do not need to alter remote JSON data
                                return {results: data};
                            }
                        },
                        initSelection: function(element, callback) {
                            var data = [];
                            $(element.val().split(",")).each(function(i) {
                                var item = this.split(':');
                                data.push({
                                    id: item[0],
                                    text: item[1]
                                });
                            });
                            $(element).val('');
                            callback(data);
                        },
                        dropdownCssClass: "bigdrop", // apply css that makes the dropdown taller
                        escapeMarkup: function (m) { return m; }
                    });
                    $('#role').change(function(){ $("#assignee_id").select2('data',null);
                                            });
                    });
            ]]></script>
            </values>
        </field>
        <field><name>recipient</name><type>email</type><title>RecEmail:</title>
            <hint>Empfänger Emailaddresse</hint>
            <required>false</required><collapsable>true</collapsable><pattern></pattern>
            <visible>false</visible><editable>true</editable>
            <values>
            </values>
        </field>
        <field><name>collaborators</name><type>text</type><title>CC:</title>
            <hint>Supervisor, Mitstreiter, Team</hint>
            <required>false</required><collapsable>true</collapsable><pattern></pattern>
            <visible>false</visible><editable>true</editable>
            <values>
                <multi>true</multi>
                <default/>
                <script><![CDATA[
            $(document).ready(function() {
                    $("#collaborators").select2({
                        width: "220px",
                        placeholder: "bitte wählen",
                        minimumInputLength: 0,
                        multiple: true,
                        ajax: { 
                            url: "/exist/restxq/nabu/users",
                            dataType: 'json',
                            data: function (term, page) {
                            return {
                                name: term, // search term
                                start: 1,
                                length: 10,
                                role: 'roles'
                                };
                            },
                            results: function (data, page) { // parse the results into the format expected by Select2.
                                // since we are using custom formatting functions we do not need to alter remote JSON data
                                return {results: data};
                            }
                        },
                        initSelection: function(element, callback) {
                            var data = [];
                            $(element.val().split(",")).each(function(i) {
                                var item = this.split(':');
                                data.push({
                                    id: item[0],
                                    text: item[1]
                                });
                            });
                            $(element).val('');
                            callback(data);
                        },
                        dropdownCssClass: "bigdrop", // apply css that makes the dropdown taller
                        escapeMarkup: function (m) { return m; }
                    });
            });
            ]]></script>
            </values>
        </field>
        
        <field><name>requester</name><type>text</type><title>Externe Anfrage?:</title>
            <hint>Name des Anfragers</hint>
            <required>false</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder></placeholder>
            </values>
        </field>
        <field><name>t_subject</name><type>text</type><title>Betreff:</title>
            <hint>Kurztitel</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder></placeholder>
            </values>
        </field>
        <field><name>problem_id</name><type>text</type><title>Patient:</title>
            <hint>Patient</hint>
            <required>false</required><collapsable>true</collapsable><pattern></pattern>
            <visible>false</visible><editable>true</editable>
            <values>
                <multi>false</multi>
                <default/>
                <script><![CDATA[
            $(document).ready(function() {
                    $("#problem_id").select2({
                        width: "245px",
                        placeholder: "Patient",
                        minimumInputLength: 2,
                        ajax: { 
                            url: "/exist/restxq/nabu/patient/simple-search",
                            dataType: 'json',
                            data: function (term, page) {
                                return {
                                    page_limit: 10,
                                    query: term, // search term
                                };
                            },
                            results: function (data, page) { // parse the results into the format expected by Select2.
                                // since we are using custom formatting functions we do not need to alter remote JSON data
                                return {results: data};
                            }
                        },
                        dropdownCssClass: "bigdrop", // apply css that makes the dropdown taller
                        escapeMarkup: function (m) { return m; }
                    });
            });
            ]]></script>
            </values>
        </field>
        <field><name>t_description</name><type>textarea</type><title>Beschreibung:</title>
            <hint>Genaue Beschreibung, was zu tun ist</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder></placeholder>
            </values>
        </field>
        <field><name>t_comment</name><type>textarea</type><title>Kommentar:</title>
            <hint>Reaktion erfolgt?</hint>
            <required>false</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder></placeholder>
            </values>
        </field>
        <field><name>t_due_at</name><type>date</type><title>Fällig am:</title>
            <hint>Datum der spätesten Bearbeitung (h|m|nW|\dW|\dM|\d{2}-\d{2}-\d{2})</hint>
            <required>true</required><collapsable>false</collapsable>
            <pattern>h|m|nW|\dW|\dM|\d{{2}}-\d{{2}}-\d{{2}}</pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value>h</value>
                <placeholder></placeholder>
            </values>
        </field>
        <field><name>t_status</name><type>select</type><title>Status:</title><hint>Status</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <multi>false</multi>
                <default>
                    <option value="open">offen</option>
                </default>
                <options>
                    {$fields:t_status_options}
                </options>
            </values>
        </field>
        <field><name>t_tags</name><type>text</type><title>Tags:</title><hint>Schlagworte</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value>spz</value>
                <placeholder>spz</placeholder>
            </values>
        </field>
        <field><name>created_at</name><type>datetime</type><title>Angelegt am:</title><hint>Datum der Erzeugung</hint>
            <required>true</required><collapsable>true</collapsable><pattern></pattern>
            <visible>false</visible><editable>false</editable>
            <values>
                <value>heute</value>
                <placeholder></placeholder>
            </values>
        </field>
        <field><name>updated_at</name><type>datetime</type><title>Verändert am:</title><hint>Datum der letzten Veränderung</hint>
            <required>true</required><collapsable>true</collapsable><pattern></pattern>
            <visible>false</visible><editable>true</editable>
            <values>
                <value>heute</value>
                <placeholder></placeholder>
            </values>
        </field>
        <field><name>t_submit</name><type>button</type><title>Fertig?</title>
            <hint>Abschicken oder Reset des Formulars</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>false</editable>
            <values>
                <class>submit</class>
                <type>submit</type>
            </values>
        </field>
        <field><name>a_header</name><type>header</type><title></title><hint>Header des Accountformulars</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>false</editable>
            <values>
                <text>Account und Ticket-Prefs</text>
                <req_span>* Feld erforderlich</req_span>
            </values>
        </field>
        <field><name>a_name</name><type>text</type><title>Name:</title><hint>Name des Nutzers</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder>Name</placeholder>
            </values>
        </field>
        <field><name>a_alias</name><type>text</type><title>Alias:</title><hint>Alias</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder>alias</placeholder>
            </values>
        </field>
        <field><name>a_password</name><type>text</type><title>Password:</title><hint>Password</hint>
            <required>false</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder>guest</placeholder>
            </values>
        </field>
        <field><name>a_email</name><type>text</type><title>Email:</title><hint>Email</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder>email</placeholder>
            </values>
        </field>
        <field><name>a_phone</name><type>text</type><title>Phone:</title><hint>Phone</hint>
            <required>false</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder>phone</placeholder>
            </values>
        </field>
        <field><name>a_signature</name><type>text</type><title>Unterschrift:</title><hint>Unterschrift</hint>
            <required>false</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <value></value>
                <placeholder>Unterschrift</placeholder>
            </values>
        </field>
        <field><name>group</name><type>select</type><title>Gruppe:</title><hint>Nutzergruppe</hint>
            <required>true</required><collapsable>false</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <multi>false</multi>
                <default>
                    <option value="">bitte auswählen</option>
                </default>
                <options>{$fields:t_group_options}</options>
            </values>
        </field>
        <field><name>roles</name><type>select</type><title>Funktionen:</title>
            <hint>Mitglied in Ticketbusterteams</hint>
            <required>false</required><collapsable>true</collapsable><pattern></pattern>
            <visible>true</visible><editable>true</editable>
            <values>
                <multi>true</multi>
                <default>
                    <option value="">bitte auswählen</option>
                </default>
                <options>
                    {$fields:t_konsil_options},
                    {$fields:t_ambulanz_options},
                    {$fields:t_group_options},
                    {$fields:t_funktion_options},
                    {$fields:t_teaml_options}
                </options>
                <script><![CDATA[
            $(document).ready(function() {
                    $("#roles").select2({
                        placeholder: 'bitte auswählen'
                    });
            });
            ]]></script>
            </values>
        </field>
    </fields>
};

declare function fields:getFieldInfo($name as xs:string)
{
let $field := $fields:fields/field[name=$name]
return
    if (empty($field))
    then <field><name>$name</name></field>
    else $field
};

declare function fields:isEditable($name as xs:string) as xs:boolean
{
let $info := fields:getFieldInfo($name)
return
    xs:boolean($info/editable/text())
};

declare function fields:isDateField($name as xs:string) as xs:boolean
{
let $info := fields:getFieldInfo($name)
return
    xs:boolean($info/type/text()='date')
};

declare function fields:mapOptionValueToLabel($name,$value as xs:string) as xs:string
{
let $field := $fields:fields/field[name=$name]
let $option := $field/values/options/option[@value=$value]
return
    if ($option)
    then $option/text()
    else 'error'
};

declare function fields:update($old,$value)
{
    if (fields:isDateField(local-name($old)))
    then element {local-name($old)}{dates:from-relative-date($value/text())}
    else element {local-name($old)}{
            if (count($value/*)>0)
            then
                for $n in $value/*
                return local:recurseReplace($n)
            else $value/text()
            }
};

declare function local:passthru($x as node()) as node()* {
    for $z in $x/node()
    return local:recurseReplace($z) };

declare function local:recurseReplace($x as node()) {
        typeswitch ($x) 
            (: Changes based on a condition 
                case element(collaborators) return <collaborators>
            :)
            (: IGNORE ANY CHANGES :)
            case text() return $x
            case comment() return comment {"an altered comment"}
            case element() return element {fn:node-name($x)} {for $a in $x/attribute()
                                                              return $a, local:passthru($x)}
            default return ()           
};

declare function local:distinct-nodes( $nodes as node()* )  as node()* {
    for $seq in (1 to count($nodes))
    return $nodes[$seq][not(local:is-node-in-sequence(
                                .,$nodes[position() < $seq]))]
 };
 
 declare function local:is-node-in-sequence( $node as node()? , $seq as node()* )  as xs:boolean {
   some $nodeInSeq in $seq satisfies $nodeInSeq is $node
 };
 