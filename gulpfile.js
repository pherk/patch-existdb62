var gulp = require('gulp')
var exist = require('gulp-exist')
var watch = require('gulp-watch')
var zip = require('gulp-zip')
var replace = require('gulp-replace')
var lazypipe = require('lazypipe')
var path = require('path')
var fs = require('fs')

var Axios = require('axios')
var axiosCookieJarSupport = require('axios-cookiejar-support').default
const tough = require('tough-cookie');


const secretsPath = process.argv.find(arg => arg.startsWith("--secrets="))?.split("=")?.[1] ?? "./exist-secrets.json"
const secretsFilePath = path.resolve(__dirname, secretsPath);
let secrets;
try {
  const rawData = fs.readFileSync(secretsFilePath, 'utf-8');
  secrets = JSON.parse(rawData);
} catch (error) {
  console.error(`Error reading or parsing secrets file: ${secretsFilePath}`, error);
  process.exit(1);
}


// ------ Deploy build dir to eXist ----------

var env =
  process.argv.includes("--env")
    ? process.argv[process.argv.indexOf("--env") + 1]
    : "local" 

console.log("Using environment '" + env + "'")

var conf = secrets[env]
var existClient = exist.createClient(conf)

exist.defineMimeTypes({
  'application/xquery': ['xqy'],
  'text/plain': ['*']
})

var permissions = { 
  'controller.xql': 'rwxr-xr-x',
  'queries/startseite-teaser.xql': 'rwxr-xr-x',
  'queries/reset.xql': 'rwxr-xr-x',
  'queries/tabelle-nachbarn.xql': 'rwxr-xr-x',
  'queries/datierung.xql': 'rwxr-xr-x',
  'queries/filter-register-besitzer.xql': 'rwxr-xr-x',
  'queries/update.xql': 'rwxr-x---',
  'queries/preprocessed/sprueche-bereinigt.xql': 'rwxr-xr-x',
  'queries/preprocessed/sprueche-perioden.xql': 'rwxr-xr-x',
  'queries/preprocessed/sprueche-gesamt.xql': 'rwxr-xr-x',
  'queries/preprocessed/sprueche-nachbarn.xql': 'rwxr-xr-x',
  'queries/preprocessed/sprueche-schrift.xql': 'rwxr-xr-x',
  'queries/preprocessed/sprueche-regionen.xql': 'rwxr-xr-x',
  'queries/preprocessed/sprueche-objektgruppen.xql': 'rwxr-xr-x',
  'queries/preprocessed/sprueche-objekte.xql': 'rwxr-xr-x',
  'queries/preprocessed/sprueche-geschlecht.xql': 'rwxr-xr-x',
  'queries/spruchtext.xql': 'rwxr-xr-x',
  'queries/admin.xql': 'rwxr-xr-x',
  'queries/images.xql': 'rwxr-xr-x',
  'queries/subforms/browsing-standort.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-inhalt.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-abbildungen.xql': 'rwxr-xr-x',
  'queries/subforms/browsing-objektart.xql': 'rwxr-xr-x',
  'queries/subforms/browsing-schrift-vignetten.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-anmerkungen.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-kurztitel.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-standort.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-datierung.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-to-standort.xql': 'rwxr-xr-x',
  'queries/subforms/browsing-herkunft.xql': 'rwxr-xr-x',
  'queries/subforms/browsing-datierung.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-form.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-allgemeines.xql': 'rwxr-xr-x',
  'queries/subforms/bearbeiten-bibliografie.xql': 'rwxr-xr-x',
  'queries/bindings-zeichentabellen.xql': 'rwxr-xr-x',
  'queries/overviews/spruchgruppen.xql': 'rwxr-xr-x',
  'queries/overviews/spruchnetz.xql': 'rwxr-xr-x',
  'queries/overviews/vorkommen-von-spruechen-und-vignetten-absolut.xql': 'rwxr-xr-x',
  'queries/overviews/benachbarte-sprueche-absolut-max.xql': 'rwxr-xr-x',
  'queries/overviews/spruchvorkommen-nach-perioden.xql': 'rwxr-xr-x',
  'queries/overviews/einzelsprueche.xql': 'rwxr-xr-x',
  'queries/overviews/benachbarte-sprueche-relativ.xql': 'rwxr-xr-x',
  'queries/overviews/benachbarte-sprueche-absolut-gerade-max.xql': 'rwxr-xr-x',
  'queries/overviews/sprueche.xql': 'rwxr-xr-x',
  'queries/overviews/benachbarte-sprueche-relativ-max.xql': 'rwxr-xr-x',
  'queries/overviews/objektzahl-pro-spruch.xql': 'rwxr-xr-x',
  'queries/overviews/benachbarte-sprueche-absolut.xql': 'rwxr-xr-x',
  'queries/overviews/benachbarte-sprueche-absolut-gerade.xql': 'rwxr-xr-x',
  'queries/url.xql': 'rwxr-xr-x',
  'queries/tabelle-besitzer.xql': 'rwxr-xr-x',
  'queries/register-besitzer.xql': 'rwxr-xr-x',
  'index.xql': 'rwxr-xr-x'
}
var urlReplaceExpr = /(totenbuch\.awk\.nrw\.de)(?!\/NS)/g
var urlReplaceSubst = conf.externalUrl

console.log(urlReplaceSubst)

var replacementTasks = lazypipe()
    .pipe(replace, new RegExp("declare variable \\$conf:admin-id as xs:string := \\\".*?\\\";"),
        "declare variable \$conf:admin-id as xs:string := \"" + conf.basic_auth.user + "\"; ",
        {skipBinary: true})
    .pipe(replace, new RegExp("declare variable \\$conf:admin-pass as xs:string := \\\".*?\\\";"),
        "declare variable \$conf:admin-pass as xs:string := \"" + conf.basic_auth.pass + "\";",
        {skipBinary: true})
    .pipe(replace, new RegExp("declare variable \\$conf:image-path := \\\".*?\\\";"),
        (match) => conf.image_path
            ? "declare variable \$conf:image-path := \"" + conf.image_path + "\";"
            : match,
        {skipBinary: true})
    .pipe(replace, urlReplaceExpr, urlReplaceSubst, {skipBinary: true})

gulp.task('deploy', function () {
  return gulp.src(['app/**/*', '!app/node_modules/**/*'])
    .pipe(replacementTasks())
    .pipe(existClient.newer({target: '/db/totenbuch/'}))
    .pipe(existClient.dest({
      target: '/db/totenbuch',
      permissions: permissions
    }))
})


// ------ Update Index ----------

gulp.task('upload-index-conf', function () {
  return gulp.src('collection-conf/**/*')
    .pipe(existClient.dest({target: '/db/system/config/'}))
})

gulp.task('update-index', gulp.series(['upload-index-conf', function() {
  return gulp.src('scripts/reindex.xql')
      .pipe(existClient.query());
}]))

// ------ WATCH ----------

gulp.task('watch', function () {
  return watch(['app/**/*.{xql,xqm,html,js,css,xsl,xml}', '!app/node_modules/**/*'], {
    ignoreInitial: true,
    name: 'Main Watcher'
  }).pipe(replacementTasks())
    .pipe(existClient.dest({
      target: '/db/totenbuch',
      permissions
    }))
})


// ------ UPDATE TOTENBUCH DATA ----------

const axios = Axios.create()
axiosCookieJarSupport(axios)

let globalCookieJar

function getUrl(path, cookieJar) {
  const url = `http://${conf.updateUrl || conf.externalUrl}${path}`
  console.log(`➜ ${url}`)
  return axios
      .get(url, {jar: cookieJar, withCredentials: true, auth: {username: conf.basic_auth.user, password: conf.basic_auth.pass}}).then(response => {
        const stripped = response.data
            .replace(/(<([^>]+)>)|/gi, "")
            .replace(/(\s){2,}/gi, "$1")
        console.log(`❮ ${stripped}`);
      })
      .catch(error => console.log(`❌ Error:\n${error}`))
}

function login() {
  if (globalCookieJar) {
    return new Promise(resolve => resolve(globalCookieJar))
  }

  let tempCookieJar = new tough.CookieJar()
  return getUrl("/user/login?username=" + conf.basic_auth.user + "&password=" + conf.basic_auth.pass, tempCookieJar).then(() => {
    globalCookieJar = tempCookieJar
    return globalCookieJar
  })
}

function request(path) {
  return login().then(cookieJar => {
    return getUrl(path, cookieJar);
  })
}

// gulp.task('update-login', function() {
//   return getUrl("/user/login?username=" + conf.basic_auth.user + "&password=" + conf.basic_auth.pass)
// })


gulp.task('update-basis-allgemein', function() {
  return request("/queries/update.xql?name=basis&skript=allgemein")
})

gulp.task('update-basis-sprueche-objekte.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-objekte.xql")
})
gulp.task('update-basis-sprueche-objektgruppen.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-objektgruppen.xql")
})
gulp.task('update-basis-sprueche-perioden.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-perioden.xql")
})
gulp.task('update-basis-sprueche-schrift.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-schrift.xql")
})
gulp.task('update-basis-sprueche-nachbarn.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-nachbarn.xql")
})
gulp.task('update-basis-sprueche-regionen.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-regionen.xql")
})
gulp.task('update-basis-sprueche-bereinigt.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-bereinigt.xql")
})
gulp.task('update-basis-sprueche-gesamt.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-gesamt.xql")
})
gulp.task('update-basis-sprueche-geschlecht.xql', function() {
  return request("/queries/update.xql?name=basis&skript=sprueche-geschlecht.xql")
})

gulp.task(
'update-basis', gulp.series(
  'update-basis-allgemein',
  'update-basis-sprueche-objekte.xql',
  'update-basis-sprueche-objektgruppen.xql',
  'update-basis-sprueche-perioden.xql',
  'update-basis-sprueche-schrift.xql',
  'update-basis-sprueche-nachbarn.xql',
  'update-basis-sprueche-regionen.xql',
  'update-basis-sprueche-bereinigt.xql',
  'update-basis-sprueche-gesamt.xql',
  'update-basis-sprueche-geschlecht.xql'
  )
)

gulp.task('update-fehlerreport', function() {
  return request("/queries/update.xql?name=report")
})


gulp.task('update-auswahllisten-auswahllisten-bearbeiten.xsl', function() {
  return request("/queries/update.xql?name=auswahllisten&auswahlliste=auswahllisten-bearbeiten.xsl")
})

gulp.task('update-auswahllisten-auswahllisten-browsing.xsl', function() {
  return request("/queries/update.xql?name=auswahllisten&auswahlliste=auswahllisten-browsing.xsl")
})

gulp.task(
'update-auswahllisten', gulp.series(
  'update-auswahllisten-auswahllisten-bearbeiten.xsl',
  'update-auswahllisten-auswahllisten-browsing.xsl'
  )
)


gulp.task('update-navigation', function() {
  return request("/queries/update.xql?name=navigation")
})


gulp.task('update-register-besitzer.xsl', function() {
  return request("/queries/update.xql?name=register&register=besitzer.xsl")
})
gulp.task('update-register-institution-institution.xsl', function() {
  return request("/queries/update.xql?name=register&register=institution-institution.xsl")
})
gulp.task('update-register-institution-land.xsl', function() {
  return request("/queries/update.xql?name=register&register=institution-land.xsl")
})
gulp.task('update-register-motive-alphabetisch.xsl', function() {
  return request("/queries/update.xql?name=register&register=motive-alphabetisch.xsl")
})
gulp.task('update-register-motive-gruppen.xsl', function() {
  return request("/queries/update.xql?name=register&register=motive-gruppen.xsl")
})


gulp.task(
  'update-register', gulp.series(
    "update-register-besitzer.xsl",
    "update-register-institution-institution.xsl",
    "update-register-institution-land.xsl",
    "update-register-motive-alphabetisch.xsl",
    "update-register-motive-gruppen.xsl",
  )
)


gulp.task('update-motive', function() {
  return request("/queries/update.xql?name=motive")
})



gulp.task('update-uebersichten-benachbarte-sprueche-absolut-gerade-max.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=benachbarte-sprueche-absolut-gerade-max.xql")
})
gulp.task('update-uebersichten-benachbarte-sprueche-absolut-gerade.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=benachbarte-sprueche-absolut-gerade.xql")
})
gulp.task('update-uebersichten-benachbarte-sprueche-absolut-max.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=benachbarte-sprueche-absolut-max.xql")
})
gulp.task('update-uebersichten-benachbarte-sprueche-absolut.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=benachbarte-sprueche-absolut.xql")
})
gulp.task('update-uebersichten-benachbarte-sprueche-relativ-max.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=benachbarte-sprueche-relativ-max.xql")
})
gulp.task('update-uebersichten-benachbarte-sprueche-relativ.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=benachbarte-sprueche-relativ.xql")
})
gulp.task('update-uebersichten-besitzer-verwandte.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=besitzer-verwandte.xsl")
})
gulp.task('update-uebersichten-bildmaterial.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=bildmaterial.xsl")
})
gulp.task('update-uebersichten-check.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=check.xsl")
})
gulp.task('update-uebersichten-datierung.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=datierung.xsl")
})
gulp.task('update-uebersichten-einzelsprueche.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=einzelsprueche.xql")
})
gulp.task('update-uebersichten-herkunft.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=herkunft.xsl")
})
gulp.task('update-uebersichten-objekte.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=objekte.xsl")
})
gulp.task('update-uebersichten-objektgruppen.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=objektgruppen.xsl")
})
gulp.task('update-uebersichten-objektzahl-pro-spruch.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=objektzahl-pro-spruch.xql")
})
gulp.task('update-uebersichten-schriften.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=schriften.xsl")
})
gulp.task('update-uebersichten-spruchgruppen.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=spruchgruppen.xql")
})
gulp.task('update-uebersichten-spruchnetz.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=spruchnetz.xql")
})
gulp.task('update-uebersichten-spruchvorkommen-nach-perioden.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=spruchvorkommen-nach-perioden.xql")
})
gulp.task('update-uebersichten-sprueche.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=sprueche.xql")
})
gulp.task('update-uebersichten-standorte.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=standorte.xsl")
})
gulp.task('update-uebersichten-vignettenstile.xsl', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=vignettenstile.xsl")
})
gulp.task('update-uebersichten-vorkommen-von-spruechen-und-vignetten-absolut.xql', function() {
  return request("/queries/update.xql?name=uebersichten&uebersicht=vorkommen-von-spruechen-und-vignetten-absolut.xql")
})

gulp.task(
'update-uebersichten', gulp.series(
  'update-uebersichten-benachbarte-sprueche-absolut-gerade.xql',
  'update-uebersichten-benachbarte-sprueche-absolut-gerade-max.xql',
  'update-uebersichten-benachbarte-sprueche-absolut-max.xql',
  'update-uebersichten-benachbarte-sprueche-absolut.xql',
  'update-uebersichten-benachbarte-sprueche-relativ-max.xql',
  'update-uebersichten-benachbarte-sprueche-relativ.xql',
  'update-uebersichten-einzelsprueche.xql',
  'update-uebersichten-besitzer-verwandte.xsl',
  'update-uebersichten-bildmaterial.xsl',
  'update-uebersichten-datierung.xsl',
  'update-uebersichten-herkunft.xsl',
  'update-uebersichten-objekte.xsl',
  'update-uebersichten-objektgruppen.xsl',
  'update-uebersichten-objektzahl-pro-spruch.xql',
  'update-uebersichten-schriften.xsl',
  'update-uebersichten-spruchgruppen.xql',
  'update-uebersichten-spruchnetz.xql',
  'update-uebersichten-spruchvorkommen-nach-perioden.xql',
  'update-uebersichten-sprueche.xql',
  'update-uebersichten-standorte.xsl',
  'update-uebersichten-vignettenstile.xsl',
  'update-uebersichten-vorkommen-von-spruechen-und-vignetten-absolut.xql',
  'update-uebersichten-check.xsl',
  'update-uebersichten-sprueche.xql'
  )
)


gulp.task(
'update-all', gulp.series(
  'update-basis',
  // 'update-fehlerreport',
  'update-auswahllisten',
  'update-register',
  'update-motive',
  'update-uebersichten',
  'update-navigation',
  )
)

gulp.task('create-user-groups', function() {
    return gulp.src('scripts/create-groups.xql')
    .pipe(existClient.query({}))
})

gulp.task('install-versioning-module', function() {
    return gulp.src('scripts/install-versioning-module.xql')
    .pipe(existClient.query({}))
})

gulp.task('install', gulp.series("upload-index-conf", "deploy", "install-versioning-module", "create-user-groups", "update-all"))
