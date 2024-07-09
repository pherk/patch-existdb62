xquery version "3.0";

import module namespace dbutil="http://exist-db.org/xquery/dbutil";

(:~ Nabu security - admin user and users group :)

declare variable $user-group    := "spz";
declare variable $data-group    := "spz";

declare function local:create-user($user as xs:string) {
    if (not(xmldb:exists-user($user))) then
        xmldb:create-user($user, 'guest123', $user-group, ())
    else
        ()
};

let $users :=
<users>
<username>armbrustd</username>
<username>artza</username>
<username>asp</username>
<username>bartzu</username>
<username>beldowitschr</username>
<username>boeckmannk</username>
<username>bossierc</username>
<username>bredschneidera</username>
<username>brendelbergerj</username>
<username>ciraks</username>
<username>cremers</username>
<username>doerwaldy</username>
<username>doniem</username>
<username>duechtingc</username>
<username>ebnerk</username>
<username>eeg</username>
<username>eggersm</username>
<username>epnlg</username>
<username>esserr</username>
<username>eXide</username>
<username>fazeliw</username>
<username>flemmingm</username>
<username>freihat</username>
<username>gaffgah</username>
<username>giersdorfm</username>
<username>goebelo</username>
<username>griewelj</username>
<username>grimmej</username>
<username>grittnerb</username>
<username>guest</username>
<username>haeckc</username>
<username>heckere</username>
<username>hellerr</username>
<username>hellingp</username>
<username>hoeterkess</username>
<username>jakschass</username>
<username>jansens</username>
<username>joppg</username>
<username>kahramano</username>
<username>kerndert</username>
<username>kloidtb</username>
<username>kole</username>
<username>koya</username>
<username>kranzg</username>
<username>kuepperk</username>
<username>martakisk</username>
<username>matthesh</username>
<username>meffertm</username>
<username>meinhardta</username>
<username>mma</username>
<username>monex</username>
<username>muellern</username>
<username>muellery</username>
<username>muglern</username>
<username>pawlowae</username>
<username>pmh</username>
<username>prawalskyn</username>
<username>reichelta</username>
<username>ritterbachc</username>
<username>salminens</username>
<username>schillingb</username>
<username>schlamannp</username>
<username>seblers</username>
<username>sherzadar</username>
<username>spa</username>
<username>speel</username>
<username>spickermannl</username>
<username>spottkes</username>
<username>strassc</username>
<username>toebbensl</username>
<username>toermers</username>
<username>vdba</username>
<username>vkr</username>
<username>weissenborna</username>
<username>wesemannh</username>
<username>wiendlochac</username>
<username>wiesnerv</username>
<username>wunramh</username>
<username>zeppj</username>
</users>

let $addall := for $u in $users/username
    return
        local:create-user($u)

return
    'user added'

