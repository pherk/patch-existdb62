# Nabu on eXistDB 6.2

Only the jars and the patches are used.
As you can see, most of the patches are stolen from the Totenbuch app of the CCEH.
I don't know if Marcel Schaeben developed the way to integrate betterform as shadowed jar into 6.2.
Many thanks to him or whoever.
The Totenbuch app and the gulpfile are unchanged and unused.

https://gitlab.dh.uni-koeln.de/cceh/totenbuch


This is the Totenbuch eXist-db application running at http://totenbuch.awk.uni-koeln.de. It has originally been written
by Ulrike Henny, Jonathan Blumtritt et al. for eXist 1.4.3 and has since been adapted to newer eXist versions:

- eXist 2.2 in 2016
- eXist 3.6+ in January 2018
- eXist 5.2.0 in May / June 2021
- eXist 6.2.0 in September 2023

The current version has been tested in eXist 6.2.0.


<!-- MarkdownTOC -->

- [Repository structure](#repository-structure)
- [Code depenencies](#code-depenencies)
- [Development and Deployment](#development-and-deployment)
    - [Setting up a development instance](#setting-up-a-development-instance)
        - [Create the deployment config file \(`exist-secrets.conf`\)](#create-the-deployment-config-file-exist-secretsconf)
        - [Set up eXist-db](#set-up-exist-db)
            - [Without docker](#without-docker)
            - [With docker](#with-docker)
            - [Install the Totenbuch application into eXist](#install-the-totenbuch-application-into-exist)
    - [Migrating to a newer eXist version](#migrating-to-a-newer-exist-version)
    - [Configuraton details](#configuraton-details)
- [Data updates and maintenance](#data-updates-and-maintenance)
- [Visual Regression Testing with *backstop.js*](#visual-regression-testing-with-backstopjs)
- [Migration Notes](#migration-notes)
    - [5.2.0 to 6.2.0 \(September 2023\)](#520-to-620-september-2023)
        - [betterFORM dependency conflicts \(Re-inclusion of betterFORM and downgrade of Saxon and Xerces, part 2\)](#betterform-dependency-conflicts-re-inclusion-of-betterform-and-downgrade-of-saxon-and-xerces-part-2)
    - [4.5.0 to 5.2.0 \(May / June 2021\)](#450-to-520-may--june-2021)
        - [Range Index problems](#range-index-problems)
        - [Inconsistent result order from ``fn:collection``](#inconsistent-result-order-from-fncollection)
        - [Re-inclusion of betterFORM and downgrade of Saxon and Xerces](#re-inclusion-of-betterform-and-downgrade-of-saxon-and-xerces)
- [Documentation TODO](#documentation-todo)
- [Maintenance TODO](#maintenance-todo)

<!-- /MarkdownTOC -->

<a id="repository-structure"></a>
## Repository structure

- `app`: contains the source eXist app source code to be deployed to eXist
- `collection-conf`: contains the collection.xconf index configuration files taking from the original running eXist
  1.4.3 instance
- `exist-config`: contains patches for certain exist configuration files. Refer to these files for necessary config
  changes in a clean eXist installation.
- `exist-webappp`: these files need to be copied into the webapp/ subdirectory of the eXist installation directory
- `scripts`: contains XQuery scripts assisting the automated installation using gulp
- `betterform`: Maven project to build the betterFORM shaded JAR (see [below](#betterform-dependency-conflicts-re-inclusion-of-betterform-and-downgrade-of-saxon-and-xerces-part-2))

<a id="code-depenencies"></a>
## Code depenencies

This app makes heavy use the betterFORM XForms processor (previously included in eXist, now to be installed into eXist
manually) as well as dojo 1.6 as a javascript framework. Further dependencies
are [AWLD.js](http://isawnyu.github.io/awld-js/) as well as [openseadragon](https://openseadragon.github.io/).

<a id="development-and-deployment"></a>
## Development and Deployment

Changes to the app like new functionality, data updates and migrations to newer eXist versions should be made and tested
locally and then deployed to the live instance.

Originally, the app source code lived in the main running eXist instance. The files were simply uploaded into eXist, and
changes were made using by open-heart surgery directly on the server.

During the eXist 2.2 migration the code has been put under git version control and a [gulp](https://gulpjs.com/)
deployment
system has been set up. If gulp is unavailable for some reason, the app should still work when uploaded to an eXist
instance using other means.

The gulpfile is intended as both an automated deployment process and an implicit **documentation of the necessary
steps of setting up an app instance**. It is recommended to read and understand this file carefully before starting any
work on this app.

<a id="setting-up-a-development-instance"></a>
### Setting up a development instance

<a id="create-the-deployment-config-file-exist-secretsconf"></a>
#### Create the deployment config file (`exist-secrets.conf`)

Create an `exist-secrets.conf` file and configure eXist server instances for deployment.
Use `exist-secrets.conf.example` as a template.

- This file can contain configurations for different environments. The example has configurations for "local", "
  live" and "dev" environments. Run a gulp task with the `--env` parameter to choose an environment. By default,
  the `local` environment is used. To use the `live` environment for example, run gulp like
  this: `gulp deploy --env live`.

<a id="set-up-exist-db"></a>
#### Set up eXist-db

<a id="without-docker"></a>
##### Without docker

1. Install a clean eXist-db instance on the development machine.

2. Make the necessary configuration changes, use the patch files in `exist-config` as a reference. The patches were
   generated againt a clean eXist 6.2.0 distribution.  
   You can also try to have the patches applied automatically. A script `apply-patches.sh` has been provided for this in
   the `exist-config` directory:

```sh
# Change to the `exist-config` directory
cd exist-config

# Dry run to see if the patches apply. Replace <config-path> with the path where the
# clean eXist config files are (usually the `etc` directoy of the eXist distribution
./apply-patches.sh <config-path>

# If the patches succeed, apply them
./apply-patches.sh <config-path> --apply
```

3. Copy the files in `exist-webapp` to the `etc/webapp` directory of the eXist installation path.

4. Make the Totenbuch image files available locally. Under the current production deployment (as of September 2023), the
   images are
   under `/nfs/cceh/projects/images-totenbuch` on the server. The update/installation scripts will fail if the images
   are not available. Thus, the images need to be available locally. You can mount the remote file system using `sshfs`
   or alternatively copy them to your local machine (85G). Be sure to adapt the image path in `exist-secrets.json` for
   your local deployment.

<a id="with-docker"></a>
##### With docker

1. Run `docker plugin install vieux/sshfs`. This will install the `docker-volume-sshfs` plugin which allows to mount the
   remote image file path (see above) directly in the container. Alternatively, you can copy the image directory to your
   local machine as described above and set up a bind mound in `docker-compose.yml`.
2. Run `IMAGE_VOLUME_SSH_USER=<your_ssh_username> IMAGE_VOLUME_SSH_PASS=<your_ssh_passwort> docker-compose up`.
   This will build the image, mount the image volume, configure eXist and start the container.  
   Setting `IMAGE_VOLUME_SSH_USER` and `IMAGE_VOLUME_SSH_PASS` is only necessary if you use the `sshfs` plugin to mount
   the
   image directory. If you use public key authentication for SSH, you need to configure the `exist_images` volume
   in `docker-compose.yml` accordingly as described [here](https://github.com/vieux/docker-volume-sshfs).


<a id="install-the-totenbuch-application-into-exist"></a>
##### Install the Totenbuch application into eXist

1. Start the eXist-db database or the docker container.

2. Run `gulp install`. If this runs through, a working app instance should have been set up. The `install` task consists
   of several sub-tasks that can also be run independently of each other:
    1. `upload-index-conf` will store the `collection.xconf` index configuration files from `collection-conf` into the
       corresponding `/db/system/config` database subdirectories.
    2. `deploy` will store all files under `app` into `/db/totenbuch` in the database.
    3. `install-versioning-module` will install the versioning XAR package contained in this repo under `app`.
    4. `create-user-groups` will create the necessary user groups `com`, `prj` and `deleted` if they do not exist yet
    5. `update-all` will run all data generation scripts.

3. `gulp watch` can be used to automatically upload changed files to eXist during development.

<a id="migrating-to-a-newer-exist-version"></a>
### Migrating to a newer eXist version

The following process is recommended:

- Use the eXist Java Admin Client to make a backup of the live instance database
- Set up a local development environment as described above, test if everything works in the new version, perform any
  necessary migrations
- Install the new eXist version on the server, configure it as described above
- Import the backup using the admin client
- Use gulp to deploy changes to the new live instance, using `gulp install --env live` or similar. If no data has
  been changed, `gulp deploy --env live` might suffice.

When a new live instance is set up without backup/restore from a previous instance as described above, it is important
to back up and restore at least `/db/system/security` for the user accounts and `/db/system/versions` so old versions
will not be lost.

<a id="configuraton-details"></a>
### Configuraton details

Find an explanation of the necessary eXist configuration below (paths relative to the eXist root directory).

- `conf.xml`:
    - increase cacheSize to 256M and collectionCache to 128M
    - configure a regular data backup job
- `webapp/WEB-INF/controller-config.xml`
    - configure the `Flux` and `inspector` servlets used by betterFORM
    - redirect root (/) to `xmldb:exist:///db/totenbuch`
    - make the contents of the eXist `webapp` subdir available under the path `/fs`
- `webapp/WEB-INF/web.xml`
    - adjust `inspector` and betterForm servlet paths
    - configure the XFormsFilter mapping for each sub-url of the app (this was necessary for eXist 2.2 due to a bug, not
      sure if this is still necessary or if a wildcard would work with newer versions)
- `tools/jetty/webapps/exist-webapp-context.xml`
    - change default webapp context from `/exist` to `/`
- `tools/jetty/webapps/portal/WEB-INF/web.xml`
    - disable the eXist portal placeholder that would normally appear under `/`

<a id="data-updates-and-maintenance"></a>
## Data updates and maintenance

When making changes to any object, knowledge entry or the bibliography, the generated data has to be updated.
Use `gulp update-all` which automates the update process that would originally be done using the links under the admin
panel at `http://totenbuch.awk.nrw.de/admin`.

**ATTENTION**: It could be that someone made changes to the data on the live instance in eXist directly. Before making
any changes to the live instance, check if any recent modifications have been made (e.g. check the last modified files
in `/db/totenbuch/objects|knowledge|bibliography` using the java admin client). Any changes need to be integrated into
the git repository before proceeding (*see Maintenance TODO*).

**NOTE:** Disable the range index before all data updates or re-generation runs (see below in migration notes: *range
Index problems*)

<a id="visual-regression-testing-with-backstopjs"></a>
## Visual Regression Testing with *backstop.js*

This repository includes a configuration for *visual regression testing* of a testing instance against a production
instance. It also includes a set of reference screenshots to test changes against. [
*backstop.js*](https://github.com/garris/BackstopJS) takes screenshots of all the URLs configured
in ``backstop.config.js`` for both instances and creates a comparison report (it is recommended to use [*Beyond
Compare*](https://www.scootersoftware.com/) for the comparison of the actual screenshots as the results are a bit more
accurate).

It is recommended to run these tests after making any changes to the code. The code base is complex and fragile, and any
unintended changes in the generated visualisations and statistics can be easily caught using these tests.

Quick how-to:

- adapt production and testing URLs in ``backtop.config.js``
- test against included reference screenshots:
  ```bash
  backstop test --config="backstop.config.js"  --docker
  ```
- filter test cases by name, i.e. include only Spruch 20:
  ```bash
  backstop test --config="backstop.config.js" --filter='Spruch 20' --docker
  ```
- create a new set of reference images, overwriting the old ones
  ```bash
  backstop reference --config="backstop.config.js"
  ```
  
The `--docker` switch makes backstop use a docker container to take the screenshots. This ensures consistent rendering across environments.
Docker needs to be installed for this to work. You can also use backstop without `--docker`, but then rendering depends on the operating system,
operating system version, installed fonts etc. which can lead to false positives when backstop checks for mismatches.


<a id="migration-notes"></a>
## Migration Notes

<a id="520-to-620-september-2023"></a>
### 5.2.0 to 6.2.0 (September 2023)

<a id="betterform-dependency-conflicts-re-inclusion-of-betterform-and-downgrade-of-saxon-and-xerces-part-2"></a>
#### betterFORM dependency conflicts (Re-inclusion of betterFORM and downgrade of Saxon and Xerces, part 2)

*Read first*: [Re-inclusion of betterFORM and downgrade of Saxon and Xerces](#re-inclusion-of-betterform-and-downgrade-of-saxon-and-xerces)

As of eXist 6.2.0, adding the betterFORM JAR leads to two dependency conflicts:

- betterFORM needs the *javax.mail* API version 1.6.2 which in eXist was upgraded to version 2
- betterFORM needs *Saxon 9.6.0-7* and eXist includes a newer version since version 5.2.0. Downgrading Saxon globally
  worked with eXist 5.2.0 but not anymore with 6.2.0

The solution for eXist 6.2.0 was to create a **shaded JAR** for betterFORM and put it into eXist's class path instead of
the original `betterform-exist-5.1-SNAPSHOT-20160615.jar`. A shaded jar includes both an application and all or some of
its dependencies, with re-packaged (or "shaded") classes to avoid dependency
conflicts. The shaded JAR is included in this repository
as `exist-webapp/WEB-INF/lib/shaded-betterform-jar-1.0-SNAPSHOT.jar`. It includes all the classes
from `betterform-exist-5.1-SNAPSHOT-20160615.jar` as well as the required versions of Saxon and javax.mail.

The Maven project for building the shaded JAR is in the `betterform` directory. The JAR can be rebuilt as follows (for example if more dependency conflicts arise during future eXist migrations):

1. Install [Maven](https://maven.apache.org/).
2. Run `npm run betterform:build`. This will re-build the JAR and copy it into `exist-webapp/WEB-INF/lib/`.
3. Make sure to commit the newly built JAR into the repository if it works as intended.

<a id="450-to-520-may--june-2021"></a>
### 4.5.0 to 5.2.0 (May / June 2021)

<a id="range-index-problems"></a>
#### Range Index problems

The eXist range index speeds up data generation and website response times. However, eXist has a problem with complex
updates of XML data while the range index is active. When re-generating the preprocessed data (e.g. by
running ``gulp update-all``), the index can get corrupted and queries can return inconsistend results (random elements
missing etc.), leading to missing visualisations or statistics in the results. For this reason, the range index should
be disabled temoprarily when re-generating / updating the data by commenting out the following line in eXist's
configuration file (`conf.xml`) and restarting eXist:

```xml

<module id="range-index" class="org.exist.indexing.range.RangeIndex"/>
```

Remember to enable the index again after updating or the app will get slow.

There is a (at the time of writing still open) eXist-db issue which might be
related: https://github.com/eXist-db/exist/issues/1720

<a id="inconsistent-result-order-from-fncollection"></a>
#### Inconsistent result order from ``fn:collection``

In eXist 5.2.0, the order in which the results are returned from calls to ``fn:collection`` has changed. This affected a
variety of visualisations and statistics. For this reason, the original order of the documents
in ``/db/totenbuch/objects`` has been stored in ``/db/totenbuch/knowledge/object-order.xml``. During the initial data
generation step ``update-basis-allgemein``, the objects are written to ``/db/totenbuch/static/preprocessed/basis.xml``
in this order. All queries accessing documents have been modified do access them only from this file, and not from the
original collection ``/db/totenbuch/objects``. The editing forms still operate on the ``objects`` collection directly,
so after each edit, the step ``update-basis-allgemein`` has to be run again.




<a id="re-inclusion-of-betterform-and-downgrade-of-saxon-and-xerces"></a>
#### Re-inclusion of betterFORM and downgrade of Saxon and Xerces

**Update**: Downgrading Saxon like this does not work anymore as of eXist 6.2.0,
see [Re-inclusion of betterFORM and downgrade of Saxon and Xerces (part 2)](#re-inclusion-of-betterform-and-downgrade-of-saxon-and-xerces-part-2)

This app uses the betterFORM XForms processor which has previously been included with eXist. Since eXist 5, it has been
removed from the distribution. For this reason, the corresponding JAR files (included in this repository under ``lib``)
need to be copied into eXist's classpath and some additional configuration files (included
under `exist-webappp/WEB-INF`) need to be copied into eXist's `webapp/WEB-INF` directory.

betterFORM has a hard dependency on specific versions of the Saxon XSLT processor and the Xerces XML parser that have
since been upgraded in eXist. For betterFORM to work, the corresponding JARs have to be reverted to their old versions,
also included in this repository (which luckily does not seem to break eXist... yet). Make sure that eXist uses these
older versions.

Related sources:  
https://github.com/eXist-db/exist/issues/2007 (Xerces downgrade)  
https://sourceforge.net/p/exist/mailman/message/36935226/ (Saxon downgrade)

<a id="documentation-todo"></a>
## Documentation TODO

- which files are the data base, which files are static content, and which files are generated by the update scripts?
- for what is AWLD.js actually used?

<a id="maintenance-todo"></a>
## Maintenance TODO

- Migrate away from remote Google APIs for data tables and charts
- Separate data base and static files
- Convert into eXist app package
- Define a process for updating data; make sure that no one modifies data in the live instance in the future
- Move away from betterFORM – possible to migrate to Orbeon XForms or move away from XForms at all?
    - or: https://github.com/Jinntec/Fore (work-in-progress)
