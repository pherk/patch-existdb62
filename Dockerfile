# Use the existing image as the base
FROM existdb/existdb:6.2.0
COPY --from=busybox:uclibc /bin/sh /bin/sh
COPY --from=busybox:uclibc /bin/patch /bin/patch
COPY --from=busybox:uclibc /bin/find /bin/find
#COPY --from=busybox:uclibc /bin/ls /bin/ls
#COPY --from=busybox:uclibc /bin/env /bin/env

COPY ./exist-webapp/ /exist/etc/webapp
COPY ./exist-config /totenbuch/exist-config

WORKDIR /totenbuch/exist-config
RUN sh ./apply-patches.sh /exist/etc --apply