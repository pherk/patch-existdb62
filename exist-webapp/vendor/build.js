({
    baseUrl: ".",
    paths: {
        requireLib: "awld/lib/requirejs/require",
        mustache: "awld/lib/mustache.0.5.0-dev",
        jquery: "awld/lib/jquery/jquery-1.7.2.min"
    },

    // namespace: "tbRequire",
    modules: [
           {
               name: "awld",
              override: {  
               baseUrl: "awld",
              },
              paths: {
                ui: "awld/ui"
              },
               include: ["requireLib", "mustache", "jquery", "types", "registry", "ui", "awld", "modules/arachne.uni-koeln.de/arachne.uni-koeln.de", "modules/ecatalogue.art.yale.edu/ecatalogue.art.yale.edu", "modules/eol/eol", "modules/finds.org.uk/finds.org.uk", "modules/geonames/place", "modules/loc/lccn", "modules/nomisma/nomisma", "modules/numismatics.org/numismatics.org", "modules/opencontext/opencontext", "modules/papyri.info/text", "modules/pelagios.dme.ait.ac.at/place", "modules/perseus/smith", "modules/perseus/urn-cts", "modules/pleiades/place", "modules/trismegistos/text", "modules/wikipedia/page", "modules/worldcat/oclc", "modules/www.smb.museum/www.smb.museum", "modules/www.sudoc.fr/www.sudoc.fr"],
               //True tells the optimizer it is OK to create
               //a new file foo.js. Normally the optimizer
               //wants foo.js to exist in the source directory.
               create: true
           },
           {
               name: "openseadragon",
               include: ["requireLib", "openseadragon/openseadragon"],
               //True tells the optimizer it is OK to create
               //a new file foo.js. Normally the optimizer
               //wants foo.js to exist in the source directory.
               create: true
           }
       ],

       dir: "build",
       optimize: "none",
       wrap: {
        start: "(function() {  ",
        end: "}());"
       },
       inlineText: "false"
})
