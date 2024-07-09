#!/bin/bash
find $1 -type f \( -name "*.err" -o -name "*.htm" -o -name "*.lnk" \) -exec rm -vf {} \;
find $1 -type f \( -name "*.doc" -o -name "*.docx" -o -name "*.dot" \) -exec rm -vf {} \;
find $1 -type f \( -name "*.xls" -o -name "*.xslx" -o -name "*.mov" \) -exec rm -vf {} \;
for F in `find $1 -type f -name "*.xml"`
do
   BASE=`basename $F .xml`
   DIR=${F%/*}
   sed -i '1 i\<body class=\"letter-body\">' $F
   sed -i 's/"data:image[^"]*"/""/g' $F
   sed -i 's/&nbsp;/ /g' $F
   echo '</body>'  >>$F
done
