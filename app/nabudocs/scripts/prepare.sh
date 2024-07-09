#!/bin/bash
find $1 -type f \( -name "AABrief*" -o -name "A-Vorlage*" \) -exec rm -vf {} \;
find $1 -type f \( -name "*.wbk" -o -name "*.tmp" -o -name "*.pdf" \) -exec rm -vf {} \;
find $1 -type f \( -name "~*.doc" -o -name "~*.docx" -o -name "~*.dot" \) -exec rm {} \;
find $1 -type f -exec rename 's/[ ,\[\]]//g;s/\([^\)]+\)/-dx/g;s/ä/ae/g;s/ü/ue/g;s/ß/ss/g;s/Ä/Ae/g;s/Ü/Ue/g;s/Ö/Oe/g;s/ö/oe/g;s/á/a/g;s/é/e/g;s/ó/o/g' {} \;
