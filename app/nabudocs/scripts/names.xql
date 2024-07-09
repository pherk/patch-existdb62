xquery version "3.1";

let $names :=
(
  'Dr. P. Herkenrath'
, 'Dr.P. Herkenrath'
, 'OA Dr.P. Herkenrath'
, 'PD Dr. von Kleist-Retzow'
, 'Dr. G. Jopp-Petzinna'
, 'Dr. Springorum'
, 'K. Martakis'
, 'Dr. P. Herkenrath Dr. G. Jopp-Petzinna Dr. Springorum K. Martakis'
)

for $n in $names
return
    analyze-string($n,'(?: )?(?:(PD |OA |OÄ )?(?:(Dr.[ ]?)?(?:([^\.].|von))? ([a-zA-Zäöüß-]+)))')