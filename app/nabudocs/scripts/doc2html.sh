#!/bin/bash

CONFIG=./tidy_options.conf
for F in `find $1 -type f -name "*.doc" -or -name "*.docx"`
do
   BASE=`basename $F .doc` ; BASE=`basename $BASE .docx`
   DIR=${F%/*}
   libreoffice --headless --convert-to htm:HTML --outdir $DIR $F
   tidy -q -config $CONFIG -f $DIR/$BASE.err -i $DIR/$BASE.htm | sed 's/ class="c[0-9]*"//g' > $DIR/$BASE.xml
done
