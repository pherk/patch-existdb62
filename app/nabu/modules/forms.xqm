xquery version "3.0";

module namespace forms="http://enahar.org/exist/apps/nabu/forms";

import module namespace fields    = "http://enahar.org/exist/apps/nabu/fields"     at "fields.xqm";
import module namespace dates     = "http://enahar.org/exist/apps/nabu/dates"      at "date.xqm";

import module namespace r-patient = "http://enahar.org/exist/restxq/nabu/patients" at "../patient/patient-routes.xqm";
import module namespace r-practrole    = "http://enahar.org/exist/restxq/metis/practrole" 
                      at "/db/apps/metis/PractitionerRole/practitionerrole-routes.xqm";

declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";

(:  date pattern="[0-9]{4}-(0[1-9]|1[012])-(0[1-9]|1[0-9]|2[0-9]|3[01])" oder
 :                (?:19|20)[0-9]{2}-(?:(?:0[1-9]|1[0-2])-(?:0[1-9]|1[0-9]|2[0-9])|(?:(?!02)(?:0[1-9]|1[0-2])-(?:30))|(?:(?:0[13578]|1[02])-31)) 
 :)

declare variable $forms:newTask {
    <form>
        <field name="t_header"/>
        <field name="t_role"/>
        <field name="assignee_id"/>
        <field name="collaborators"/>
        <field name="requester"/>
        <field name="t_subject"/>
        <field name="problem_id"/>
        <field name="t_description"/>
        <field name="t_priority"/>
        <field name="t_due_at"/>
        <field name="t_tags"/>
        <field name="created_at"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:newSelfTask {
    <form>
        <field name="t_header"/>
        <field name="collaborators"/>
        <field name="t_subject"/>
        <field name="problem_id"/>
        <field name="t_description"/>
        <field name="t_priority"/>
        <field name="t_due_at"/>
        <field name="t_tags"/>
        <field name="created_at"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:newQuestion {
    <form>
        <field name="t_qheader"/>
        <field name="t_role"/>
        <field name="assignee_id"/>
        <field name="requester"/>
        <field name="t_subject"/>
        <field name="problem_id"/>
        <field name="t_description"/>
        <field name="t_priority"/>
        <field name="t_due_at"/>
        <field name="t_tags"/>
        <field name="created_at"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:updateTask {
    <form>
        <field name="t_updateheader"/>
        <field name="submitter_id"><editable>false</editable></field>
        <field name="t_role"><editable>false</editable></field>
        <field name="assignee_id"><editable>false</editable></field>
        <field name="collaborators"><editable>false</editable></field>
        <field name="requester"><editable>false</editable></field>
        <field name="t_subject"><editable>false</editable></field>
        <field name="problem_id"><editable>false</editable></field>
        <field name="t_description"><editable>false</editable></field>
        <field name="t_comment"/>
        <field name="t_priority"/>
        <field name="t_status"/>
        <field name="t_due_at"/>
        <field name="t_tags"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:updateQuestion {
    <form>
        <field name="t_updateqheader"/>
        <field name="submitter_id"><editable>false</editable></field>
        <field name="t_role"><editable>false</editable></field>
        <field name="assignee_id"><editable>false</editable></field>
        <field name="requester"><editable>false</editable></field>
        <field name="t_subject"><editable>false</editable></field>
        <field name="problem_id"><editable>false</editable></field>
        <field name="t_description"><editable>false</editable></field>
        <field name="t_comment"/>
        <field name="t_priority"/>
        <field name="t_status"/>
        <field name="t_due_at"/>
        <field name="t_tags"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:updateOrMoveTask {
    <form>
        <field name="t_updateheader"/>
        <field name="submitter_id"><editable>false</editable></field>
        <field name="t_role"></field>
        <field name="assignee_id"></field>
        <field name="collaborators"><editable>false</editable></field>
        <field name="requester"><editable>false</editable></field>
        <field name="t_subject"><editable>false</editable></field>
        <field name="problem_id"><editable>false</editable></field>
        <field name="t_description"><editable>false</editable></field>
        <field name="t_comment"/>
        <field name="t_priority"/>
        <field name="t_status"/>
        <field name="t_due_at"/>
        <field name="t_tags"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:cloneTask {
    <form>
        <field name="t_cloneheader"/>
        <field name="submitter_id"><editable>false</editable></field>
        <field name="t_role"></field>
        <field name="assignee_id"></field>
        <field name="collaborators"/>
        <field name="requester"><editable>false</editable></field>
        <field name="t_subject"><editable>false</editable></field>
        <field name="problem_id"><editable>false</editable></field>
        <field name="t_description"><editable>false</editable></field>
        <field name="t_comment"/>
        <field name="t_priority"/>
        <field name="t_status"/>
        <field name="t_due_at"/>
        <field name="t_tags"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:updateSelfTask {
    <form>
        <field name="t_updateheader"/>
        <field name="collaborators"/>
        <field name="t_subject"/>
        <field name="problem_id"><editable>false</editable></field>
        <field name="t_description"/>
        <field name="t_comment"/>
        <field name="t_priority"/>
        <field name="t_status"/>
        <field name="t_due_at"/>
        <field name="t_tags"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:newUser {
    <form>
        <field name="a_header"/>
        <field name="a_name"/>
        <field name="a_alias"/>
        <field name="a_email"/>
        <field name="a_phone"/>
        <field name="group"/>
        <field name="roles"/>
        <field name="t_type"><editable>true</editable></field>
        <field name="t_role"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};

declare variable $forms:updateUser {
    <form>
        <field name="a_header"/>
        <field name="a_name"/>
        <field name="a_alias"><editable>false</editable></field>
        <field name="a_password"/>
        <field name="a_email"/>
        <field name="a_phone"/>
        <filed name="a_signature"/>
        <field name="group"><editable>false</editable></field>
        <field name="roles"><editable>false</editable></field>
        <field name="t_type"><editable>true</editable></field>
        <field name="t_role"/>
        <field name="t_tags"/>
        <field name="updated_at"/>
        <field name="t_submit"/>
    </form>
};



declare function forms:insertAsLastChild($node, $new-node, $check) {
    if (local-name($node) eq $check) then
            element { node-name($node) } { 
                        $node/@*
(:                      ,
                        for $child in $node/node()
                            return 
                                forms:insertAsLastChild($child, $new-node, $check) 
:)
                        ,
                        $new-node
                    }
    else if ($node instance of element()) then
            element { node-name($node) } { 
                $node/@*
                , 
                for $child in $node/node()
                    return 
                        forms:insertAsLastChild($child, $new-node, $check) 
         }
    else $node
};

declare function forms:isRequired($input)
{
    if ($input/required/text()='true')
    then attribute required {"true"}
    else ()
};


declare function forms:isMulti($input)
{
    if ($input/values/multi/text()='true')
    then true()
    else false()
};

declare function forms:isEditable($input)
{
    if ($input/editable/text()='true')
    then ()
    else attribute disabled {"true"}
};

declare function forms:mkHeader($header) as element() {
    <li><h2>{$header/values/text/text()}</h2><span class="required_notification">{$header/values/req_span/text()}</span></li>
};

(: double of function tasks:getFieldValue() :)
declare function forms:getValue($fields, $name) {
let $fval := for $f in $fields/node()
    where $name = local-name($f)
    return
        $f
return
    if (empty($fval))
    then ()
    else forms:prepareValue($name,$fval)
};

declare function forms:prepareValue($name,$value)
{
    if ($name='collaborators')
    then <collaborators>{
            string-join(
            for $cc in $value/*
            return
                concat($cc/@alias/string(),':',$cc/text())
            ,','
            )
         }</collaborators>
    else if ($name='problem_id')
    then 
        <problem_id>{
            if ($value = '')
            then ''
            else forms:mapToPatientInfo($value)
        }</problem_id>
    else if ($name='assignee_id')
    then <assignee_id>{r-practrole:userByID($value)/a_name/string()}</assignee_id>
    else if ($name='submitter_id')
    then <submitter_id>{r-practrole:userByID($value)/a_name/string()}</submitter_id>
    else $value
};

declare function forms:mapToPatientInfo($id as xs:string) as xs:string
{
    let $p := r-patient:patDemographicsByUUID($id)
    return
        if ($p/@id)
        then concat($p/contact/person/n/family-name,', ', $p/contact/person/n/given-name, ' *', $p/bday)
        else '? Patient ID not found'
};

declare function forms:mkText($input, $value, $self, $new) as element() {
(:   :let $log := util:log-app('DEBUG','nabu', ('mkText: ', $input,' - ',$value)) :)
let $fval  := normalize-space($value)
let $name  := $input/name/text()
let $label := $input/title/text()
let $core  := $input/collapsable/text()
let $placeholder := attribute placeholder {$input/values/placeholder/text()}
let $req   := forms:isRequired($input)
let $hint  := $input/hint/text()
let $ph := if ($fval='')
    then $placeholder
    else ()
let $vis := xs:boolean($input/visible/text())
let $js  := $input/values/script/text()
let $dis  := forms:isEditable($input)
return
    if ($vis or $dis) 
    then    <li>
                <label for="{$name}">{$label}</label>
                {element input {
                    attribute type {"text"},
                    attribute id {$name},
                    attribute name {$name},
                    $ph,
                    $req,
                    $dis,
                    attribute value {$fval}
                    }
                }
                <span class="form_hint">{$hint}</span>
            </li>
    else
        <li><label for="{$name}">{$label}</label>
            {element input {
                attribute type  {"hidden"},
                attribute class {"bigdrop"},
                attribute id    {$name},
                attribute name {$name},
                $dis,
                attribute value {$fval}
                }
            }
            {if ($js)
                then <script type="text/javascript">{$js}</script>
                else ()
            }
        </li>
};

declare function forms:mkInt($input, $value, $self, $new) as element() {
let $name  := $input/name/text()
let $label := $input/title/text()
let $core  := $input/collapsable/text()
let $placeholder := $input/values/placeholder/text()
let $req   := $input/required/text()
let $hint  := $input/hint/text()
let $ph := if ($value/text()='auto') then 'Todo'
        else if ($input/values/value/text()='') then $placeholder
        else  ''
let $vis := xs:boolean($input/visible/text())
return
    if ($vis) then
        <li>
            <label for="{$name}">{$label}</label>
            <input type="text"  id="{$name}" name="{$name}" placeholder="{$ph}" required="{$req}" value="{$value/text()}"/>
            <span class="form_hint">{$hint}</span>
        </li>     
    else
        <li><input type="hidden"  id="{$name}" name="{$name}" value="{$value}"/></li>
};


declare function forms:mkDate($input, $fval, $self, $new) as element() {
let $name  := $input/name/text()
let $label := $input/title/text()
let $core  := $input/collapsable/text()
let $default:= format-date(dates:from-relative-date($input/values/value/text()),"[D01]-[M01]-[Y02]")
let $value := if ($fval)
        then if ($fval/text()=('heute','h'))
            then format-date(dates:from-relative-dateTime($fval/text()),"[D01]-[M01]-[Y02]")
            else format-date($fval/text(),"[D01]-[M01]-[Y02]")
        else $default
let $placeholder := $input/values/placeholder/text()
let $req   := $input/required/text()
let $hint  := $input/hint/text()
let $pat   := $input/pattern/text()
let $ph    := if ($value='') then   $placeholder  else  ''
let $vis := $input/visible/text()
let $edit  := forms:isEditable($input)
return
    if ($vis ='true') then
        <li>
            <label for="{$name}">{$label}</label>
            <input type="date"  id="{$name}" name="{$name}" pattern="{$pat}" 
                    required="{$req}" hint="{$hint}" value="{$value}"/>
            <span class="form_hint">{$hint}</span>
        </li>
    else if($input/editable/text()='true')
        then <li><input type="hidden"  id="{$name}" name="{$name}"  data-nabu-datetime="{$fval/text()}"
                    value="{$value}"/></li>
        else <li><input type="hidden"  id="{$name}" name="{$name}" value="{$default}"/></li>
};

declare function forms:mkDateTime($input, $fval, $self, $new) as element() {
(:  let $log := util:log-app('DEBUG','nabu', ('mkText: ', $input,' - ',$fval)) :)
let $name  := $input/name/text()
let $label := $input/title/text()
let $default:= dates:from-relative-dateTime($input/values/value/text())
let $value := if ($fval)
        then if ($fval/text()=('heute','auto'))
            then dates:from-relative-dateTime($fval/text())
            else $fval/text()
        else $default
let $vis := $input/visible/text()
return
    if ($vis ='true') then (: not really implemented :)
        <li>
            <label for="{$name}">{$label}</label>
            <input type="date" id="{$name}" name="{$name}" data-nabu-datetime="{$fval}"
                    value="{$value}"/>
        </li>
    else if($input/editable/text()='true')
        then <li><input type="hidden" id="{$name}" name="{$name}" value="{$default}"/></li>
        else <li><input type="hidden" id="{$name}" name="{$name}" value="{$value}"/></li>
};

declare function forms:mkTextarea($input, $value, $self, $new) as element() {
let $name  := $input/name/text()
let $label := $input/title/text()
let $core  := $input/collapsable/text()
let $req   := forms:isRequired($input)
let $edit  := forms:isEditable($input)
let $hint  := $input/hint/text()
return
    <li>
        <label for="{$name}">{$label}</label>
        {element textarea {
            attribute id {$name},
            attribute name {$name},
            attribute col {"40"},
            attribute rows {'3'},
            $req,
            $edit,
            attribute overflow {"auto"},
            $value/text()
            }
        }
        <span class="form_hint">{$hint}</span>
    </li>
};


declare function forms:selectOption($options as item()+, $multi, $fvals)
{
    let $selected := 
        if ($multi)
        then 
            for $f in $fvals/*
                return
                <option value="{$f/text()}" selected="true">{
                    $options//option[@value/string()=$f/text()]/text()
                }</option>
        else if ($fvals)
                then <option value="{$fvals/text()}" selected="true">{
                        $options//option[@value/string()=$fvals/text()]/text()
                    }</option>
                else ()
    let $rest :=
        if ($multi)
        then  for $o in $options
            return
                $o//option[not(@value/string() = $fvals/*/text())]
        else
            $options//option[not(@value/string() = $fvals/text())]
    return
    ($selected, $rest)
};

declare function forms:mkSelect($input, $fval, $self, $new) as element()* {
let $name := $input/name/text()
let $label:= $input/title/text()
let $core := $input/collapsable/text()
let $req  := forms:isRequired($input)
let $multi := forms:isMulti($input)
let $ph   := if(empty($input/values/default/*))
        then ()
        else attribute placeholder {$input/values/default/option/text()}
let $edit  := forms:isEditable($input)
let $js  := $input/values/script/text()
let $select  := 
        <li>
            <label for="{$name}">{$label}</label>
            { element select {
                attribute id {$name},
                if ($multi)
                then attribute name {concat($name,'[]')}
                else attribute name {$name},
                $req,
                $edit,
                $ph,
                if ($multi) 
                then attribute multiple {'true'}
                else ()
                }
            }
            <script type="text/javascript">{$js}</script>
        </li>
(:  let $log := util:log-app('DEBUG','nabu', ($name,$multi,$fval,$default)) :)

let $options := if ($new='true')
        then if ($self)
            then forms:selectOption($input/values/options,$multi,$fval)
            else forms:selectOption($input/values/options,$multi,$fval)
        else     forms:selectOption($input/values/options,$multi,$fval)

return
    if (xs:boolean($core)) then
        forms:insertAsLastChild($select, $options, 'select')
    else if ($core='auto') then
        forms:insertAsLastChild($select, $options, 'select')
    else 
        forms:insertAsLastChild($select, $options, 'select')
};

declare function forms:mkButton($input) as element() {
let $class := $input/values/class/text()
let $type  := $input/values/type/text()
let $value := $input/title/text()
let $edit  := forms:isEditable($input)
return
  <li>
    <button class="{$class}" type="{$type}">{$value}</button>
  </li>
};

declare function forms:mkFormElement($elem, $fields, $self, $new) as element()* {
let $name := $elem/@name/string()
let $finfo := fields:getFieldInfo($name)
let $field := local:updateElements($finfo,$elem)
let $value := forms:getValue($fields,$name)
let $type  := $field/type/text()
(: let $log := util:log-app('DEBUG','nabu',($name, ": ", $fields, ", value: ", $value)) :)
return (: try catch :)
    if ($type='header') then
        forms:mkHeader($field)
    else if ($type='text') then
        forms:mkText($field, $value, $self, $new)
    else if ($type='int') then
        forms:mkInt($field, $value, $self, $new)
    else if ($type='date') then
        forms:mkDate($field, $value, $self, $new)
    else if ($type='datetime') then
        forms:mkDateTime($field, $value, $self, $new)
    else if ($type='select') then
        forms:mkSelect($field, $value, $self, $new)
    else if ($type='textarea') then
        forms:mkTextarea($field, $value, $self, $new)
    else if ($type='button') then
        forms:mkButton($field)
    else 
        <li>{$name}</li>
};

declare function local:updateAttr($node,$attr-name,$new-val)
{ 
  element {node-name($node)}
            { 
              for $att in $node/@*
              return
                if (name($att)=$attr-name)
                  then
                     attribute {name($att)} {$new-val}
                   else
                      attribute {name($att)} {$att}
            }
};

declare function local:updateElements($input, $new)
{
    element {node-name($input) }
      {$input/@*,
        for $i in $input/node()
        let $m :=
            for $b in $new/node()
            return if (local-name($i) = local-name($b))
                then $b/text()
                else ()
    return
        if (empty($m))
        then $i
        else if ($i/text() = $m)
            then $i
            else element {local-name($i)}{$m}
      }
};

declare function forms:mkEditTaskForm($type, $task, $new, $self, $moveable) {
let $tid  := if (exists($task/@xml:id))
    then $task/@xml:id/string()
    else ''
let $emptyForm :=  <form class="edit_form" method="post" action="{if ($new='true') then
                                ('task/newTask.xq') else ('task/updateTask.xq')}">
                        <ul/>
                    </form>
let $form := if ($new='true') (: tricky, select correct form template :)
        then if ($self)
            then $forms:newSelfTask
            else if ($type='question')
                then $forms:newQuestion
                else $forms:newTask
        else if ($type='question')
            then $forms:updateQuestion
        else if ($self)
            then $forms:updateSelfTask
            else if ($moveable)
                then $forms:updateOrMoveTask
                else $forms:updateTask
let $elems := for $fn in $form/node()
        return
            forms:mkFormElement($fn,$task, $self, $new)
return
    <p>
      <p>taskid: {$tid}, new: {$new}, self: {$self}</p>
        {forms:insertAsLastChild($emptyForm, 
            (
                <li><input type="hidden"  id="tid" name="tid" value="{$tid}"/></li>
            ,   <li><input type="hidden"  id="t_type" name="t_type" value="{$type}"/></li>
            ,   $elems
            ), 'ul')}
    </p>
};

declare function forms:mkCloneTaskForm($task, $uid, $self, $cloneable) {
let $emptyForm :=  <form class="edit_form" method="post" action="task/cloneTask.xq">
                        <ul/>
                    </form>
let $form := $forms:cloneTask
let $elems := for $fn in $form/node()
        return
            forms:mkFormElement($fn,$task, $self, 'true')
return
    <p>
      <p>It is {current-dateTime()}, user: {r-practrole:userByID($uid)/a_alias}, id: {$task/@xml:id/string()}, self: {$self}</p>
      {forms:insertAsLastChild($emptyForm, $elems, 'ul')}
    </p>
};

declare function forms:mkAccountForm($account, $uid, $self) {
let $new   := if (normalize-space($account/@xml:id)='')
        then 'true'
        else 'false'
let $emptyForm := forms:mkEmptyAccountForm($new)
let $form := if ($new='true')
        then $forms:newUser
        else $forms:updateUser
let $elems := for $fn in $form/node()
        return
            forms:mkFormElement($fn,$account, $self, $new)
return
    <p>
      <p>It is {current-dateTime()}, user: {r-practrole:userByID($uid)/a_alias}, id: {$account/@xml:id/string()}, new: {$new}, self: {$self}</p>
      {forms:insertAsLastChild($emptyForm, $elems, 'ul')}
    </p>
};

declare function forms:mkEmptyAccountForm($new) {
 <form class="edit_form" method="post" action="{if ($new='true') then
          ('user/newAccount.xq') else ('user/updateAccount.xq')}">
 <ul></ul>
 </form>
};

(: 
 : tricky
 : Strukturen wie tickets haben zunächst kein ID attribut
 : bei Updates wird die ID von der neuen Struktur genommen (identisch oder nicht)
 : es werden von der neuen Struktur nur Elemente kopiert, die der alten schon vorhanden sind
:)

declare function forms:mergeFormData($master as item(), $new as item()) as item()
{
element {local-name($master)}{
    $new/@*,
    for $f in $master/node()
    let $m :=
        for $b in $new/node()
        return if (local-name($f) = local-name($b))
                then $b
                else ()

    return
        if (empty($m))
        then $f
        else if ($f=$m)
            then $f
            else fields:update($f, $m)
    }
};
