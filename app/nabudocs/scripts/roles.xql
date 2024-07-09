xquery version "3.1";

let $names :=
(
  'Leiter Sozial- und Neuropädiatrie'
, 'Kinderärztin'
, 'Kinderarzt'
, 'Arzt für Kinder- und Jugendmedizin'
, 'Assistenzärztin'
, 'Assistenzarzt für Kinder- und Jugendmedizin'
, 'Assistenzärztin für Kinder- und Jugendmedizin'
, 'Fachärztin für Kinder- und Jugendmedizin'
, 'Fachärztin für Kinder- und Jugendmedizin'
, 'Ambulanzärztin'
, 'Ambulanzarzt'
, 'Oberarzt'
, 'Oberärztin Sozial- u. Neuropädiatrie'
, 'OÄ Sozial- u. Neuropädiatrie'
, 'Orthopäde'
, 'OA Orthopädie'
, 'OÄ Orthopädie'
, 'OÄ Orthopädie-Kinderklinik'
, 'Neuropädiatrie'
, 'Arzt f. Kinder- und Jugendpsychiatrie und -psychotherapie'
, 'Pädiatrische Endokrinologie und Diabetologie'
, 'Ergotherapeutin'
, 'Physiotherapeutin'
, 'Logopädin'
, 'Dipl. Psychologe'
, 'Dipl. Psychologin'
, 'Diplompsychologe'
, 'Diplompsychologin'
, 'Kinder- und Jugendlichenpsychotherapeutin'
, 'Psychologischer Psychotherapeut'
, 'Psychologische Psychotherapeutin'
, 'Psychol. Psychotherapeutin (VT)'
, 'Dipl.- Psych./ Dipl.-Päd.'
, 'Klinische Neuropsychologin GNP'
)
let $div := " ,()"

for $n in $names
return
    analyze-string($n,'(?: )?(?:(PD |OA |OÄ )?(?:(Dr.[ ]?)?(?:([^\.].|von))? ([a-zA-Zäöüß-]+)))')