(function() {  
/** vim: et:ts=4:sw=4:sts=4
 * @license RequireJS 1.0.7 Copyright (c) 2010-2012, The Dojo Foundation All Rights Reserved.
 * Available via the MIT or new BSD license.
 * see: http://github.com/jrburke/requirejs for details
 */
/*jslint strict: false, plusplus: false, sub: true */
/*global window, navigator, document, importScripts, jQuery, setTimeout, opera */

var requirejs, require, define;
(function () {
    //Change this version number for each release.
    var version = "1.0.7",
        commentRegExp = /(\/\*([\s\S]*?)\*\/|([^:]|^)\/\/(.*)$)/mg,
        cjsRequireRegExp = /require\(\s*["']([^'"\s]+)["']\s*\)/g,
        currDirRegExp = /^\.\//,
        jsSuffixRegExp = /\.js$/,
        ostring = Object.prototype.toString,
        ap = Array.prototype,
        aps = ap.slice,
        apsp = ap.splice,
        isBrowser = !!(typeof window !== "undefined" && navigator && document),
        isWebWorker = !isBrowser && typeof importScripts !== "undefined",
        //PS3 indicates loaded and complete, but need to wait for complete
        //specifically. Sequence is "loading", "loaded", execution,
        // then "complete". The UA check is unfortunate, but not sure how
        //to feature test w/o causing perf issues.
        readyRegExp = isBrowser && navigator.platform === 'PLAYSTATION 3' ?
                      /^complete$/ : /^(complete|loaded)$/,
        defContextName = "_",
        //Oh the tragedy, detecting opera. See the usage of isOpera for reason.
        isOpera = typeof opera !== "undefined" && opera.toString() === "[object Opera]",
        empty = {},
        contexts = {},
        globalDefQueue = [],
        interactiveScript = null,
        checkLoadedDepth = 0,
        useInteractive = false,
        reservedDependencies = {
            require: true,
            module: true,
            exports: true
        },
        req, cfg = {}, currentlyAddingScript, s, head, baseElement, scripts, script,
        src, subPath, mainScript, dataMain, globalI, ctx, jQueryCheck, checkLoadedTimeoutId;

    function isFunction(it) {
        return ostring.call(it) === "[object Function]";
    }

    function isArray(it) {
        return ostring.call(it) === "[object Array]";
    }

    /**
     * Simple function to mix in properties from source into target,
     * but only if target does not already have a property of the same name.
     * This is not robust in IE for transferring methods that match
     * Object.prototype names, but the uses of mixin here seem unlikely to
     * trigger a problem related to that.
     */
    function mixin(target, source, force) {
        for (var prop in source) {
            if (!(prop in empty) && (!(prop in target) || force)) {
                target[prop] = source[prop];
            }
        }
        return req;
    }

    /**
     * Constructs an error with a pointer to an URL with more information.
     * @param {String} id the error ID that maps to an ID on a web page.
     * @param {String} message human readable error.
     * @param {Error} [err] the original error, if there is one.
     *
     * @returns {Error}
     */
    function makeError(id, msg, err) {
        var e = new Error(msg + '\nhttp://requirejs.org/docs/errors.html#' + id);
        if (err) {
            e.originalError = err;
        }
        return e;
    }

    /**
     * Used to set up package paths from a packagePaths or packages config object.
     * @param {Object} pkgs the object to store the new package config
     * @param {Array} currentPackages an array of packages to configure
     * @param {String} [dir] a prefix dir to use.
     */
    function configurePackageDir(pkgs, currentPackages, dir) {
        var i, location, pkgObj;

        for (i = 0; (pkgObj = currentPackages[i]); i++) {
            pkgObj = typeof pkgObj === "string" ? { name: pkgObj } : pkgObj;
            location = pkgObj.location;

            //Add dir to the path, but avoid paths that start with a slash
            //or have a colon (indicates a protocol)
            if (dir && (!location || (location.indexOf("/") !== 0 && location.indexOf(":") === -1))) {
                location = dir + "/" + (location || pkgObj.name);
            }

            //Create a brand new object on pkgs, since currentPackages can
            //be passed in again, and config.pkgs is the internal transformed
            //state for all package configs.
            pkgs[pkgObj.name] = {
                name: pkgObj.name,
                location: location || pkgObj.name,
                //Remove leading dot in main, so main paths are normalized,
                //and remove any trailing .js, since different package
                //envs have different conventions: some use a module name,
                //some use a file name.
                main: (pkgObj.main || "main")
                      .replace(currDirRegExp, '')
                      .replace(jsSuffixRegExp, '')
            };
        }
    }

    /**
     * jQuery 1.4.3-1.5.x use a readyWait/ready() pairing to hold DOM
     * ready callbacks, but jQuery 1.6 supports a holdReady() API instead.
     * At some point remove the readyWait/ready() support and just stick
     * with using holdReady.
     */
    function jQueryHoldReady($, shouldHold) {
        if ($.holdReady) {
            $.holdReady(shouldHold);
        } else if (shouldHold) {
            $.readyWait += 1;
        } else {
            $.ready(true);
        }
    }

    if (typeof define !== "undefined") {
        //If a define is already in play via another AMD loader,
        //do not overwrite.
        return;
    }

    if (typeof requirejs !== "undefined") {
        if (isFunction(requirejs)) {
            //Do not overwrite and existing requirejs instance.
            return;
        } else {
            cfg = requirejs;
            requirejs = undefined;
        }
    }

    //Allow for a require config object
    if (typeof require !== "undefined" && !isFunction(require)) {
        //assume it is a config object.
        cfg = require;
        require = undefined;
    }

    /**
     * Creates a new context for use in require and define calls.
     * Handle most of the heavy lifting. Do not want to use an object
     * with prototype here to avoid using "this" in require, in case it
     * needs to be used in more super secure envs that do not want this.
     * Also there should not be that many contexts in the page. Usually just
     * one for the default context, but could be extra for multiversion cases
     * or if a package needs a special context for a dependency that conflicts
     * with the standard context.
     */
    function newContext(contextName) {
        var context, resume,
            config = {
                waitSeconds: 7,
                baseUrl: "./",
                paths: {},
                pkgs: {},
                catchError: {}
            },
            defQueue = [],
            specified = {
                "require": true,
                "exports": true,
                "module": true
            },
            urlMap = {},
            defined = {},
            loaded = {},
            waiting = {},
            waitAry = [],
            urlFetched = {},
            managerCounter = 0,
            managerCallbacks = {},
            plugins = {},
            //Used to indicate which modules in a build scenario
            //need to be full executed.
            needFullExec = {},
            fullExec = {},
            resumeDepth = 0;

        /**
         * Trims the . and .. from an array of path segments.
         * It will keep a leading path segment if a .. will become
         * the first path segment, to help with module name lookups,
         * which act like paths, but can be remapped. But the end result,
         * all paths that use this function should look normalized.
         * NOTE: this method MODIFIES the input array.
         * @param {Array} ary the array of path segments.
         */
        function trimDots(ary) {
            var i, part;
            for (i = 0; (part = ary[i]); i++) {
                if (part === ".") {
                    ary.splice(i, 1);
                    i -= 1;
                } else if (part === "..") {
                    if (i === 1 && (ary[2] === '..' || ary[0] === '..')) {
                        //End of the line. Keep at least one non-dot
                        //path segment at the front so it can be mapped
                        //correctly to disk. Otherwise, there is likely
                        //no path mapping for a path starting with '..'.
                        //This can still fail, but catches the most reasonable
                        //uses of ..
                        break;
                    } else if (i > 0) {
                        ary.splice(i - 1, 2);
                        i -= 2;
                    }
                }
            }
        }

        /**
         * Given a relative module name, like ./something, normalize it to
         * a real name that can be mapped to a path.
         * @param {String} name the relative name
         * @param {String} baseName a real name that the name arg is relative
         * to.
         * @returns {String} normalized name
         */
        function normalize(name, baseName) {
            var pkgName, pkgConfig;

            //Adjust any relative paths.
            if (name && name.charAt(0) === ".") {
                //If have a base name, try to normalize against it,
                //otherwise, assume it is a top-level require that will
                //be relative to baseUrl in the end.
                if (baseName) {
                    if (config.pkgs[baseName]) {
                        //If the baseName is a package name, then just treat it as one
                        //name to concat the name with.
                        baseName = [baseName];
                    } else {
                        //Convert baseName to array, and lop off the last part,
                        //so that . matches that "directory" and not name of the baseName's
                        //module. For instance, baseName of "one/two/three", maps to
                        //"one/two/three.js", but we want the directory, "one/two" for
                        //this normalization.
                        baseName = baseName.split("/");
                        baseName = baseName.slice(0, baseName.length - 1);
                    }

                    name = baseName.concat(name.split("/"));
                    trimDots(name);

                    //Some use of packages may use a . path to reference the
                    //"main" module name, so normalize for that.
                    pkgConfig = config.pkgs[(pkgName = name[0])];
                    name = name.join("/");
                    if (pkgConfig && name === pkgName + '/' + pkgConfig.main) {
                        name = pkgName;
                    }
                } else if (name.indexOf("./") === 0) {
                    // No baseName, so this is ID is resolved relative
                    // to baseUrl, pull off the leading dot.
                    name = name.substring(2);
                }
            }
            return name;
        }

        /**
         * Creates a module mapping that includes plugin prefix, module
         * name, and path. If parentModuleMap is provided it will
         * also normalize the name via require.normalize()
         *
         * @param {String} name the module name
         * @param {String} [parentModuleMap] parent module map
         * for the module name, used to resolve relative names.
         *
         * @returns {Object}
         */
        function makeModuleMap(name, parentModuleMap) {
            var index = name ? name.indexOf("!") : -1,
                prefix = null,
                parentName = parentModuleMap ? parentModuleMap.name : null,
                originalName = name,
                normalizedName, url, pluginModule;

            if (index !== -1) {
                prefix = name.substring(0, index);
                name = name.substring(index + 1, name.length);
            }

            if (prefix) {
                prefix = normalize(prefix, parentName);
            }

            //Account for relative paths if there is a base name.
            if (name) {
                if (prefix) {
                    pluginModule = defined[prefix];
                    if (pluginModule && pluginModule.normalize) {
                        //Plugin is loaded, use its normalize method.
                        normalizedName = pluginModule.normalize(name, function (name) {
                            return normalize(name, parentName);
                        });
                    } else {
                        normalizedName = normalize(name, parentName);
                    }
                } else {
                    //A regular module.
                    normalizedName = normalize(name, parentName);

                    url = urlMap[normalizedName];
                    if (!url) {
                        //Calculate url for the module, if it has a name.
                        //Use name here since nameToUrl also calls normalize,
                        //and for relative names that are outside the baseUrl
                        //this causes havoc. Was thinking of just removing
                        //parentModuleMap to avoid extra normalization, but
                        //normalize() still does a dot removal because of
                        //issue #142, so just pass in name here and redo
                        //the normalization. Paths outside baseUrl are just
                        //messy to support.
                        url = context.nameToUrl(name, null, parentModuleMap);

                        //Store the URL mapping for later.
                        urlMap[normalizedName] = url;
                    }
                }
            }

            return {
                prefix: prefix,
                name: normalizedName,
                parentMap: parentModuleMap,
                url: url,
                originalName: originalName,
                fullName: prefix ? prefix + "!" + (normalizedName || '') : normalizedName
            };
        }

        /**
         * Determine if priority loading is done. If so clear the priorityWait
         */
        function isPriorityDone() {
            var priorityDone = true,
                priorityWait = config.priorityWait,
                priorityName, i;
            if (priorityWait) {
                for (i = 0; (priorityName = priorityWait[i]); i++) {
                    if (!loaded[priorityName]) {
                        priorityDone = false;
                        break;
                    }
                }
                if (priorityDone) {
                    delete config.priorityWait;
                }
            }
            return priorityDone;
        }

        function makeContextModuleFunc(func, relModuleMap, enableBuildCallback) {
            return function () {
                //A version of a require function that passes a moduleName
                //value for items that may need to
                //look up paths relative to the moduleName
                var args = aps.call(arguments, 0), lastArg;
                if (enableBuildCallback &&
                    isFunction((lastArg = args[args.length - 1]))) {
                    lastArg.__requireJsBuild = true;
                }
                args.push(relModuleMap);
                return func.apply(null, args);
            };
        }

        /**
         * Helper function that creates a require function object to give to
         * modules that ask for it as a dependency. It needs to be specific
         * per module because of the implication of path mappings that may
         * need to be relative to the module name.
         */
        function makeRequire(relModuleMap, enableBuildCallback, altRequire) {
            var modRequire = makeContextModuleFunc(altRequire || context.require, relModuleMap, enableBuildCallback);

            mixin(modRequire, {
                nameToUrl: makeContextModuleFunc(context.nameToUrl, relModuleMap),
                toUrl: makeContextModuleFunc(context.toUrl, relModuleMap),
                defined: makeContextModuleFunc(context.requireDefined, relModuleMap),
                specified: makeContextModuleFunc(context.requireSpecified, relModuleMap),
                isBrowser: req.isBrowser
            });
            return modRequire;
        }

        /*
         * Queues a dependency for checking after the loader is out of a
         * "paused" state, for example while a script file is being loaded
         * in the browser, where it may have many modules defined in it.
         */
        function queueDependency(manager) {
            context.paused.push(manager);
        }

        function execManager(manager) {
            var i, ret, err, errFile, errModuleTree,
                cb = manager.callback,
                map = manager.map,
                fullName = map.fullName,
                args = manager.deps,
                listeners = manager.listeners,
                cjsModule;

            //Call the callback to define the module, if necessary.
            if (cb && isFunction(cb)) {
                if (config.catchError.define) {
                    try {
                        ret = req.execCb(fullName, manager.callback, args, defined[fullName]);
                    } catch (e) {
                        err = e;
                    }
                } else {
                    ret = req.execCb(fullName, manager.callback, args, defined[fullName]);
                }

                if (fullName) {
                    //If setting exports via "module" is in play,
                    //favor that over return value and exports. After that,
                    //favor a non-undefined return value over exports use.
                    cjsModule = manager.cjsModule;
                    if (cjsModule &&
                        cjsModule.exports !== undefined &&
                        //Make sure it is not already the exports value
                        cjsModule.exports !== defined[fullName]) {
                        ret = defined[fullName] = manager.cjsModule.exports;
                    } else if (ret === undefined && manager.usingExports) {
                        //exports already set the defined value.
                        ret = defined[fullName];
                    } else {
                        //Use the return value from the function.
                        defined[fullName] = ret;
                        //If this module needed full execution in a build
                        //environment, mark that now.
                        if (needFullExec[fullName]) {
                            fullExec[fullName] = true;
                        }
                    }
                }
            } else if (fullName) {
                //May just be an object definition for the module. Only
                //worry about defining if have a module name.
                ret = defined[fullName] = cb;

                //If this module needed full execution in a build
                //environment, mark that now.
                if (needFullExec[fullName]) {
                    fullExec[fullName] = true;
                }
            }

            //Clean up waiting. Do this before error calls, and before
            //calling back listeners, so that bookkeeping is correct
            //in the event of an error and error is reported in correct order,
            //since the listeners will likely have errors if the
            //onError function does not throw.
            if (waiting[manager.id]) {
                delete waiting[manager.id];
                manager.isDone = true;
                context.waitCount -= 1;
                if (context.waitCount === 0) {
                    //Clear the wait array used for cycles.
                    waitAry = [];
                }
            }

            //Do not need to track manager callback now that it is defined.
            delete managerCallbacks[fullName];

            //Allow instrumentation like the optimizer to know the order
            //of modules executed and their dependencies.
            if (req.onResourceLoad && !manager.placeholder) {
                req.onResourceLoad(context, map, manager.depArray);
            }

            if (err) {
                errFile = (fullName ? makeModuleMap(fullName).url : '') ||
                           err.fileName || err.sourceURL;
                errModuleTree = err.moduleTree;
                err = makeError('defineerror', 'Error evaluating ' +
                                'module "' + fullName + '" at location "' +
                                errFile + '":\n' +
                                err + '\nfileName:' + errFile +
                                '\nlineNumber: ' + (err.lineNumber || err.line), err);
                err.moduleName = fullName;
                err.moduleTree = errModuleTree;
                return req.onError(err);
            }

            //Let listeners know of this manager's value.
            for (i = 0; (cb = listeners[i]); i++) {
                cb(ret);
            }

            return undefined;
        }

        /**
         * Helper that creates a callack function that is called when a dependency
         * is ready, and sets the i-th dependency for the manager as the
         * value passed to the callback generated by this function.
         */
        function makeArgCallback(manager, i) {
            return function (value) {
                //Only do the work if it has not been done
                //already for a dependency. Cycle breaking
                //logic in forceExec could mean this function
                //is called more than once for a given dependency.
                if (!manager.depDone[i]) {
                    manager.depDone[i] = true;
                    manager.deps[i] = value;
                    manager.depCount -= 1;
                    if (!manager.depCount) {
                        //All done, execute!
                        execManager(manager);
                    }
                }
            };
        }

        function callPlugin(pluginName, depManager) {
            var map = depManager.map,
                fullName = map.fullName,
                name = map.name,
                plugin = plugins[pluginName] ||
                        (plugins[pluginName] = defined[pluginName]),
                load;

            //No need to continue if the manager is already
            //in the process of loading.
            if (depManager.loading) {
                return;
            }
            depManager.loading = true;

            load = function (ret) {
                depManager.callback = function () {
                    return ret;
                };
                execManager(depManager);

                loaded[depManager.id] = true;

                //The loading of this plugin
                //might have placed other things
                //in the paused queue. In particular,
                //a loader plugin that depends on
                //a different plugin loaded resource.
                resume();
            };

            //Allow plugins to load other code without having to know the
            //context or how to "complete" the load.
            load.fromText = function (moduleName, text) {
                /*jslint evil: true */
                var hasInteractive = useInteractive;

                //Indicate a the module is in process of loading.
                loaded[moduleName] = false;
                context.scriptCount += 1;

                //Indicate this is not a "real" module, so do not track it
                //for builds, it does not map to a real file.
                context.fake[moduleName] = true;

                //Turn off interactive script matching for IE for any define
                //calls in the text, then turn it back on at the end.
                if (hasInteractive) {
                    useInteractive = false;
                }

                req.exec(text);

                if (hasInteractive) {
                    useInteractive = true;
                }

                //Support anonymous modules.
                context.completeLoad(moduleName);
            };

            //No need to continue if the plugin value has already been
            //defined by a build.
            if (fullName in defined) {
                load(defined[fullName]);
            } else {
                //Use parentName here since the plugin's name is not reliable,
                //could be some weird string with no path that actually wants to
                //reference the parentName's path.
                plugin.load(name, makeRequire(map.parentMap, true, function (deps, cb) {
                    var moduleDeps = [],
                        i, dep, depMap;
                    //Convert deps to full names and hold on to them
                    //for reference later, when figuring out if they
                    //are blocked by a circular dependency.
                    for (i = 0; (dep = deps[i]); i++) {
                        depMap = makeModuleMap(dep, map.parentMap);
                        deps[i] = depMap.fullName;
                        if (!depMap.prefix) {
                            moduleDeps.push(deps[i]);
                        }
                    }
                    depManager.moduleDeps = (depManager.moduleDeps || []).concat(moduleDeps);
                    return context.require(deps, cb);
                }), load, config);
            }
        }

        /**
         * Adds the manager to the waiting queue. Only fully
         * resolved items should be in the waiting queue.
         */
        function addWait(manager) {
            if (!waiting[manager.id]) {
                waiting[manager.id] = manager;
                waitAry.push(manager);
                context.waitCount += 1;
            }
        }

        /**
         * Function added to every manager object. Created out here
         * to avoid new function creation for each manager instance.
         */
        function managerAdd(cb) {
            this.listeners.push(cb);
        }

        function getManager(map, shouldQueue) {
            var fullName = map.fullName,
                prefix = map.prefix,
                plugin = prefix ? plugins[prefix] ||
                                (plugins[prefix] = defined[prefix]) : null,
                manager, created, pluginManager, prefixMap;

            if (fullName) {
                manager = managerCallbacks[fullName];
            }

            if (!manager) {
                created = true;
                manager = {
                    //ID is just the full name, but if it is a plugin resource
                    //for a plugin that has not been loaded,
                    //then add an ID counter to it.
                    id: (prefix && !plugin ?
                        (managerCounter++) + '__p@:' : '') +
                        (fullName || '__r@' + (managerCounter++)),
                    map: map,
                    depCount: 0,
                    depDone: [],
                    depCallbacks: [],
                    deps: [],
                    listeners: [],
                    add: managerAdd
                };

                specified[manager.id] = true;

                //Only track the manager/reuse it if this is a non-plugin
                //resource. Also only track plugin resources once
                //the plugin has been loaded, and so the fullName is the
                //true normalized value.
                if (fullName && (!prefix || plugins[prefix])) {
                    managerCallbacks[fullName] = manager;
                }
            }

            //If there is a plugin needed, but it is not loaded,
            //first load the plugin, then continue on.
            if (prefix && !plugin) {
                prefixMap = makeModuleMap(prefix);

                //Clear out defined and urlFetched if the plugin was previously
                //loaded/defined, but not as full module (as in a build
                //situation). However, only do this work if the plugin is in
                //defined but does not have a module export value.
                if (prefix in defined && !defined[prefix]) {
                    delete defined[prefix];
                    delete urlFetched[prefixMap.url];
                }

                pluginManager = getManager(prefixMap, true);
                pluginManager.add(function (plugin) {
                    //Create a new manager for the normalized
                    //resource ID and have it call this manager when
                    //done.
                    var newMap = makeModuleMap(map.originalName, map.parentMap),
                        normalizedManager = getManager(newMap, true);

                    //Indicate this manager is a placeholder for the real,
                    //normalized thing. Important for when trying to map
                    //modules and dependencies, for instance, in a build.
                    manager.placeholder = true;

                    normalizedManager.add(function (resource) {
                        manager.callback = function () {
                            return resource;
                        };
                        execManager(manager);
                    });
                });
            } else if (created && shouldQueue) {
                //Indicate the resource is not loaded yet if it is to be
                //queued.
                loaded[manager.id] = false;
                queueDependency(manager);
                addWait(manager);
            }

            return manager;
        }

        function main(inName, depArray, callback, relModuleMap) {
            var moduleMap = makeModuleMap(inName, relModuleMap),
                name = moduleMap.name,
                fullName = moduleMap.fullName,
                manager = getManager(moduleMap),
                id = manager.id,
                deps = manager.deps,
                i, depArg, depName, depPrefix, cjsMod;

            if (fullName) {
                //If module already defined for context, or already loaded,
                //then leave. Also leave if jQuery is registering but it does
                //not match the desired version number in the config.
                if (fullName in defined || loaded[id] === true ||
                    (fullName === "jquery" && config.jQuery &&
                     config.jQuery !== callback().fn.jquery)) {
                    return;
                }

                //Set specified/loaded here for modules that are also loaded
                //as part of a layer, where onScriptLoad is not fired
                //for those cases. Do this after the inline define and
                //dependency tracing is done.
                specified[id] = true;
                loaded[id] = true;

                //If module is jQuery set up delaying its dom ready listeners.
                if (fullName === "jquery" && callback) {
                    jQueryCheck(callback());
                }
            }

            //Attach real depArray and callback to the manager. Do this
            //only if the module has not been defined already, so do this after
            //the fullName checks above. IE can call main() more than once
            //for a module.
            manager.depArray = depArray;
            manager.callback = callback;

            //Add the dependencies to the deps field, and register for callbacks
            //on the dependencies.
            for (i = 0; i < depArray.length; i++) {
                depArg = depArray[i];
                //There could be cases like in IE, where a trailing comma will
                //introduce a null dependency, so only treat a real dependency
                //value as a dependency.
                if (depArg) {
                    //Split the dependency name into plugin and name parts
                    depArg = makeModuleMap(depArg, (name ? moduleMap : relModuleMap));
                    depName = depArg.fullName;
                    depPrefix = depArg.prefix;

                    //Fix the name in depArray to be just the name, since
                    //that is how it will be called back later.
                    depArray[i] = depName;

                    //Fast path CommonJS standard dependencies.
                    if (depName === "require") {
                        deps[i] = makeRequire(moduleMap);
                    } else if (depName === "exports") {
                        //CommonJS module spec 1.1
                        deps[i] = defined[fullName] = {};
                        manager.usingExports = true;
                    } else if (depName === "module") {
                        //CommonJS module spec 1.1
                        manager.cjsModule = cjsMod = deps[i] = {
                            id: name,
                            uri: name ? context.nameToUrl(name, null, relModuleMap) : undefined,
                            exports: defined[fullName]
                        };
                    } else if (depName in defined && !(depName in waiting) &&
                               (!(fullName in needFullExec) ||
                                (fullName in needFullExec && fullExec[depName]))) {
                        //Module already defined, and not in a build situation
                        //where the module is a something that needs full
                        //execution and this dependency has not been fully
                        //executed. See r.js's requirePatch.js for more info
                        //on fullExec.
                        deps[i] = defined[depName];
                    } else {
                        //Mark this dependency as needing full exec if
                        //the current module needs full exec.
                        if (fullName in needFullExec) {
                            needFullExec[depName] = true;
                            //Reset state so fully executed code will get
                            //picked up correctly.
                            delete defined[depName];
                            urlFetched[depArg.url] = false;
                        }

                        //Either a resource that is not loaded yet, or a plugin
                        //resource for either a plugin that has not
                        //loaded yet.
                        manager.depCount += 1;
                        manager.depCallbacks[i] = makeArgCallback(manager, i);
                        getManager(depArg, true).add(manager.depCallbacks[i]);
                    }
                }
            }

            //Do not bother tracking the manager if it is all done.
            if (!manager.depCount) {
                //All done, execute!
                execManager(manager);
            } else {
                addWait(manager);
            }
        }

        /**
         * Convenience method to call main for a define call that was put on
         * hold in the defQueue.
         */
        function callDefMain(args) {
            main.apply(null, args);
        }

        /**
         * jQuery 1.4.3+ supports ways to hold off calling
         * calling jQuery ready callbacks until all scripts are loaded. Be sure
         * to track it if the capability exists.. Also, since jQuery 1.4.3 does
         * not register as a module, need to do some global inference checking.
         * Even if it does register as a module, not guaranteed to be the precise
         * name of the global. If a jQuery is tracked for this context, then go
         * ahead and register it as a module too, if not already in process.
         */
        jQueryCheck = function (jqCandidate) {
            if (!context.jQuery) {
                var $ = jqCandidate || (typeof jQuery !== "undefined" ? jQuery : null);

                if ($) {
                    //If a specific version of jQuery is wanted, make sure to only
                    //use this jQuery if it matches.
                    if (config.jQuery && $.fn.jquery !== config.jQuery) {
                        return;
                    }

                    if ("holdReady" in $ || "readyWait" in $) {
                        context.jQuery = $;

                        //Manually create a "jquery" module entry if not one already
                        //or in process. Note this could trigger an attempt at
                        //a second jQuery registration, but does no harm since
                        //the first one wins, and it is the same value anyway.
                        callDefMain(["jquery", [], function () {
                            return jQuery;
                        }]);

                        //Ask jQuery to hold DOM ready callbacks.
                        if (context.scriptCount) {
                            jQueryHoldReady($, true);
                            context.jQueryIncremented = true;
                        }
                    }
                }
            }
        };

        function findCycle(manager, traced) {
            var fullName = manager.map.fullName,
                depArray = manager.depArray,
                fullyLoaded = true,
                i, depName, depManager, result;

            if (manager.isDone || !fullName || !loaded[fullName]) {
                return result;
            }

            //Found the cycle.
            if (traced[fullName]) {
                return manager;
            }

            traced[fullName] = true;

            //Trace through the dependencies.
            if (depArray) {
                for (i = 0; i < depArray.length; i++) {
                    //Some array members may be null, like if a trailing comma
                    //IE, so do the explicit [i] access and check if it has a value.
                    depName = depArray[i];
                    if (!loaded[depName] && !reservedDependencies[depName]) {
                        fullyLoaded = false;
                        break;
                    }
                    depManager = waiting[depName];
                    if (depManager && !depManager.isDone && loaded[depName]) {
                        result = findCycle(depManager, traced);
                        if (result) {
                            break;
                        }
                    }
                }
                if (!fullyLoaded) {
                    //Discard the cycle that was found, since it cannot
                    //be forced yet. Also clear this module from traced.
                    result = undefined;
                    delete traced[fullName];
                }
            }

            return result;
        }

        function forceExec(manager, traced) {
            var fullName = manager.map.fullName,
                depArray = manager.depArray,
                i, depName, depManager, prefix, prefixManager, value;


            if (manager.isDone || !fullName || !loaded[fullName]) {
                return undefined;
            }

            if (fullName) {
                if (traced[fullName]) {
                    return defined[fullName];
                }

                traced[fullName] = true;
            }

            //Trace through the dependencies.
            if (depArray) {
                for (i = 0; i < depArray.length; i++) {
                    //Some array members may be null, like if a trailing comma
                    //IE, so do the explicit [i] access and check if it has a value.
                    depName = depArray[i];
                    if (depName) {
                        //First, make sure if it is a plugin resource that the
                        //plugin is not blocked.
                        prefix = makeModuleMap(depName).prefix;
                        if (prefix && (prefixManager = waiting[prefix])) {
                            forceExec(prefixManager, traced);
                        }
                        depManager = waiting[depName];
                        if (depManager && !depManager.isDone && loaded[depName]) {
                            value = forceExec(depManager, traced);
                            manager.depCallbacks[i](value);
                        }
                    }
                }
            }

            return defined[fullName];
        }

        /**
         * Checks if all modules for a context are loaded, and if so, evaluates the
         * new ones in right dependency order.
         *
         * @private
         */
        function checkLoaded() {
            var waitInterval = config.waitSeconds * 1000,
                //It is possible to disable the wait interval by using waitSeconds of 0.
                expired = waitInterval && (context.startTime + waitInterval) < new Date().getTime(),
                noLoads = "", hasLoadedProp = false, stillLoading = false,
                cycleDeps = [],
                i, prop, err, manager, cycleManager, moduleDeps;

            //If there are items still in the paused queue processing wait.
            //This is particularly important in the sync case where each paused
            //item is processed right away but there may be more waiting.
            if (context.pausedCount > 0) {
                return undefined;
            }

            //Determine if priority loading is done. If so clear the priority. If
            //not, then do not check
            if (config.priorityWait) {
                if (isPriorityDone()) {
                    //Call resume, since it could have
                    //some waiting dependencies to trace.
                    resume();
                } else {
                    return undefined;
                }
            }

            //See if anything is still in flight.
            for (prop in loaded) {
                if (!(prop in empty)) {
                    hasLoadedProp = true;
                    if (!loaded[prop]) {
                        if (expired) {
                            noLoads += prop + " ";
                        } else {
                            stillLoading = true;
                            if (prop.indexOf('!') === -1) {
                                //No reason to keep looking for unfinished
                                //loading. If the only stillLoading is a
                                //plugin resource though, keep going,
                                //because it may be that a plugin resource
                                //is waiting on a non-plugin cycle.
                                cycleDeps = [];
                                break;
                            } else {
                                moduleDeps = managerCallbacks[prop] && managerCallbacks[prop].moduleDeps;
                                if (moduleDeps) {
                                    cycleDeps.push.apply(cycleDeps, moduleDeps);
                                }
                            }
                        }
                    }
                }
            }

            //Check for exit conditions.
            if (!hasLoadedProp && !context.waitCount) {
                //If the loaded object had no items, then the rest of
                //the work below does not need to be done.
                return undefined;
            }
            if (expired && noLoads) {
                //If wait time expired, throw error of unloaded modules.
                err = makeError("timeout", "Load timeout for modules: " + noLoads);
                err.requireType = "timeout";
                err.requireModules = noLoads;
                err.contextName = context.contextName;
                return req.onError(err);
            }

            //If still loading but a plugin is waiting on a regular module cycle
            //break the cycle.
            if (stillLoading && cycleDeps.length) {
                for (i = 0; (manager = waiting[cycleDeps[i]]); i++) {
                    if ((cycleManager = findCycle(manager, {}))) {
                        forceExec(cycleManager, {});
                        break;
                    }
                }

            }

            //If still waiting on loads, and the waiting load is something
            //other than a plugin resource, or there are still outstanding
            //scripts, then just try back later.
            if (!expired && (stillLoading || context.scriptCount)) {
                //Something is still waiting to load. Wait for it, but only
                //if a timeout is not already in effect.
                if ((isBrowser || isWebWorker) && !checkLoadedTimeoutId) {
                    checkLoadedTimeoutId = setTimeout(function () {
                        checkLoadedTimeoutId = 0;
                        checkLoaded();
                    }, 50);
                }
                return undefined;
            }

            //If still have items in the waiting cue, but all modules have
            //been loaded, then it means there are some circular dependencies
            //that need to be broken.
            //However, as a waiting thing is fired, then it can add items to
            //the waiting cue, and those items should not be fired yet, so
            //make sure to redo the checkLoaded call after breaking a single
            //cycle, if nothing else loaded then this logic will pick it up
            //again.
            if (context.waitCount) {
                //Cycle through the waitAry, and call items in sequence.
                for (i = 0; (manager = waitAry[i]); i++) {
                    forceExec(manager, {});
                }

                //If anything got placed in the paused queue, run it down.
                if (context.paused.length) {
                    resume();
                }

                //Only allow this recursion to a certain depth. Only
                //triggered by errors in calling a module in which its
                //modules waiting on it cannot finish loading, or some circular
                //dependencies that then may add more dependencies.
                //The value of 5 is a bit arbitrary. Hopefully just one extra
                //pass, or two for the case of circular dependencies generating
                //more work that gets resolved in the sync node case.
                if (checkLoadedDepth < 5) {
                    checkLoadedDepth += 1;
                    checkLoaded();
                }
            }

            checkLoadedDepth = 0;

            //Check for DOM ready, and nothing is waiting across contexts.
            req.checkReadyState();

            return undefined;
        }

        /**
         * Resumes tracing of dependencies and then checks if everything is loaded.
         */
        resume = function () {
            var manager, map, url, i, p, args, fullName;

            //Any defined modules in the global queue, intake them now.
            context.takeGlobalQueue();

            resumeDepth += 1;

            if (context.scriptCount <= 0) {
                //Synchronous envs will push the number below zero with the
                //decrement above, be sure to set it back to zero for good measure.
                //require() calls that also do not end up loading scripts could
                //push the number negative too.
                context.scriptCount = 0;
            }

            //Make sure any remaining defQueue items get properly processed.
            while (defQueue.length) {
                args = defQueue.shift();
                if (args[0] === null) {
                    return req.onError(makeError('mismatch', 'Mismatched anonymous define() module: ' + args[args.length - 1]));
                } else {
                    callDefMain(args);
                }
            }

            //Skip the resume of paused dependencies
            //if current context is in priority wait.
            if (!config.priorityWait || isPriorityDone()) {
                while (context.paused.length) {
                    p = context.paused;
                    context.pausedCount += p.length;
                    //Reset paused list
                    context.paused = [];

                    for (i = 0; (manager = p[i]); i++) {
                        map = manager.map;
                        url = map.url;
                        fullName = map.fullName;

                        //If the manager is for a plugin managed resource,
                        //ask the plugin to load it now.
                        if (map.prefix) {
                            callPlugin(map.prefix, manager);
                        } else {
                            //Regular dependency.
                            if (!urlFetched[url] && !loaded[fullName]) {
                                req.load(context, fullName, url);

                                //Mark the URL as fetched, but only if it is
                                //not an empty: URL, used by the optimizer.
                                //In that case we need to be sure to call
                                //load() for each module that is mapped to
                                //empty: so that dependencies are satisfied
                                //correctly.
                                if (url.indexOf('empty:') !== 0) {
                                    urlFetched[url] = true;
                                }
                            }
                        }
                    }

                    //Move the start time for timeout forward.
                    context.startTime = (new Date()).getTime();
                    context.pausedCount -= p.length;
                }
            }

            //Only check if loaded when resume depth is 1. It is likely that
            //it is only greater than 1 in sync environments where a factory
            //function also then calls the callback-style require. In those
            //cases, the checkLoaded should not occur until the resume
            //depth is back at the top level.
            if (resumeDepth === 1) {
                checkLoaded();
            }

            resumeDepth -= 1;

            return undefined;
        };

        //Define the context object. Many of these fields are on here
        //just to make debugging easier.
        context = {
            contextName: contextName,
            config: config,
            defQueue: defQueue,
            waiting: waiting,
            waitCount: 0,
            specified: specified,
            loaded: loaded,
            urlMap: urlMap,
            urlFetched: urlFetched,
            scriptCount: 0,
            defined: defined,
            paused: [],
            pausedCount: 0,
            plugins: plugins,
            needFullExec: needFullExec,
            fake: {},
            fullExec: fullExec,
            managerCallbacks: managerCallbacks,
            makeModuleMap: makeModuleMap,
            normalize: normalize,
            /**
             * Set a configuration for the context.
             * @param {Object} cfg config object to integrate.
             */
            configure: function (cfg) {
                var paths, prop, packages, pkgs, packagePaths, requireWait;

                //Make sure the baseUrl ends in a slash.
                if (cfg.baseUrl) {
                    if (cfg.baseUrl.charAt(cfg.baseUrl.length - 1) !== "/") {
                        cfg.baseUrl += "/";
                    }
                }

                //Save off the paths and packages since they require special processing,
                //they are additive.
                paths = config.paths;
                packages = config.packages;
                pkgs = config.pkgs;

                //Mix in the config values, favoring the new values over
                //existing ones in context.config.
                mixin(config, cfg, true);

                //Adjust paths if necessary.
                if (cfg.paths) {
                    for (prop in cfg.paths) {
                        if (!(prop in empty)) {
                            paths[prop] = cfg.paths[prop];
                        }
                    }
                    config.paths = paths;
                }

                packagePaths = cfg.packagePaths;
                if (packagePaths || cfg.packages) {
                    //Convert packagePaths into a packages config.
                    if (packagePaths) {
                        for (prop in packagePaths) {
                            if (!(prop in empty)) {
                                configurePackageDir(pkgs, packagePaths[prop], prop);
                            }
                        }
                    }

                    //Adjust packages if necessary.
                    if (cfg.packages) {
                        configurePackageDir(pkgs, cfg.packages);
                    }

                    //Done with modifications, assing packages back to context config
                    config.pkgs = pkgs;
                }

                //If priority loading is in effect, trigger the loads now
                if (cfg.priority) {
                    //Hold on to requireWait value, and reset it after done
                    requireWait = context.requireWait;

                    //Allow tracing some require calls to allow the fetching
                    //of the priority config.
                    context.requireWait = false;
                    //But first, call resume to register any defined modules that may
                    //be in a data-main built file before the priority config
                    //call.
                    resume();

                    context.require(cfg.priority);

                    //Trigger a resume right away, for the case when
                    //the script with the priority load is done as part
                    //of a data-main call. In that case the normal resume
                    //call will not happen because the scriptCount will be
                    //at 1, since the script for data-main is being processed.
                    resume();

                    //Restore previous state.
                    context.requireWait = requireWait;
                    config.priorityWait = cfg.priority;
                }

                //If a deps array or a config callback is specified, then call
                //require with those args. This is useful when require is defined as a
                //config object before require.js is loaded.
                if (cfg.deps || cfg.callback) {
                    context.require(cfg.deps || [], cfg.callback);
                }
            },

            requireDefined: function (moduleName, relModuleMap) {
                return makeModuleMap(moduleName, relModuleMap).fullName in defined;
            },

            requireSpecified: function (moduleName, relModuleMap) {
                return makeModuleMap(moduleName, relModuleMap).fullName in specified;
            },

            require: function (deps, callback, relModuleMap) {
                var moduleName, fullName, moduleMap;
                if (typeof deps === "string") {
                    if (isFunction(callback)) {
                        //Invalid call
                        return req.onError(makeError("requireargs", "Invalid require call"));
                    }

                    //Synchronous access to one module. If require.get is
                    //available (as in the Node adapter), prefer that.
                    //In this case deps is the moduleName and callback is
                    //the relModuleMap
                    if (req.get) {
                        return req.get(context, deps, callback);
                    }

                    //Just return the module wanted. In this scenario, the
                    //second arg (if passed) is just the relModuleMap.
                    moduleName = deps;
                    relModuleMap = callback;

                    //Normalize module name, if it contains . or ..
                    moduleMap = makeModuleMap(moduleName, relModuleMap);
                    fullName = moduleMap.fullName;

                    if (!(fullName in defined)) {
                        return req.onError(makeError("notloaded", "Module name '" +
                                    moduleMap.fullName +
                                    "' has not been loaded yet for context: " +
                                    contextName));
                    }
                    return defined[fullName];
                }

                //Call main but only if there are dependencies or
                //a callback to call.
                if (deps && deps.length || callback) {
                    main(null, deps, callback, relModuleMap);
                }

                //If the require call does not trigger anything new to load,
                //then resume the dependency processing.
                if (!context.requireWait) {
                    while (!context.scriptCount && context.paused.length) {
                        resume();
                    }
                }
                return context.require;
            },

            /**
             * Internal method to transfer globalQueue items to this context's
             * defQueue.
             */
            takeGlobalQueue: function () {
                //Push all the globalDefQueue items into the context's defQueue
                if (globalDefQueue.length) {
                    //Array splice in the values since the context code has a
                    //local var ref to defQueue, so cannot just reassign the one
                    //on context.
                    apsp.apply(context.defQueue,
                               [context.defQueue.length - 1, 0].concat(globalDefQueue));
                    globalDefQueue = [];
                }
            },

            /**
             * Internal method used by environment adapters to complete a load event.
             * A load event could be a script load or just a load pass from a synchronous
             * load call.
             * @param {String} moduleName the name of the module to potentially complete.
             */
            completeLoad: function (moduleName) {
                var args;

                context.takeGlobalQueue();

                while (defQueue.length) {
                    args = defQueue.shift();

                    if (args[0] === null) {
                        args[0] = moduleName;
                        break;
                    } else if (args[0] === moduleName) {
                        //Found matching define call for this script!
                        break;
                    } else {
                        //Some other named define call, most likely the result
                        //of a build layer that included many define calls.
                        callDefMain(args);
                        args = null;
                    }
                }
                if (args) {
                    callDefMain(args);
                } else {
                    //A script that does not call define(), so just simulate
                    //the call for it. Special exception for jQuery dynamic load.
                    callDefMain([moduleName, [],
                                moduleName === "jquery" && typeof jQuery !== "undefined" ?
                                function () {
                                    return jQuery;
                                } : null]);
                }

                //Doing this scriptCount decrement branching because sync envs
                //need to decrement after resume, otherwise it looks like
                //loading is complete after the first dependency is fetched.
                //For browsers, it works fine to decrement after, but it means
                //the checkLoaded setTimeout 50 ms cost is taken. To avoid
                //that cost, decrement beforehand.
                if (req.isAsync) {
                    context.scriptCount -= 1;
                }
                resume();
                if (!req.isAsync) {
                    context.scriptCount -= 1;
                }
            },

            /**
             * Converts a module name + .extension into an URL path.
             * *Requires* the use of a module name. It does not support using
             * plain URLs like nameToUrl.
             */
            toUrl: function (moduleNamePlusExt, relModuleMap) {
                var index = moduleNamePlusExt.lastIndexOf("."),
                    ext = null;

                if (index !== -1) {
                    ext = moduleNamePlusExt.substring(index, moduleNamePlusExt.length);
                    moduleNamePlusExt = moduleNamePlusExt.substring(0, index);
                }

                return context.nameToUrl(moduleNamePlusExt, ext, relModuleMap);
            },

            /**
             * Converts a module name to a file path. Supports cases where
             * moduleName may actually be just an URL.
             */
            nameToUrl: function (moduleName, ext, relModuleMap) {
                var paths, pkgs, pkg, pkgPath, syms, i, parentModule, url,
                    config = context.config;

                //Normalize module name if have a base relative module name to work from.
                moduleName = normalize(moduleName, relModuleMap && relModuleMap.fullName);

                //If a colon is in the URL, it indicates a protocol is used and it is just
                //an URL to a file, or if it starts with a slash or ends with .js, it is just a plain file.
                //The slash is important for protocol-less URLs as well as full paths.
                if (req.jsExtRegExp.test(moduleName)) {
                    //Just a plain path, not module name lookup, so just return it.
                    //Add extension if it is included. This is a bit wonky, only non-.js things pass
                    //an extension, this method probably needs to be reworked.
                    url = moduleName + (ext ? ext : "");
                } else {
                    //A module that needs to be converted to a path.
                    paths = config.paths;
                    pkgs = config.pkgs;

                    syms = moduleName.split("/");
                    //For each module name segment, see if there is a path
                    //registered for it. Start with most specific name
                    //and work up from it.
                    for (i = syms.length; i > 0; i--) {
                        parentModule = syms.slice(0, i).join("/");
                        if (paths[parentModule]) {
                            syms.splice(0, i, paths[parentModule]);
                            break;
                        } else if ((pkg = pkgs[parentModule])) {
                            //If module name is just the package name, then looking
                            //for the main module.
                            if (moduleName === pkg.name) {
                                pkgPath = pkg.location + '/' + pkg.main;
                            } else {
                                pkgPath = pkg.location;
                            }
                            syms.splice(0, i, pkgPath);
                            break;
                        }
                    }

                    //Join the path parts together, then figure out if baseUrl is needed.
                    url = syms.join("/") + (ext || ".js");
                    url = (url.charAt(0) === '/' || url.match(/^\w+:/) ? "" : config.baseUrl) + url;
                }

                return config.urlArgs ? url +
                                        ((url.indexOf('?') === -1 ? '?' : '&') +
                                         config.urlArgs) : url;
            }
        };

        //Make these visible on the context so can be called at the very
        //end of the file to bootstrap
        context.jQueryCheck = jQueryCheck;
        context.resume = resume;

        return context;
    }

    /**
     * Main entry point.
     *
     * If the only argument to require is a string, then the module that
     * is represented by that string is fetched for the appropriate context.
     *
     * If the first argument is an array, then it will be treated as an array
     * of dependency string names to fetch. An optional function callback can
     * be specified to execute when all of those dependencies are available.
     *
     * Make a local req variable to help Caja compliance (it assumes things
     * on a require that are not standardized), and to give a short
     * name for minification/local scope use.
     */
    req = requirejs = function (deps, callback) {

        //Find the right context, use default
        var contextName = defContextName,
            context, config;

        // Determine if have config object in the call.
        if (!isArray(deps) && typeof deps !== "string") {
            // deps is a config object
            config = deps;
            if (isArray(callback)) {
                // Adjust args if there are dependencies
                deps = callback;
                callback = arguments[2];
            } else {
                deps = [];
            }
        }

        if (config && config.context) {
            contextName = config.context;
        }

        context = contexts[contextName] ||
                  (contexts[contextName] = newContext(contextName));

        if (config) {
            context.configure(config);
        }

        return context.require(deps, callback);
    };

    /**
     * Support require.config() to make it easier to cooperate with other
     * AMD loaders on globally agreed names.
     */
    req.config = function (config) {
        return req(config);
    };

    /**
     * Export require as a global, but only if it does not already exist.
     */
    if (!require) {
        require = req;
    }

    /**
     * Global require.toUrl(), to match global require, mostly useful
     * for debugging/work in the global space.
     */
    req.toUrl = function (moduleNamePlusExt) {
        return contexts[defContextName].toUrl(moduleNamePlusExt);
    };

    req.version = version;

    //Used to filter out dependencies that are already paths.
    req.jsExtRegExp = /^\/|:|\?|\.js$/;
    s = req.s = {
        contexts: contexts,
        //Stores a list of URLs that should not get async script tag treatment.
        skipAsync: {}
    };

    req.isAsync = req.isBrowser = isBrowser;
    if (isBrowser) {
        head = s.head = document.getElementsByTagName("head")[0];
        //If BASE tag is in play, using appendChild is a problem for IE6.
        //When that browser dies, this can be removed. Details in this jQuery bug:
        //http://dev.jquery.com/ticket/2709
        baseElement = document.getElementsByTagName("base")[0];
        if (baseElement) {
            head = s.head = baseElement.parentNode;
        }
    }

    /**
     * Any errors that require explicitly generates will be passed to this
     * function. Intercept/override it if you want custom error handling.
     * @param {Error} err the error object.
     */
    req.onError = function (err) {
        throw err;
    };

    /**
     * Does the request to load a module for the browser case.
     * Make this a separate function to allow other environments
     * to override it.
     *
     * @param {Object} context the require context to find state.
     * @param {String} moduleName the name of the module.
     * @param {Object} url the URL to the module.
     */
    req.load = function (context, moduleName, url) {
        req.resourcesReady(false);

        context.scriptCount += 1;
        req.attach(url, context, moduleName);

        //If tracking a jQuery, then make sure its ready callbacks
        //are put on hold to prevent its ready callbacks from
        //triggering too soon.
        if (context.jQuery && !context.jQueryIncremented) {
            jQueryHoldReady(context.jQuery, true);
            context.jQueryIncremented = true;
        }
    };

    function getInteractiveScript() {
        var scripts, i, script;
        if (interactiveScript && interactiveScript.readyState === 'interactive') {
            return interactiveScript;
        }

        scripts = document.getElementsByTagName('script');
        for (i = scripts.length - 1; i > -1 && (script = scripts[i]); i--) {
            if (script.readyState === 'interactive') {
                return (interactiveScript = script);
            }
        }

        return null;
    }

    /**
     * The function that handles definitions of modules. Differs from
     * require() in that a string for the module should be the first argument,
     * and the function to execute after dependencies are loaded should
     * return a value to define the module corresponding to the first argument's
     * name.
     */
    define = function (name, deps, callback) {
        var node, context;

        //Allow for anonymous functions
        if (typeof name !== 'string') {
            //Adjust args appropriately
            callback = deps;
            deps = name;
            name = null;
        }

        //This module may not have dependencies
        if (!isArray(deps)) {
            callback = deps;
            deps = [];
        }

        //If no name, and callback is a function, then figure out if it a
        //CommonJS thing with dependencies.
        if (!deps.length && isFunction(callback)) {
            //Remove comments from the callback string,
            //look for require calls, and pull them into the dependencies,
            //but only if there are function args.
            if (callback.length) {
                callback
                    .toString()
                    .replace(commentRegExp, "")
                    .replace(cjsRequireRegExp, function (match, dep) {
                        deps.push(dep);
                    });

                //May be a CommonJS thing even without require calls, but still
                //could use exports, and module. Avoid doing exports and module
                //work though if it just needs require.
                //REQUIRES the function to expect the CommonJS variables in the
                //order listed below.
                deps = (callback.length === 1 ? ["require"] : ["require", "exports", "module"]).concat(deps);
            }
        }

        //If in IE 6-8 and hit an anonymous define() call, do the interactive
        //work.
        if (useInteractive) {
            node = currentlyAddingScript || getInteractiveScript();
            if (node) {
                if (!name) {
                    name = node.getAttribute("data-requiremodule");
                }
                context = contexts[node.getAttribute("data-requirecontext")];
            }
        }

        //Always save off evaluating the def call until the script onload handler.
        //This allows multiple modules to be in a file without prematurely
        //tracing dependencies, and allows for anonymous module support,
        //where the module name is not known until the script onload event
        //occurs. If no context, use the global queue, and get it processed
        //in the onscript load callback.
        (context ? context.defQueue : globalDefQueue).push([name, deps, callback]);

        return undefined;
    };

    define.amd = {
        multiversion: true,
        plugins: true,
        jQuery: true
    };

    /**
     * Executes the text. Normally just uses eval, but can be modified
     * to use a more environment specific call.
     * @param {String} text the text to execute/evaluate.
     */
    req.exec = function (text) {
        return eval(text);
    };

    /**
     * Executes a module callack function. Broken out as a separate function
     * solely to allow the build system to sequence the files in the built
     * layer in the right sequence.
     *
     * @private
     */
    req.execCb = function (name, callback, args, exports) {
        return callback.apply(exports, args);
    };


    /**
     * Adds a node to the DOM. Public function since used by the order plugin.
     * This method should not normally be called by outside code.
     */
    req.addScriptToDom = function (node) {
        //For some cache cases in IE 6-8, the script executes before the end
        //of the appendChild execution, so to tie an anonymous define
        //call to the module name (which is stored on the node), hold on
        //to a reference to this node, but clear after the DOM insertion.
        currentlyAddingScript = node;
        if (baseElement) {
            head.insertBefore(node, baseElement);
        } else {
            head.appendChild(node);
        }
        currentlyAddingScript = null;
    };

    /**
     * callback for script loads, used to check status of loading.
     *
     * @param {Event} evt the event from the browser for the script
     * that was loaded.
     *
     * @private
     */
    req.onScriptLoad = function (evt) {
        //Using currentTarget instead of target for Firefox 2.0's sake. Not
        //all old browsers will be supported, but this one was easy enough
        //to support and still makes sense.
        var node = evt.currentTarget || evt.srcElement, contextName, moduleName,
            context;

        if (evt.type === "load" || (node && readyRegExp.test(node.readyState))) {
            //Reset interactive script so a script node is not held onto for
            //to long.
            interactiveScript = null;

            //Pull out the name of the module and the context.
            contextName = node.getAttribute("data-requirecontext");
            moduleName = node.getAttribute("data-requiremodule");
            context = contexts[contextName];

            contexts[contextName].completeLoad(moduleName);

            //Clean up script binding. Favor detachEvent because of IE9
            //issue, see attachEvent/addEventListener comment elsewhere
            //in this file.
            if (node.detachEvent && !isOpera) {
                //Probably IE. If not it will throw an error, which will be
                //useful to know.
                node.detachEvent("onreadystatechange", req.onScriptLoad);
            } else {
                node.removeEventListener("load", req.onScriptLoad, false);
            }
        }
    };

    /**
     * Attaches the script represented by the URL to the current
     * environment. Right now only supports browser loading,
     * but can be redefined in other environments to do the right thing.
     * @param {String} url the url of the script to attach.
     * @param {Object} context the context that wants the script.
     * @param {moduleName} the name of the module that is associated with the script.
     * @param {Function} [callback] optional callback, defaults to require.onScriptLoad
     * @param {String} [type] optional type, defaults to text/javascript
     * @param {Function} [fetchOnlyFunction] optional function to indicate the script node
     * should be set up to fetch the script but do not attach it to the DOM
     * so that it can later be attached to execute it. This is a way for the
     * order plugin to support ordered loading in IE. Once the script is fetched,
     * but not executed, the fetchOnlyFunction will be called.
     */
    req.attach = function (url, context, moduleName, callback, type, fetchOnlyFunction) {
        var node;
        if (isBrowser) {
            //In the browser so use a script tag
            callback = callback || req.onScriptLoad;
            node = context && context.config && context.config.xhtml ?
                    document.createElementNS("http://www.w3.org/1999/xhtml", "html:script") :
                    document.createElement("script");
            node.type = type || (context && context.config.scriptType) ||
                        "text/javascript";
            node.charset = "utf-8";
            //Use async so Gecko does not block on executing the script if something
            //like a long-polling comet tag is being run first. Gecko likes
            //to evaluate scripts in DOM order, even for dynamic scripts.
            //It will fetch them async, but only evaluate the contents in DOM
            //order, so a long-polling script tag can delay execution of scripts
            //after it. But telling Gecko we expect async gets us the behavior
            //we want -- execute it whenever it is finished downloading. Only
            //Helps Firefox 3.6+
            //Allow some URLs to not be fetched async. Mostly helps the order!
            //plugin
            node.async = !s.skipAsync[url];

            if (context) {
                node.setAttribute("data-requirecontext", context.contextName);
            }
            node.setAttribute("data-requiremodule", moduleName);

            //Set up load listener. Test attachEvent first because IE9 has
            //a subtle issue in its addEventListener and script onload firings
            //that do not match the behavior of all other browsers with
            //addEventListener support, which fire the onload event for a
            //script right after the script execution. See:
            //https://connect.microsoft.com/IE/feedback/details/648057/script-onload-event-is-not-fired-immediately-after-script-execution
            //UNFORTUNATELY Opera implements attachEvent but does not follow the script
            //script execution mode.
            if (node.attachEvent && !isOpera) {
                //Probably IE. IE (at least 6-8) do not fire
                //script onload right after executing the script, so
                //we cannot tie the anonymous define call to a name.
                //However, IE reports the script as being in "interactive"
                //readyState at the time of the define call.
                useInteractive = true;


                if (fetchOnlyFunction) {
                    //Need to use old school onreadystate here since
                    //when the event fires and the node is not attached
                    //to the DOM, the evt.srcElement is null, so use
                    //a closure to remember the node.
                    node.onreadystatechange = function (evt) {
                        //Script loaded but not executed.
                        //Clear loaded handler, set the real one that
                        //waits for script execution.
                        if (node.readyState === 'loaded') {
                            node.onreadystatechange = null;
                            node.attachEvent("onreadystatechange", callback);
                            fetchOnlyFunction(node);
                        }
                    };
                } else {
                    node.attachEvent("onreadystatechange", callback);
                }
            } else {
                node.addEventListener("load", callback, false);
            }
            node.src = url;

            //Fetch only means waiting to attach to DOM after loaded.
            if (!fetchOnlyFunction) {
                req.addScriptToDom(node);
            }

            return node;
        } else if (isWebWorker) {
            //In a web worker, use importScripts. This is not a very
            //efficient use of importScripts, importScripts will block until
            //its script is downloaded and evaluated. However, if web workers
            //are in play, the expectation that a build has been done so that
            //only one script needs to be loaded anyway. This may need to be
            //reevaluated if other use cases become common.
            importScripts(url);

            //Account for anonymous modules
            context.completeLoad(moduleName);
        }
        return null;
    };

    //Look for a data-main script attribute, which could also adjust the baseUrl.
    if (isBrowser) {
        //Figure out baseUrl. Get it from the script tag with require.js in it.
        scripts = document.getElementsByTagName("script");

        for (globalI = scripts.length - 1; globalI > -1 && (script = scripts[globalI]); globalI--) {
            //Set the "head" where we can append children by
            //using the script's parent.
            if (!head) {
                head = script.parentNode;
            }

            //Look for a data-main attribute to set main script for the page
            //to load. If it is there, the path to data main becomes the
            //baseUrl, if it is not already set.
            if ((dataMain = script.getAttribute('data-main'))) {
                if (!cfg.baseUrl) {
                    //Pull off the directory of data-main for use as the
                    //baseUrl.
                    src = dataMain.split('/');
                    mainScript = src.pop();
                    subPath = src.length ? src.join('/')  + '/' : './';

                    //Set final config.
                    cfg.baseUrl = subPath;
                    //Strip off any trailing .js since dataMain is now
                    //like a module name.
                    dataMain = mainScript.replace(jsSuffixRegExp, '');
                }

                //Put the data-main script in the files to load.
                cfg.deps = cfg.deps ? cfg.deps.concat(dataMain) : [dataMain];

                break;
            }
        }
    }

    //See if there is nothing waiting across contexts, and if not, trigger
    //resourcesReady.
    req.checkReadyState = function () {
        var contexts = s.contexts, prop;
        for (prop in contexts) {
            if (!(prop in empty)) {
                if (contexts[prop].waitCount) {
                    return;
                }
            }
        }
        req.resourcesReady(true);
    };

    /**
     * Internal function that is triggered whenever all scripts/resources
     * have been loaded by the loader. Can be overridden by other, for
     * instance the domReady plugin, which wants to know when all resources
     * are loaded.
     */
    req.resourcesReady = function (isReady) {
        var contexts, context, prop;

        //First, set the public variable indicating that resources are loading.
        req.resourcesDone = isReady;

        if (req.resourcesDone) {
            //If jQuery with DOM ready delayed, release it now.
            contexts = s.contexts;
            for (prop in contexts) {
                if (!(prop in empty)) {
                    context = contexts[prop];
                    if (context.jQueryIncremented) {
                        jQueryHoldReady(context.jQuery, false);
                        context.jQueryIncremented = false;
                    }
                }
            }
        }
    };

    //FF < 3.6 readyState fix. Needed so that domReady plugin
    //works well in that environment, since require.js is normally
    //loaded via an HTML script tag so it will be there before window load,
    //where the domReady plugin is more likely to be loaded after window load.
    req.pageLoaded = function () {
        if (document.readyState !== "complete") {
            document.readyState = "complete";
        }
    };
    if (isBrowser) {
        if (document.addEventListener) {
            if (!document.readyState) {
                document.readyState = "loading";
                window.addEventListener("load", req.pageLoaded, false);
            }
        }
    }

    //Set up default context. If require was a configuration object, use that as base config.
    req(cfg);

    //If modules are built into require.js, then need to make sure dependencies are
    //traced. Use a setTimeout in the browser world, to allow all the modules to register
    //themselves. In a non-browser env, assume that modules are not built into require.js,
    //which seems odd to do on the server.
    if (req.isAsync && typeof setTimeout !== "undefined") {
        ctx = s.contexts[(cfg.context || defContextName)];
        //Indicate that the script that includes require() is still loading,
        //so that require()'d dependencies are not traced until the end of the
        //file is parsed (approximated via the setTimeout call).
        ctx.requireWait = true;
        setTimeout(function () {
            ctx.requireWait = false;

            if (!ctx.scriptCount) {
                ctx.resume();
            }
            req.checkReadyState();
        }, 0);
    }
}());

define("requireLib", function(){});

/*!
 * mustache.js - Logic-less {{mustache}} templates with JavaScript
 * http://github.com/janl/mustache.js
 */
define('mustache',[],function(){

var Mustache = (typeof module !== "undefined" && module.exports) || {};

(function (exports) {

  exports.name = "mustache.js";
  exports.version = "0.5.0-dev";
  exports.tags = ["{{", "}}"];
  exports.parse = parse;
  exports.compile = compile;
  exports.render = render;
  exports.clearCache = clearCache;

  // This is here for backwards compatibility with 0.4.x.
  exports.to_html = function (template, view, partials, send) {
    var result = render(template, view, partials);

    if (typeof send === "function") {
      send(result);
    } else {
      return result;
    }
  };

  var _toString = Object.prototype.toString;
  var _isArray = Array.isArray;
  var _forEach = Array.prototype.forEach;
  var _trim = String.prototype.trim;

  var isArray;
  if (_isArray) {
    isArray = _isArray;
  } else {
    isArray = function (obj) {
      return _toString.call(obj) === "[object Array]";
    };
  }

  var forEach;
  if (_forEach) {
    forEach = function (obj, callback, scope) {
      return _forEach.call(obj, callback, scope);
    };
  } else {
    forEach = function (obj, callback, scope) {
      for (var i = 0, len = obj.length; i < len; ++i) {
        callback.call(scope, obj[i], i, obj);
      }
    };
  }

  var spaceRe = /^\s*$/;

  function isWhitespace(string) {
    return spaceRe.test(string);
  }

  var trim;
  if (_trim) {
    trim = function (string) {
      return string == null ? "" : _trim.call(string);
    };
  } else {
    var trimLeft, trimRight;

    if (isWhitespace("\xA0")) {
      trimLeft = /^\s+/;
      trimRight = /\s+$/;
    } else {
      // IE doesn't match non-breaking spaces with \s, thanks jQuery.
      trimLeft = /^[\s\xA0]+/;
      trimRight = /[\s\xA0]+$/;
    }

    trim = function (string) {
      return string == null ? "" :
        String(string).replace(trimLeft, "").replace(trimRight, "");
    };
  }

  var escapeMap = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': '&quot;',
    "'": '&#39;'
  };

  function escapeHTML(string) {
    return String(string).replace(/&(?!\w+;)|[<>"']/g, function (s) {
      return escapeMap[s] || s;
    });
  }

  /**
   * Adds the `template`, `line`, and `file` properties to the given error
   * object and alters the message to provide more useful debugging information.
   */
  function debug(e, template, line, file) {
    file = file || "<template>";

    var lines = template.split("\n"),
        start = Math.max(line - 3, 0),
        end = Math.min(lines.length, line + 3),
        context = lines.slice(start, end);

    var c;
    for (var i = 0, len = context.length; i < len; ++i) {
      c = i + start + 1;
      context[i] = (c === line ? " >> " : "    ") + context[i];
    }

    e.template = template;
    e.line = line;
    e.file = file;
    e.message = [file + ":" + line, context.join("\n"), "", e.message].join("\n");

    return e;
  }

  /**
   * Looks up the value of the given `name` in the given context `stack`.
   */
  function lookup(name, stack, defaultValue) {
    if (name === ".") {
      return stack[stack.length - 1];
    }

    var names = name.split(".");
    var lastIndex = names.length - 1;
    var target = names[lastIndex];

    var value, context, i = stack.length, j, localStack;
    while (i) {
      localStack = stack.slice(0);
      context = stack[--i];

      j = 0;
      while (j < lastIndex) {
        context = context[names[j++]];

        if (context == null) {
          break;
        }

        localStack.push(context);
      }

      if (context && typeof context === "object" && target in context) {
        value = context[target];
        break;
      }
    }

    // If the value is a function, call it in the current context.
    if (typeof value === "function") {
      value = value.call(localStack[localStack.length - 1]);
    }

    if (value == null)  {
      return defaultValue;
    }

    return value;
  }

  function renderSection(name, stack, callback, inverted) {
    var buffer = "";
    var value =  lookup(name, stack);

    if (inverted) {
      // From the spec: inverted sections may render text once based on the
      // inverse value of the key. That is, they will be rendered if the key
      // doesn't exist, is false, or is an empty list.
      if (value == null || value === false || (isArray(value) && value.length === 0)) {
        buffer += callback();
      }
    } else if (isArray(value)) {
      forEach(value, function (value) {
        stack.push(value);
        buffer += callback();
        stack.pop();
      });
    } else if (typeof value === "object") {
      stack.push(value);
      buffer += callback();
      stack.pop();
    } else if (typeof value === "function") {
      var scope = stack[stack.length - 1];
      var scopedRender = function (template) {
        return render(template, scope);
      };
      buffer += value.call(scope, callback(), scopedRender) || "";
    } else if (value) {
      buffer += callback();
    }

    return buffer;
  }

  /**
   * Parses the given `template` and returns the source of a function that,
   * with the proper arguments, will render the template. Recognized options
   * include the following:
   *
   *   - file     The name of the file the template comes from (displayed in
   *              error messages)
   *   - tags     An array of open and close tags the `template` uses. Defaults
   *              to the value of Mustache.tags
   *   - debug    Set `true` to log the body of the generated function to the
   *              console
   *   - space    Set `true` to preserve whitespace from lines that otherwise
   *              contain only a {{tag}}. Defaults to `false`
   */
  function parse(template, options) {
    options = options || {};

    var tags = options.tags || exports.tags,
        openTag = tags[0],
        closeTag = tags[tags.length - 1];

    var code = [
      'var buffer = "";', // output buffer
      "\nvar line = 1;", // keep track of source line number
      "\ntry {",
      '\nbuffer += "'
    ];

    var spaces = [],      // indices of whitespace in code on the current line
        hasTag = false,   // is there a {{tag}} on the current line?
        nonSpace = false; // is there a non-space char on the current line?

    // Strips all space characters from the code array for the current line
    // if there was a {{tag}} on it and otherwise only spaces.
    var stripSpace = function () {
      if (hasTag && !nonSpace && !options.space) {
        while (spaces.length) {
          code.splice(spaces.pop(), 1);
        }
      } else {
        spaces = [];
      }

      hasTag = false;
      nonSpace = false;
    };

    var sectionStack = [], updateLine, nextOpenTag, nextCloseTag;

    var setTags = function (source) {
      tags = trim(source).split(/\s+/);
      nextOpenTag = tags[0];
      nextCloseTag = tags[tags.length - 1];
    };

    var includePartial = function (source) {
      code.push(
        '";',
        updateLine,
        '\nvar partial = partials["' + trim(source) + '"];',
        '\nif (partial) {',
        '\n  buffer += render(partial,stack[stack.length - 1],partials);',
        '\n}',
        '\nbuffer += "'
      );
    };

    var openSection = function (source, inverted) {
      var name = trim(source);

      if (name === "") {
        throw debug(new Error("Section name may not be empty"), template, line, options.file);
      }

      sectionStack.push({name: name, inverted: inverted});

      code.push(
        '";',
        updateLine,
        '\nvar name = "' + name + '";',
        '\nvar callback = (function () {',
        '\n  return function () {',
        '\n    var buffer = "";',
        '\nbuffer += "'
      );
    };

    var openInvertedSection = function (source) {
      openSection(source, true);
    };

    var closeSection = function (source) {
      var name = trim(source);
      var openName = sectionStack.length != 0 && sectionStack[sectionStack.length - 1].name;

      if (!openName || name != openName) {
        throw debug(new Error('Section named "' + name + '" was never opened'), template, line, options.file);
      }

      var section = sectionStack.pop();

      code.push(
        '";',
        '\n    return buffer;',
        '\n  };',
        '\n})();'
      );

      if (section.inverted) {
        code.push("\nbuffer += renderSection(name,stack,callback,true);");
      } else {
        code.push("\nbuffer += renderSection(name,stack,callback);");
      }

      code.push('\nbuffer += "');
    };

    var sendPlain = function (source) {
      code.push(
        '";',
        updateLine,
        '\nbuffer += lookup("' + trim(source) + '",stack,"");',
        '\nbuffer += "'
      );
    };

    var sendEscaped = function (source) {
      code.push(
        '";',
        updateLine,
        '\nbuffer += escapeHTML(lookup("' + trim(source) + '",stack,""));',
        '\nbuffer += "'
      );
    };

    var line = 1, c, callback;
    for (var i = 0, len = template.length; i < len; ++i) {
      if (template.slice(i, i + openTag.length) === openTag) {
        i += openTag.length;
        c = template.substr(i, 1);
        updateLine = '\nline = ' + line + ';';
        nextOpenTag = openTag;
        nextCloseTag = closeTag;
        hasTag = true;

        switch (c) {
        case "!": // comment
          i++;
          callback = null;
          break;
        case "=": // change open/close tags, e.g. {{=<% %>=}}
          i++;
          closeTag = "=" + closeTag;
          callback = setTags;
          break;
        case ">": // include partial
          i++;
          callback = includePartial;
          break;
        case "#": // start section
          i++;
          callback = openSection;
          break;
        case "^": // start inverted section
          i++;
          callback = openInvertedSection;
          break;
        case "/": // end section
          i++;
          callback = closeSection;
          break;
        case "{": // plain variable
          closeTag = "}" + closeTag;
          // fall through
        case "&": // plain variable
          i++;
          nonSpace = true;
          callback = sendPlain;
          break;
        default: // escaped variable
          nonSpace = true;
          callback = sendEscaped;
        }

        var end = template.indexOf(closeTag, i);

        if (end === -1) {
          throw debug(new Error('Tag "' + openTag + '" was not closed properly'), template, line, options.file);
        }

        var source = template.substring(i, end);

        if (callback) {
          callback(source);
        }

        // Maintain line count for \n in source.
        var n = 0;
        while (~(n = source.indexOf("\n", n))) {
          line++;
          n++;
        }

        i = end + closeTag.length - 1;
        openTag = nextOpenTag;
        closeTag = nextCloseTag;
      } else {
        c = template.substr(i, 1);

        switch (c) {
        case '"':
        case "\\":
          nonSpace = true;
          code.push("\\" + c);
          break;
        case "\r":
          // Ignore carriage returns.
          break;
        case "\n":
          spaces.push(code.length);
          code.push("\\n");
          stripSpace(); // Check for whitespace on the current line.
          line++;
          break;
        default:
          if (isWhitespace(c)) {
            spaces.push(code.length);
          } else {
            nonSpace = true;
          }

          code.push(c);
        }
      }
    }

    if (sectionStack.length != 0) {
      throw debug(new Error('Section "' + sectionStack[sectionStack.length - 1].name + '" was not closed properly'), template, line, options.file);
    }

    // Clean up any whitespace from a closing {{tag}} that was at the end
    // of the template without a trailing \n.
    stripSpace();

    code.push(
      '";',
      "\nreturn buffer;",
      "\n} catch (e) { throw {error: e, line: line}; }"
    );

    // Ignore `buffer += "";` statements.
    var body = code.join("").replace(/buffer \+= "";\n/g, "");

    if (options.debug) {
      if (typeof console != "undefined" && console.log) {
        console.log(body);
      } else if (typeof print === "function") {
        print(body);
      }
    }

    return body;
  }

  /**
   * Used by `compile` to generate a reusable function for the given `template`.
   */
  function _compile(template, options) {
    var args = "view,partials,stack,lookup,escapeHTML,renderSection,render";
    var body = parse(template, options);
    var fn = new Function(args, body);

    // This anonymous function wraps the generated function so we can do
    // argument coercion, setup some variables, and handle any errors
    // encountered while executing it.
    return function (view, partials) {
      partials = partials || {};

      var stack = [view]; // context stack

      try {
        return fn(view, partials, stack, lookup, escapeHTML, renderSection, render);
      } catch (e) {
        throw debug(e.error, template, e.line, options.file);
      }
    };
  }

  // Cache of pre-compiled templates.
  var _cache = {};

  /**
   * Clear the cache of compiled templates.
   */
  function clearCache() {
    _cache = {};
  }

  /**
   * Compiles the given `template` into a reusable function using the given
   * `options`. In addition to the options accepted by Mustache.parse,
   * recognized options include the following:
   *
   *   - cache    Set `false` to bypass any pre-compiled version of the given
   *              template. Otherwise, a given `template` string will be cached
   *              the first time it is parsed
   */
  function compile(template, options) {
    options = options || {};

    // Use a pre-compiled version from the cache if we have one.
    if (options.cache !== false) {
      if (!_cache[template]) {
        _cache[template] = _compile(template, options);
      }

      return _cache[template];
    }

    return _compile(template, options);
  }

  /**
   * High-level function that renders the given `template` using the given
   * `view` and `partials`. If you need to use any of the template options (see
   * `compile` above), you must compile in a separate step, and then call that
   * compiled function.
   */
  function render(template, view, partials) {
    return compile(template)(view, partials);
  }

})(Mustache);

return Mustache;
});

/*! jQuery v1.7.2 jquery.com | jquery.org/license */
(function(a,b){function cy(a){return f.isWindow(a)?a:a.nodeType===9?a.defaultView||a.parentWindow:!1}function cu(a){if(!cj[a]){var b=c.body,d=f("<"+a+">").appendTo(b),e=d.css("display");d.remove();if(e==="none"||e===""){ck||(ck=c.createElement("iframe"),ck.frameBorder=ck.width=ck.height=0),b.appendChild(ck);if(!cl||!ck.createElement)cl=(ck.contentWindow||ck.contentDocument).document,cl.write((f.support.boxModel?"<!doctype html>":"")+"<html><body>"),cl.close();d=cl.createElement(a),cl.body.appendChild(d),e=f.css(d,"display"),b.removeChild(ck)}cj[a]=e}return cj[a]}function ct(a,b){var c={};f.each(cp.concat.apply([],cp.slice(0,b)),function(){c[this]=a});return c}function cs(){cq=b}function cr(){setTimeout(cs,0);return cq=f.now()}function ci(){try{return new a.ActiveXObject("Microsoft.XMLHTTP")}catch(b){}}function ch(){try{return new a.XMLHttpRequest}catch(b){}}function cb(a,c){a.dataFilter&&(c=a.dataFilter(c,a.dataType));var d=a.dataTypes,e={},g,h,i=d.length,j,k=d[0],l,m,n,o,p;for(g=1;g<i;g++){if(g===1)for(h in a.converters)typeof h=="string"&&(e[h.toLowerCase()]=a.converters[h]);l=k,k=d[g];if(k==="*")k=l;else if(l!=="*"&&l!==k){m=l+" "+k,n=e[m]||e["* "+k];if(!n){p=b;for(o in e){j=o.split(" ");if(j[0]===l||j[0]==="*"){p=e[j[1]+" "+k];if(p){o=e[o],o===!0?n=p:p===!0&&(n=o);break}}}}!n&&!p&&f.error("No conversion from "+m.replace(" "," to ")),n!==!0&&(c=n?n(c):p(o(c)))}}return c}function ca(a,c,d){var e=a.contents,f=a.dataTypes,g=a.responseFields,h,i,j,k;for(i in g)i in d&&(c[g[i]]=d[i]);while(f[0]==="*")f.shift(),h===b&&(h=a.mimeType||c.getResponseHeader("content-type"));if(h)for(i in e)if(e[i]&&e[i].test(h)){f.unshift(i);break}if(f[0]in d)j=f[0];else{for(i in d){if(!f[0]||a.converters[i+" "+f[0]]){j=i;break}k||(k=i)}j=j||k}if(j){j!==f[0]&&f.unshift(j);return d[j]}}function b_(a,b,c,d){if(f.isArray(b))f.each(b,function(b,e){c||bD.test(a)?d(a,e):b_(a+"["+(typeof e=="object"?b:"")+"]",e,c,d)});else if(!c&&f.type(b)==="object")for(var e in b)b_(a+"["+e+"]",b[e],c,d);else d(a,b)}function b$(a,c){var d,e,g=f.ajaxSettings.flatOptions||{};for(d in c)c[d]!==b&&((g[d]?a:e||(e={}))[d]=c[d]);e&&f.extend(!0,a,e)}function bZ(a,c,d,e,f,g){f=f||c.dataTypes[0],g=g||{},g[f]=!0;var h=a[f],i=0,j=h?h.length:0,k=a===bS,l;for(;i<j&&(k||!l);i++)l=h[i](c,d,e),typeof l=="string"&&(!k||g[l]?l=b:(c.dataTypes.unshift(l),l=bZ(a,c,d,e,l,g)));(k||!l)&&!g["*"]&&(l=bZ(a,c,d,e,"*",g));return l}function bY(a){return function(b,c){typeof b!="string"&&(c=b,b="*");if(f.isFunction(c)){var d=b.toLowerCase().split(bO),e=0,g=d.length,h,i,j;for(;e<g;e++)h=d[e],j=/^\+/.test(h),j&&(h=h.substr(1)||"*"),i=a[h]=a[h]||[],i[j?"unshift":"push"](c)}}}function bB(a,b,c){var d=b==="width"?a.offsetWidth:a.offsetHeight,e=b==="width"?1:0,g=4;if(d>0){if(c!=="border")for(;e<g;e+=2)c||(d-=parseFloat(f.css(a,"padding"+bx[e]))||0),c==="margin"?d+=parseFloat(f.css(a,c+bx[e]))||0:d-=parseFloat(f.css(a,"border"+bx[e]+"Width"))||0;return d+"px"}d=by(a,b);if(d<0||d==null)d=a.style[b];if(bt.test(d))return d;d=parseFloat(d)||0;if(c)for(;e<g;e+=2)d+=parseFloat(f.css(a,"padding"+bx[e]))||0,c!=="padding"&&(d+=parseFloat(f.css(a,"border"+bx[e]+"Width"))||0),c==="margin"&&(d+=parseFloat(f.css(a,c+bx[e]))||0);return d+"px"}function bo(a){var b=c.createElement("div");bh.appendChild(b),b.innerHTML=a.outerHTML;return b.firstChild}function bn(a){var b=(a.nodeName||"").toLowerCase();b==="input"?bm(a):b!=="script"&&typeof a.getElementsByTagName!="undefined"&&f.grep(a.getElementsByTagName("input"),bm)}function bm(a){if(a.type==="checkbox"||a.type==="radio")a.defaultChecked=a.checked}function bl(a){return typeof a.getElementsByTagName!="undefined"?a.getElementsByTagName("*"):typeof a.querySelectorAll!="undefined"?a.querySelectorAll("*"):[]}function bk(a,b){var c;b.nodeType===1&&(b.clearAttributes&&b.clearAttributes(),b.mergeAttributes&&b.mergeAttributes(a),c=b.nodeName.toLowerCase(),c==="object"?b.outerHTML=a.outerHTML:c!=="input"||a.type!=="checkbox"&&a.type!=="radio"?c==="option"?b.selected=a.defaultSelected:c==="input"||c==="textarea"?b.defaultValue=a.defaultValue:c==="script"&&b.text!==a.text&&(b.text=a.text):(a.checked&&(b.defaultChecked=b.checked=a.checked),b.value!==a.value&&(b.value=a.value)),b.removeAttribute(f.expando),b.removeAttribute("_submit_attached"),b.removeAttribute("_change_attached"))}function bj(a,b){if(b.nodeType===1&&!!f.hasData(a)){var c,d,e,g=f._data(a),h=f._data(b,g),i=g.events;if(i){delete h.handle,h.events={};for(c in i)for(d=0,e=i[c].length;d<e;d++)f.event.add(b,c,i[c][d])}h.data&&(h.data=f.extend({},h.data))}}function bi(a,b){return f.nodeName(a,"table")?a.getElementsByTagName("tbody")[0]||a.appendChild(a.ownerDocument.createElement("tbody")):a}function U(a){var b=V.split("|"),c=a.createDocumentFragment();if(c.createElement)while(b.length)c.createElement(b.pop());return c}function T(a,b,c){b=b||0;if(f.isFunction(b))return f.grep(a,function(a,d){var e=!!b.call(a,d,a);return e===c});if(b.nodeType)return f.grep(a,function(a,d){return a===b===c});if(typeof b=="string"){var d=f.grep(a,function(a){return a.nodeType===1});if(O.test(b))return f.filter(b,d,!c);b=f.filter(b,d)}return f.grep(a,function(a,d){return f.inArray(a,b)>=0===c})}function S(a){return!a||!a.parentNode||a.parentNode.nodeType===11}function K(){return!0}function J(){return!1}function n(a,b,c){var d=b+"defer",e=b+"queue",g=b+"mark",h=f._data(a,d);h&&(c==="queue"||!f._data(a,e))&&(c==="mark"||!f._data(a,g))&&setTimeout(function(){!f._data(a,e)&&!f._data(a,g)&&(f.removeData(a,d,!0),h.fire())},0)}function m(a){for(var b in a){if(b==="data"&&f.isEmptyObject(a[b]))continue;if(b!=="toJSON")return!1}return!0}function l(a,c,d){if(d===b&&a.nodeType===1){var e="data-"+c.replace(k,"-$1").toLowerCase();d=a.getAttribute(e);if(typeof d=="string"){try{d=d==="true"?!0:d==="false"?!1:d==="null"?null:f.isNumeric(d)?+d:j.test(d)?f.parseJSON(d):d}catch(g){}f.data(a,c,d)}else d=b}return d}function h(a){var b=g[a]={},c,d;a=a.split(/\s+/);for(c=0,d=a.length;c<d;c++)b[a[c]]=!0;return b}var c=a.document,d=a.navigator,e=a.location,f=function(){function J(){if(!e.isReady){try{c.documentElement.doScroll("left")}catch(a){setTimeout(J,1);return}e.ready()}}var e=function(a,b){return new e.fn.init(a,b,h)},f=a.jQuery,g=a.$,h,i=/^(?:[^#<]*(<[\w\W]+>)[^>]*$|#([\w\-]*)$)/,j=/\S/,k=/^\s+/,l=/\s+$/,m=/^<(\w+)\s*\/?>(?:<\/\1>)?$/,n=/^[\],:{}\s]*$/,o=/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g,p=/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,q=/(?:^|:|,)(?:\s*\[)+/g,r=/(webkit)[ \/]([\w.]+)/,s=/(opera)(?:.*version)?[ \/]([\w.]+)/,t=/(msie) ([\w.]+)/,u=/(mozilla)(?:.*? rv:([\w.]+))?/,v=/-([a-z]|[0-9])/ig,w=/^-ms-/,x=function(a,b){return(b+"").toUpperCase()},y=d.userAgent,z,A,B,C=Object.prototype.toString,D=Object.prototype.hasOwnProperty,E=Array.prototype.push,F=Array.prototype.slice,G=String.prototype.trim,H=Array.prototype.indexOf,I={};e.fn=e.prototype={constructor:e,init:function(a,d,f){var g,h,j,k;if(!a)return this;if(a.nodeType){this.context=this[0]=a,this.length=1;return this}if(a==="body"&&!d&&c.body){this.context=c,this[0]=c.body,this.selector=a,this.length=1;return this}if(typeof a=="string"){a.charAt(0)!=="<"||a.charAt(a.length-1)!==">"||a.length<3?g=i.exec(a):g=[null,a,null];if(g&&(g[1]||!d)){if(g[1]){d=d instanceof e?d[0]:d,k=d?d.ownerDocument||d:c,j=m.exec(a),j?e.isPlainObject(d)?(a=[c.createElement(j[1])],e.fn.attr.call(a,d,!0)):a=[k.createElement(j[1])]:(j=e.buildFragment([g[1]],[k]),a=(j.cacheable?e.clone(j.fragment):j.fragment).childNodes);return e.merge(this,a)}h=c.getElementById(g[2]);if(h&&h.parentNode){if(h.id!==g[2])return f.find(a);this.length=1,this[0]=h}this.context=c,this.selector=a;return this}return!d||d.jquery?(d||f).find(a):this.constructor(d).find(a)}if(e.isFunction(a))return f.ready(a);a.selector!==b&&(this.selector=a.selector,this.context=a.context);return e.makeArray(a,this)},selector:"",jquery:"1.7.2",length:0,size:function(){return this.length},toArray:function(){return F.call(this,0)},get:function(a){return a==null?this.toArray():a<0?this[this.length+a]:this[a]},pushStack:function(a,b,c){var d=this.constructor();e.isArray(a)?E.apply(d,a):e.merge(d,a),d.prevObject=this,d.context=this.context,b==="find"?d.selector=this.selector+(this.selector?" ":"")+c:b&&(d.selector=this.selector+"."+b+"("+c+")");return d},each:function(a,b){return e.each(this,a,b)},ready:function(a){e.bindReady(),A.add(a);return this},eq:function(a){a=+a;return a===-1?this.slice(a):this.slice(a,a+1)},first:function(){return this.eq(0)},last:function(){return this.eq(-1)},slice:function(){return this.pushStack(F.apply(this,arguments),"slice",F.call(arguments).join(","))},map:function(a){return this.pushStack(e.map(this,function(b,c){return a.call(b,c,b)}))},end:function(){return this.prevObject||this.constructor(null)},push:E,sort:[].sort,splice:[].splice},e.fn.init.prototype=e.fn,e.extend=e.fn.extend=function(){var a,c,d,f,g,h,i=arguments[0]||{},j=1,k=arguments.length,l=!1;typeof i=="boolean"&&(l=i,i=arguments[1]||{},j=2),typeof i!="object"&&!e.isFunction(i)&&(i={}),k===j&&(i=this,--j);for(;j<k;j++)if((a=arguments[j])!=null)for(c in a){d=i[c],f=a[c];if(i===f)continue;l&&f&&(e.isPlainObject(f)||(g=e.isArray(f)))?(g?(g=!1,h=d&&e.isArray(d)?d:[]):h=d&&e.isPlainObject(d)?d:{},i[c]=e.extend(l,h,f)):f!==b&&(i[c]=f)}return i},e.extend({noConflict:function(b){a.$===e&&(a.$=g),b&&a.jQuery===e&&(a.jQuery=f);return e},isReady:!1,readyWait:1,holdReady:function(a){a?e.readyWait++:e.ready(!0)},ready:function(a){if(a===!0&&!--e.readyWait||a!==!0&&!e.isReady){if(!c.body)return setTimeout(e.ready,1);e.isReady=!0;if(a!==!0&&--e.readyWait>0)return;A.fireWith(c,[e]),e.fn.trigger&&e(c).trigger("ready").off("ready")}},bindReady:function(){if(!A){A=e.Callbacks("once memory");if(c.readyState==="complete")return setTimeout(e.ready,1);if(c.addEventListener)c.addEventListener("DOMContentLoaded",B,!1),a.addEventListener("load",e.ready,!1);else if(c.attachEvent){c.attachEvent("onreadystatechange",B),a.attachEvent("onload",e.ready);var b=!1;try{b=a.frameElement==null}catch(d){}c.documentElement.doScroll&&b&&J()}}},isFunction:function(a){return e.type(a)==="function"},isArray:Array.isArray||function(a){return e.type(a)==="array"},isWindow:function(a){return a!=null&&a==a.window},isNumeric:function(a){return!isNaN(parseFloat(a))&&isFinite(a)},type:function(a){return a==null?String(a):I[C.call(a)]||"object"},isPlainObject:function(a){if(!a||e.type(a)!=="object"||a.nodeType||e.isWindow(a))return!1;try{if(a.constructor&&!D.call(a,"constructor")&&!D.call(a.constructor.prototype,"isPrototypeOf"))return!1}catch(c){return!1}var d;for(d in a);return d===b||D.call(a,d)},isEmptyObject:function(a){for(var b in a)return!1;return!0},error:function(a){throw new Error(a)},parseJSON:function(b){if(typeof b!="string"||!b)return null;b=e.trim(b);if(a.JSON&&a.JSON.parse)return a.JSON.parse(b);if(n.test(b.replace(o,"@").replace(p,"]").replace(q,"")))return(new Function("return "+b))();e.error("Invalid JSON: "+b)},parseXML:function(c){if(typeof c!="string"||!c)return null;var d,f;try{a.DOMParser?(f=new DOMParser,d=f.parseFromString(c,"text/xml")):(d=new ActiveXObject("Microsoft.XMLDOM"),d.async="false",d.loadXML(c))}catch(g){d=b}(!d||!d.documentElement||d.getElementsByTagName("parsererror").length)&&e.error("Invalid XML: "+c);return d},noop:function(){},globalEval:function(b){b&&j.test(b)&&(a.execScript||function(b){a.eval.call(a,b)})(b)},camelCase:function(a){return a.replace(w,"ms-").replace(v,x)},nodeName:function(a,b){return a.nodeName&&a.nodeName.toUpperCase()===b.toUpperCase()},each:function(a,c,d){var f,g=0,h=a.length,i=h===b||e.isFunction(a);if(d){if(i){for(f in a)if(c.apply(a[f],d)===!1)break}else for(;g<h;)if(c.apply(a[g++],d)===!1)break}else if(i){for(f in a)if(c.call(a[f],f,a[f])===!1)break}else for(;g<h;)if(c.call(a[g],g,a[g++])===!1)break;return a},trim:G?function(a){return a==null?"":G.call(a)}:function(a){return a==null?"":(a+"").replace(k,"").replace(l,"")},makeArray:function(a,b){var c=b||[];if(a!=null){var d=e.type(a);a.length==null||d==="string"||d==="function"||d==="regexp"||e.isWindow(a)?E.call(c,a):e.merge(c,a)}return c},inArray:function(a,b,c){var d;if(b){if(H)return H.call(b,a,c);d=b.length,c=c?c<0?Math.max(0,d+c):c:0;for(;c<d;c++)if(c in b&&b[c]===a)return c}return-1},merge:function(a,c){var d=a.length,e=0;if(typeof c.length=="number")for(var f=c.length;e<f;e++)a[d++]=c[e];else while(c[e]!==b)a[d++]=c[e++];a.length=d;return a},grep:function(a,b,c){var d=[],e;c=!!c;for(var f=0,g=a.length;f<g;f++)e=!!b(a[f],f),c!==e&&d.push(a[f]);return d},map:function(a,c,d){var f,g,h=[],i=0,j=a.length,k=a instanceof e||j!==b&&typeof j=="number"&&(j>0&&a[0]&&a[j-1]||j===0||e.isArray(a));if(k)for(;i<j;i++)f=c(a[i],i,d),f!=null&&(h[h.length]=f);else for(g in a)f=c(a[g],g,d),f!=null&&(h[h.length]=f);return h.concat.apply([],h)},guid:1,proxy:function(a,c){if(typeof c=="string"){var d=a[c];c=a,a=d}if(!e.isFunction(a))return b;var f=F.call(arguments,2),g=function(){return a.apply(c,f.concat(F.call(arguments)))};g.guid=a.guid=a.guid||g.guid||e.guid++;return g},access:function(a,c,d,f,g,h,i){var j,k=d==null,l=0,m=a.length;if(d&&typeof d=="object"){for(l in d)e.access(a,c,l,d[l],1,h,f);g=1}else if(f!==b){j=i===b&&e.isFunction(f),k&&(j?(j=c,c=function(a,b,c){return j.call(e(a),c)}):(c.call(a,f),c=null));if(c)for(;l<m;l++)c(a[l],d,j?f.call(a[l],l,c(a[l],d)):f,i);g=1}return g?a:k?c.call(a):m?c(a[0],d):h},now:function(){return(new Date).getTime()},uaMatch:function(a){a=a.toLowerCase();var b=r.exec(a)||s.exec(a)||t.exec(a)||a.indexOf("compatible")<0&&u.exec(a)||[];return{browser:b[1]||"",version:b[2]||"0"}},sub:function(){function a(b,c){return new a.fn.init(b,c)}e.extend(!0,a,this),a.superclass=this,a.fn=a.prototype=this(),a.fn.constructor=a,a.sub=this.sub,a.fn.init=function(d,f){f&&f instanceof e&&!(f instanceof a)&&(f=a(f));return e.fn.init.call(this,d,f,b)},a.fn.init.prototype=a.fn;var b=a(c);return a},browser:{}}),e.each("Boolean Number String Function Array Date RegExp Object".split(" "),function(a,b){I["[object "+b+"]"]=b.toLowerCase()}),z=e.uaMatch(y),z.browser&&(e.browser[z.browser]=!0,e.browser.version=z.version),e.browser.webkit&&(e.browser.safari=!0),j.test(" ")&&(k=/^[\s\xA0]+/,l=/[\s\xA0]+$/),h=e(c),c.addEventListener?B=function(){c.removeEventListener("DOMContentLoaded",B,!1),e.ready()}:c.attachEvent&&(B=function(){c.readyState==="complete"&&(c.detachEvent("onreadystatechange",B),e.ready())});return e}(),g={};f.Callbacks=function(a){a=a?g[a]||h(a):{};var c=[],d=[],e,i,j,k,l,m,n=function(b){var d,e,g,h,i;for(d=0,e=b.length;d<e;d++)g=b[d],h=f.type(g),h==="array"?n(g):h==="function"&&(!a.unique||!p.has(g))&&c.push(g)},o=function(b,f){f=f||[],e=!a.memory||[b,f],i=!0,j=!0,m=k||0,k=0,l=c.length;for(;c&&m<l;m++)if(c[m].apply(b,f)===!1&&a.stopOnFalse){e=!0;break}j=!1,c&&(a.once?e===!0?p.disable():c=[]:d&&d.length&&(e=d.shift(),p.fireWith(e[0],e[1])))},p={add:function(){if(c){var a=c.length;n(arguments),j?l=c.length:e&&e!==!0&&(k=a,o(e[0],e[1]))}return this},remove:function(){if(c){var b=arguments,d=0,e=b.length;for(;d<e;d++)for(var f=0;f<c.length;f++)if(b[d]===c[f]){j&&f<=l&&(l--,f<=m&&m--),c.splice(f--,1);if(a.unique)break}}return this},has:function(a){if(c){var b=0,d=c.length;for(;b<d;b++)if(a===c[b])return!0}return!1},empty:function(){c=[];return this},disable:function(){c=d=e=b;return this},disabled:function(){return!c},lock:function(){d=b,(!e||e===!0)&&p.disable();return this},locked:function(){return!d},fireWith:function(b,c){d&&(j?a.once||d.push([b,c]):(!a.once||!e)&&o(b,c));return this},fire:function(){p.fireWith(this,arguments);return this},fired:function(){return!!i}};return p};var i=[].slice;f.extend({Deferred:function(a){var b=f.Callbacks("once memory"),c=f.Callbacks("once memory"),d=f.Callbacks("memory"),e="pending",g={resolve:b,reject:c,notify:d},h={done:b.add,fail:c.add,progress:d.add,state:function(){return e},isResolved:b.fired,isRejected:c.fired,then:function(a,b,c){i.done(a).fail(b).progress(c);return this},always:function(){i.done.apply(i,arguments).fail.apply(i,arguments);return this},pipe:function(a,b,c){return f.Deferred(function(d){f.each({done:[a,"resolve"],fail:[b,"reject"],progress:[c,"notify"]},function(a,b){var c=b[0],e=b[1],g;f.isFunction(c)?i[a](function(){g=c.apply(this,arguments),g&&f.isFunction(g.promise)?g.promise().then(d.resolve,d.reject,d.notify):d[e+"With"](this===i?d:this,[g])}):i[a](d[e])})}).promise()},promise:function(a){if(a==null)a=h;else for(var b in h)a[b]=h[b];return a}},i=h.promise({}),j;for(j in g)i[j]=g[j].fire,i[j+"With"]=g[j].fireWith;i.done(function(){e="resolved"},c.disable,d.lock).fail(function(){e="rejected"},b.disable,d.lock),a&&a.call(i,i);return i},when:function(a){function m(a){return function(b){e[a]=arguments.length>1?i.call(arguments,0):b,j.notifyWith(k,e)}}function l(a){return function(c){b[a]=arguments.length>1?i.call(arguments,0):c,--g||j.resolveWith(j,b)}}var b=i.call(arguments,0),c=0,d=b.length,e=Array(d),g=d,h=d,j=d<=1&&a&&f.isFunction(a.promise)?a:f.Deferred(),k=j.promise();if(d>1){for(;c<d;c++)b[c]&&b[c].promise&&f.isFunction(b[c].promise)?b[c].promise().then(l(c),j.reject,m(c)):--g;g||j.resolveWith(j,b)}else j!==a&&j.resolveWith(j,d?[a]:[]);return k}}),f.support=function(){var b,d,e,g,h,i,j,k,l,m,n,o,p=c.createElement("div"),q=c.documentElement;p.setAttribute("className","t"),p.innerHTML="   <link/><table></table><a href='/a' style='top:1px;float:left;opacity:.55;'>a</a><input type='checkbox'/>",d=p.getElementsByTagName("*"),e=p.getElementsByTagName("a")[0];if(!d||!d.length||!e)return{};g=c.createElement("select"),h=g.appendChild(c.createElement("option")),i=p.getElementsByTagName("input")[0],b={leadingWhitespace:p.firstChild.nodeType===3,tbody:!p.getElementsByTagName("tbody").length,htmlSerialize:!!p.getElementsByTagName("link").length,style:/top/.test(e.getAttribute("style")),hrefNormalized:e.getAttribute("href")==="/a",opacity:/^0.55/.test(e.style.opacity),cssFloat:!!e.style.cssFloat,checkOn:i.value==="on",optSelected:h.selected,getSetAttribute:p.className!=="t",enctype:!!c.createElement("form").enctype,html5Clone:c.createElement("nav").cloneNode(!0).outerHTML!=="<:nav></:nav>",submitBubbles:!0,changeBubbles:!0,focusinBubbles:!1,deleteExpando:!0,noCloneEvent:!0,inlineBlockNeedsLayout:!1,shrinkWrapBlocks:!1,reliableMarginRight:!0,pixelMargin:!0},f.boxModel=b.boxModel=c.compatMode==="CSS1Compat",i.checked=!0,b.noCloneChecked=i.cloneNode(!0).checked,g.disabled=!0,b.optDisabled=!h.disabled;try{delete p.test}catch(r){b.deleteExpando=!1}!p.addEventListener&&p.attachEvent&&p.fireEvent&&(p.attachEvent("onclick",function(){b.noCloneEvent=!1}),p.cloneNode(!0).fireEvent("onclick")),i=c.createElement("input"),i.value="t",i.setAttribute("type","radio"),b.radioValue=i.value==="t",i.setAttribute("checked","checked"),i.setAttribute("name","t"),p.appendChild(i),j=c.createDocumentFragment(),j.appendChild(p.lastChild),b.checkClone=j.cloneNode(!0).cloneNode(!0).lastChild.checked,b.appendChecked=i.checked,j.removeChild(i),j.appendChild(p);if(p.attachEvent)for(n in{submit:1,change:1,focusin:1})m="on"+n,o=m in p,o||(p.setAttribute(m,"return;"),o=typeof p[m]=="function"),b[n+"Bubbles"]=o;j.removeChild(p),j=g=h=p=i=null,f(function(){var d,e,g,h,i,j,l,m,n,q,r,s,t,u=c.getElementsByTagName("body")[0];!u||(m=1,t="padding:0;margin:0;border:",r="position:absolute;top:0;left:0;width:1px;height:1px;",s=t+"0;visibility:hidden;",n="style='"+r+t+"5px solid #000;",q="<div "+n+"display:block;'><div style='"+t+"0;display:block;overflow:hidden;'></div></div>"+"<table "+n+"' cellpadding='0' cellspacing='0'>"+"<tr><td></td></tr></table>",d=c.createElement("div"),d.style.cssText=s+"width:0;height:0;position:static;top:0;margin-top:"+m+"px",u.insertBefore(d,u.firstChild),p=c.createElement("div"),d.appendChild(p),p.innerHTML="<table><tr><td style='"+t+"0;display:none'></td><td>t</td></tr></table>",k=p.getElementsByTagName("td"),o=k[0].offsetHeight===0,k[0].style.display="",k[1].style.display="none",b.reliableHiddenOffsets=o&&k[0].offsetHeight===0,a.getComputedStyle&&(p.innerHTML="",l=c.createElement("div"),l.style.width="0",l.style.marginRight="0",p.style.width="2px",p.appendChild(l),b.reliableMarginRight=(parseInt((a.getComputedStyle(l,null)||{marginRight:0}).marginRight,10)||0)===0),typeof p.style.zoom!="undefined"&&(p.innerHTML="",p.style.width=p.style.padding="1px",p.style.border=0,p.style.overflow="hidden",p.style.display="inline",p.style.zoom=1,b.inlineBlockNeedsLayout=p.offsetWidth===3,p.style.display="block",p.style.overflow="visible",p.innerHTML="<div style='width:5px;'></div>",b.shrinkWrapBlocks=p.offsetWidth!==3),p.style.cssText=r+s,p.innerHTML=q,e=p.firstChild,g=e.firstChild,i=e.nextSibling.firstChild.firstChild,j={doesNotAddBorder:g.offsetTop!==5,doesAddBorderForTableAndCells:i.offsetTop===5},g.style.position="fixed",g.style.top="20px",j.fixedPosition=g.offsetTop===20||g.offsetTop===15,g.style.position=g.style.top="",e.style.overflow="hidden",e.style.position="relative",j.subtractsBorderForOverflowNotVisible=g.offsetTop===-5,j.doesNotIncludeMarginInBodyOffset=u.offsetTop!==m,a.getComputedStyle&&(p.style.marginTop="1%",b.pixelMargin=(a.getComputedStyle(p,null)||{marginTop:0}).marginTop!=="1%"),typeof d.style.zoom!="undefined"&&(d.style.zoom=1),u.removeChild(d),l=p=d=null,f.extend(b,j))});return b}();var j=/^(?:\{.*\}|\[.*\])$/,k=/([A-Z])/g;f.extend({cache:{},uuid:0,expando:"jQuery"+(f.fn.jquery+Math.random()).replace(/\D/g,""),noData:{embed:!0,object:"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000",applet:!0},hasData:function(a){a=a.nodeType?f.cache[a[f.expando]]:a[f.expando];return!!a&&!m(a)},data:function(a,c,d,e){if(!!f.acceptData(a)){var g,h,i,j=f.expando,k=typeof c=="string",l=a.nodeType,m=l?f.cache:a,n=l?a[j]:a[j]&&j,o=c==="events";if((!n||!m[n]||!o&&!e&&!m[n].data)&&k&&d===b)return;n||(l?a[j]=n=++f.uuid:n=j),m[n]||(m[n]={},l||(m[n].toJSON=f.noop));if(typeof c=="object"||typeof c=="function")e?m[n]=f.extend(m[n],c):m[n].data=f.extend(m[n].data,c);g=h=m[n],e||(h.data||(h.data={}),h=h.data),d!==b&&(h[f.camelCase(c)]=d);if(o&&!h[c])return g.events;k?(i=h[c],i==null&&(i=h[f.camelCase(c)])):i=h;return i}},removeData:function(a,b,c){if(!!f.acceptData(a)){var d,e,g,h=f.expando,i=a.nodeType,j=i?f.cache:a,k=i?a[h]:h;if(!j[k])return;if(b){d=c?j[k]:j[k].data;if(d){f.isArray(b)||(b in d?b=[b]:(b=f.camelCase(b),b in d?b=[b]:b=b.split(" ")));for(e=0,g=b.length;e<g;e++)delete d[b[e]];if(!(c?m:f.isEmptyObject)(d))return}}if(!c){delete j[k].data;if(!m(j[k]))return}f.support.deleteExpando||!j.setInterval?delete j[k]:j[k]=null,i&&(f.support.deleteExpando?delete a[h]:a.removeAttribute?a.removeAttribute(h):a[h]=null)}},_data:function(a,b,c){return f.data(a,b,c,!0)},acceptData:function(a){if(a.nodeName){var b=f.noData[a.nodeName.toLowerCase()];if(b)return b!==!0&&a.getAttribute("classid")===b}return!0}}),f.fn.extend({data:function(a,c){var d,e,g,h,i,j=this[0],k=0,m=null;if(a===b){if(this.length){m=f.data(j);if(j.nodeType===1&&!f._data(j,"parsedAttrs")){g=j.attributes;for(i=g.length;k<i;k++)h=g[k].name,h.indexOf("data-")===0&&(h=f.camelCase(h.substring(5)),l(j,h,m[h]));f._data(j,"parsedAttrs",!0)}}return m}if(typeof a=="object")return this.each(function(){f.data(this,a)});d=a.split(".",2),d[1]=d[1]?"."+d[1]:"",e=d[1]+"!";return f.access(this,function(c){if(c===b){m=this.triggerHandler("getData"+e,[d[0]]),m===b&&j&&(m=f.data(j,a),m=l(j,a,m));return m===b&&d[1]?this.data(d[0]):m}d[1]=c,this.each(function(){var b=f(this);b.triggerHandler("setData"+e,d),f.data(this,a,c),b.triggerHandler("changeData"+e,d)})},null,c,arguments.length>1,null,!1)},removeData:function(a){return this.each(function(){f.removeData(this,a)})}}),f.extend({_mark:function(a,b){a&&(b=(b||"fx")+"mark",f._data(a,b,(f._data(a,b)||0)+1))},_unmark:function(a,b,c){a!==!0&&(c=b,b=a,a=!1);if(b){c=c||"fx";var d=c+"mark",e=a?0:(f._data(b,d)||1)-1;e?f._data(b,d,e):(f.removeData(b,d,!0),n(b,c,"mark"))}},queue:function(a,b,c){var d;if(a){b=(b||"fx")+"queue",d=f._data(a,b),c&&(!d||f.isArray(c)?d=f._data(a,b,f.makeArray(c)):d.push(c));return d||[]}},dequeue:function(a,b){b=b||"fx";var c=f.queue(a,b),d=c.shift(),e={};d==="inprogress"&&(d=c.shift()),d&&(b==="fx"&&c.unshift("inprogress"),f._data(a,b+".run",e),d.call(a,function(){f.dequeue(a,b)},e)),c.length||(f.removeData(a,b+"queue "+b+".run",!0),n(a,b,"queue"))}}),f.fn.extend({queue:function(a,c){var d=2;typeof a!="string"&&(c=a,a="fx",d--);if(arguments.length<d)return f.queue(this[0],a);return c===b?this:this.each(function(){var b=f.queue(this,a,c);a==="fx"&&b[0]!=="inprogress"&&f.dequeue(this,a)})},dequeue:function(a){return this.each(function(){f.dequeue(this,a)})},delay:function(a,b){a=f.fx?f.fx.speeds[a]||a:a,b=b||"fx";return this.queue(b,function(b,c){var d=setTimeout(b,a);c.stop=function(){clearTimeout(d)}})},clearQueue:function(a){return this.queue(a||"fx",[])},promise:function(a,c){function m(){--h||d.resolveWith(e,[e])}typeof a!="string"&&(c=a,a=b),a=a||"fx";var d=f.Deferred(),e=this,g=e.length,h=1,i=a+"defer",j=a+"queue",k=a+"mark",l;while(g--)if(l=f.data(e[g],i,b,!0)||(f.data(e[g],j,b,!0)||f.data(e[g],k,b,!0))&&f.data(e[g],i,f.Callbacks("once memory"),!0))h++,l.add(m);m();return d.promise(c)}});var o=/[\n\t\r]/g,p=/\s+/,q=/\r/g,r=/^(?:button|input)$/i,s=/^(?:button|input|object|select|textarea)$/i,t=/^a(?:rea)?$/i,u=/^(?:autofocus|autoplay|async|checked|controls|defer|disabled|hidden|loop|multiple|open|readonly|required|scoped|selected)$/i,v=f.support.getSetAttribute,w,x,y;f.fn.extend({attr:function(a,b){return f.access(this,f.attr,a,b,arguments.length>1)},removeAttr:function(a){return this.each(function(){f.removeAttr(this,a)})},prop:function(a,b){return f.access(this,f.prop,a,b,arguments.length>1)},removeProp:function(a){a=f.propFix[a]||a;return this.each(function(){try{this[a]=b,delete this[a]}catch(c){}})},addClass:function(a){var b,c,d,e,g,h,i;if(f.isFunction(a))return this.each(function(b){f(this).addClass(a.call(this,b,this.className))});if(a&&typeof a=="string"){b=a.split(p);for(c=0,d=this.length;c<d;c++){e=this[c];if(e.nodeType===1)if(!e.className&&b.length===1)e.className=a;else{g=" "+e.className+" ";for(h=0,i=b.length;h<i;h++)~g.indexOf(" "+b[h]+" ")||(g+=b[h]+" ");e.className=f.trim(g)}}}return this},removeClass:function(a){var c,d,e,g,h,i,j;if(f.isFunction(a))return this.each(function(b){f(this).removeClass(a.call(this,b,this.className))});if(a&&typeof a=="string"||a===b){c=(a||"").split(p);for(d=0,e=this.length;d<e;d++){g=this[d];if(g.nodeType===1&&g.className)if(a){h=(" "+g.className+" ").replace(o," ");for(i=0,j=c.length;i<j;i++)h=h.replace(" "+c[i]+" "," ");g.className=f.trim(h)}else g.className=""}}return this},toggleClass:function(a,b){var c=typeof a,d=typeof b=="boolean";if(f.isFunction(a))return this.each(function(c){f(this).toggleClass(a.call(this,c,this.className,b),b)});return this.each(function(){if(c==="string"){var e,g=0,h=f(this),i=b,j=a.split(p);while(e=j[g++])i=d?i:!h.hasClass(e),h[i?"addClass":"removeClass"](e)}else if(c==="undefined"||c==="boolean")this.className&&f._data(this,"__className__",this.className),this.className=this.className||a===!1?"":f._data(this,"__className__")||""})},hasClass:function(a){var b=" "+a+" ",c=0,d=this.length;for(;c<d;c++)if(this[c].nodeType===1&&(" "+this[c].className+" ").replace(o," ").indexOf(b)>-1)return!0;return!1},val:function(a){var c,d,e,g=this[0];{if(!!arguments.length){e=f.isFunction(a);return this.each(function(d){var g=f(this),h;if(this.nodeType===1){e?h=a.call(this,d,g.val()):h=a,h==null?h="":typeof h=="number"?h+="":f.isArray(h)&&(h=f.map(h,function(a){return a==null?"":a+""})),c=f.valHooks[this.type]||f.valHooks[this.nodeName.toLowerCase()];if(!c||!("set"in c)||c.set(this,h,"value")===b)this.value=h}})}if(g){c=f.valHooks[g.type]||f.valHooks[g.nodeName.toLowerCase()];if(c&&"get"in c&&(d=c.get(g,"value"))!==b)return d;d=g.value;return typeof d=="string"?d.replace(q,""):d==null?"":d}}}}),f.extend({valHooks:{option:{get:function(a){var b=a.attributes.value;return!b||b.specified?a.value:a.text}},select:{get:function(a){var b,c,d,e,g=a.selectedIndex,h=[],i=a.options,j=a.type==="select-one";if(g<0)return null;c=j?g:0,d=j?g+1:i.length;for(;c<d;c++){e=i[c];if(e.selected&&(f.support.optDisabled?!e.disabled:e.getAttribute("disabled")===null)&&(!e.parentNode.disabled||!f.nodeName(e.parentNode,"optgroup"))){b=f(e).val();if(j)return b;h.push(b)}}if(j&&!h.length&&i.length)return f(i[g]).val();return h},set:function(a,b){var c=f.makeArray(b);f(a).find("option").each(function(){this.selected=f.inArray(f(this).val(),c)>=0}),c.length||(a.selectedIndex=-1);return c}}},attrFn:{val:!0,css:!0,html:!0,text:!0,data:!0,width:!0,height:!0,offset:!0},attr:function(a,c,d,e){var g,h,i,j=a.nodeType;if(!!a&&j!==3&&j!==8&&j!==2){if(e&&c in f.attrFn)return f(a)[c](d);if(typeof a.getAttribute=="undefined")return f.prop(a,c,d);i=j!==1||!f.isXMLDoc(a),i&&(c=c.toLowerCase(),h=f.attrHooks[c]||(u.test(c)?x:w));if(d!==b){if(d===null){f.removeAttr(a,c);return}if(h&&"set"in h&&i&&(g=h.set(a,d,c))!==b)return g;a.setAttribute(c,""+d);return d}if(h&&"get"in h&&i&&(g=h.get(a,c))!==null)return g;g=a.getAttribute(c);return g===null?b:g}},removeAttr:function(a,b){var c,d,e,g,h,i=0;if(b&&a.nodeType===1){d=b.toLowerCase().split(p),g=d.length;for(;i<g;i++)e=d[i],e&&(c=f.propFix[e]||e,h=u.test(e),h||f.attr(a,e,""),a.removeAttribute(v?e:c),h&&c in a&&(a[c]=!1))}},attrHooks:{type:{set:function(a,b){if(r.test(a.nodeName)&&a.parentNode)f.error("type property can't be changed");else if(!f.support.radioValue&&b==="radio"&&f.nodeName(a,"input")){var c=a.value;a.setAttribute("type",b),c&&(a.value=c);return b}}},value:{get:function(a,b){if(w&&f.nodeName(a,"button"))return w.get(a,b);return b in a?a.value:null},set:function(a,b,c){if(w&&f.nodeName(a,"button"))return w.set(a,b,c);a.value=b}}},propFix:{tabindex:"tabIndex",readonly:"readOnly","for":"htmlFor","class":"className",maxlength:"maxLength",cellspacing:"cellSpacing",cellpadding:"cellPadding",rowspan:"rowSpan",colspan:"colSpan",usemap:"useMap",frameborder:"frameBorder",contenteditable:"contentEditable"},prop:function(a,c,d){var e,g,h,i=a.nodeType;if(!!a&&i!==3&&i!==8&&i!==2){h=i!==1||!f.isXMLDoc(a),h&&(c=f.propFix[c]||c,g=f.propHooks[c]);return d!==b?g&&"set"in g&&(e=g.set(a,d,c))!==b?e:a[c]=d:g&&"get"in g&&(e=g.get(a,c))!==null?e:a[c]}},propHooks:{tabIndex:{get:function(a){var c=a.getAttributeNode("tabindex");return c&&c.specified?parseInt(c.value,10):s.test(a.nodeName)||t.test(a.nodeName)&&a.href?0:b}}}}),f.attrHooks.tabindex=f.propHooks.tabIndex,x={get:function(a,c){var d,e=f.prop(a,c);return e===!0||typeof e!="boolean"&&(d=a.getAttributeNode(c))&&d.nodeValue!==!1?c.toLowerCase():b},set:function(a,b,c){var d;b===!1?f.removeAttr(a,c):(d=f.propFix[c]||c,d in a&&(a[d]=!0),a.setAttribute(c,c.toLowerCase()));return c}},v||(y={name:!0,id:!0,coords:!0},w=f.valHooks.button={get:function(a,c){var d;d=a.getAttributeNode(c);return d&&(y[c]?d.nodeValue!=="":d.specified)?d.nodeValue:b},set:function(a,b,d){var e=a.getAttributeNode(d);e||(e=c.createAttribute(d),a.setAttributeNode(e));return e.nodeValue=b+""}},f.attrHooks.tabindex.set=w.set,f.each(["width","height"],function(a,b){f.attrHooks[b]=f.extend(f.attrHooks[b],{set:function(a,c){if(c===""){a.setAttribute(b,"auto");return c}}})}),f.attrHooks.contenteditable={get:w.get,set:function(a,b,c){b===""&&(b="false"),w.set(a,b,c)}}),f.support.hrefNormalized||f.each(["href","src","width","height"],function(a,c){f.attrHooks[c]=f.extend(f.attrHooks[c],{get:function(a){var d=a.getAttribute(c,2);return d===null?b:d}})}),f.support.style||(f.attrHooks.style={get:function(a){return a.style.cssText.toLowerCase()||b},set:function(a,b){return a.style.cssText=""+b}}),f.support.optSelected||(f.propHooks.selected=f.extend(f.propHooks.selected,{get:function(a){var b=a.parentNode;b&&(b.selectedIndex,b.parentNode&&b.parentNode.selectedIndex);return null}})),f.support.enctype||(f.propFix.enctype="encoding"),f.support.checkOn||f.each(["radio","checkbox"],function(){f.valHooks[this]={get:function(a){return a.getAttribute("value")===null?"on":a.value}}}),f.each(["radio","checkbox"],function(){f.valHooks[this]=f.extend(f.valHooks[this],{set:function(a,b){if(f.isArray(b))return a.checked=f.inArray(f(a).val(),b)>=0}})});var z=/^(?:textarea|input|select)$/i,A=/^([^\.]*)?(?:\.(.+))?$/,B=/(?:^|\s)hover(\.\S+)?\b/,C=/^key/,D=/^(?:mouse|contextmenu)|click/,E=/^(?:focusinfocus|focusoutblur)$/,F=/^(\w*)(?:#([\w\-]+))?(?:\.([\w\-]+))?$/,G=function(
a){var b=F.exec(a);b&&(b[1]=(b[1]||"").toLowerCase(),b[3]=b[3]&&new RegExp("(?:^|\\s)"+b[3]+"(?:\\s|$)"));return b},H=function(a,b){var c=a.attributes||{};return(!b[1]||a.nodeName.toLowerCase()===b[1])&&(!b[2]||(c.id||{}).value===b[2])&&(!b[3]||b[3].test((c["class"]||{}).value))},I=function(a){return f.event.special.hover?a:a.replace(B,"mouseenter$1 mouseleave$1")};f.event={add:function(a,c,d,e,g){var h,i,j,k,l,m,n,o,p,q,r,s;if(!(a.nodeType===3||a.nodeType===8||!c||!d||!(h=f._data(a)))){d.handler&&(p=d,d=p.handler,g=p.selector),d.guid||(d.guid=f.guid++),j=h.events,j||(h.events=j={}),i=h.handle,i||(h.handle=i=function(a){return typeof f!="undefined"&&(!a||f.event.triggered!==a.type)?f.event.dispatch.apply(i.elem,arguments):b},i.elem=a),c=f.trim(I(c)).split(" ");for(k=0;k<c.length;k++){l=A.exec(c[k])||[],m=l[1],n=(l[2]||"").split(".").sort(),s=f.event.special[m]||{},m=(g?s.delegateType:s.bindType)||m,s=f.event.special[m]||{},o=f.extend({type:m,origType:l[1],data:e,handler:d,guid:d.guid,selector:g,quick:g&&G(g),namespace:n.join(".")},p),r=j[m];if(!r){r=j[m]=[],r.delegateCount=0;if(!s.setup||s.setup.call(a,e,n,i)===!1)a.addEventListener?a.addEventListener(m,i,!1):a.attachEvent&&a.attachEvent("on"+m,i)}s.add&&(s.add.call(a,o),o.handler.guid||(o.handler.guid=d.guid)),g?r.splice(r.delegateCount++,0,o):r.push(o),f.event.global[m]=!0}a=null}},global:{},remove:function(a,b,c,d,e){var g=f.hasData(a)&&f._data(a),h,i,j,k,l,m,n,o,p,q,r,s;if(!!g&&!!(o=g.events)){b=f.trim(I(b||"")).split(" ");for(h=0;h<b.length;h++){i=A.exec(b[h])||[],j=k=i[1],l=i[2];if(!j){for(j in o)f.event.remove(a,j+b[h],c,d,!0);continue}p=f.event.special[j]||{},j=(d?p.delegateType:p.bindType)||j,r=o[j]||[],m=r.length,l=l?new RegExp("(^|\\.)"+l.split(".").sort().join("\\.(?:.*\\.)?")+"(\\.|$)"):null;for(n=0;n<r.length;n++)s=r[n],(e||k===s.origType)&&(!c||c.guid===s.guid)&&(!l||l.test(s.namespace))&&(!d||d===s.selector||d==="**"&&s.selector)&&(r.splice(n--,1),s.selector&&r.delegateCount--,p.remove&&p.remove.call(a,s));r.length===0&&m!==r.length&&((!p.teardown||p.teardown.call(a,l)===!1)&&f.removeEvent(a,j,g.handle),delete o[j])}f.isEmptyObject(o)&&(q=g.handle,q&&(q.elem=null),f.removeData(a,["events","handle"],!0))}},customEvent:{getData:!0,setData:!0,changeData:!0},trigger:function(c,d,e,g){if(!e||e.nodeType!==3&&e.nodeType!==8){var h=c.type||c,i=[],j,k,l,m,n,o,p,q,r,s;if(E.test(h+f.event.triggered))return;h.indexOf("!")>=0&&(h=h.slice(0,-1),k=!0),h.indexOf(".")>=0&&(i=h.split("."),h=i.shift(),i.sort());if((!e||f.event.customEvent[h])&&!f.event.global[h])return;c=typeof c=="object"?c[f.expando]?c:new f.Event(h,c):new f.Event(h),c.type=h,c.isTrigger=!0,c.exclusive=k,c.namespace=i.join("."),c.namespace_re=c.namespace?new RegExp("(^|\\.)"+i.join("\\.(?:.*\\.)?")+"(\\.|$)"):null,o=h.indexOf(":")<0?"on"+h:"";if(!e){j=f.cache;for(l in j)j[l].events&&j[l].events[h]&&f.event.trigger(c,d,j[l].handle.elem,!0);return}c.result=b,c.target||(c.target=e),d=d!=null?f.makeArray(d):[],d.unshift(c),p=f.event.special[h]||{};if(p.trigger&&p.trigger.apply(e,d)===!1)return;r=[[e,p.bindType||h]];if(!g&&!p.noBubble&&!f.isWindow(e)){s=p.delegateType||h,m=E.test(s+h)?e:e.parentNode,n=null;for(;m;m=m.parentNode)r.push([m,s]),n=m;n&&n===e.ownerDocument&&r.push([n.defaultView||n.parentWindow||a,s])}for(l=0;l<r.length&&!c.isPropagationStopped();l++)m=r[l][0],c.type=r[l][1],q=(f._data(m,"events")||{})[c.type]&&f._data(m,"handle"),q&&q.apply(m,d),q=o&&m[o],q&&f.acceptData(m)&&q.apply(m,d)===!1&&c.preventDefault();c.type=h,!g&&!c.isDefaultPrevented()&&(!p._default||p._default.apply(e.ownerDocument,d)===!1)&&(h!=="click"||!f.nodeName(e,"a"))&&f.acceptData(e)&&o&&e[h]&&(h!=="focus"&&h!=="blur"||c.target.offsetWidth!==0)&&!f.isWindow(e)&&(n=e[o],n&&(e[o]=null),f.event.triggered=h,e[h](),f.event.triggered=b,n&&(e[o]=n));return c.result}},dispatch:function(c){c=f.event.fix(c||a.event);var d=(f._data(this,"events")||{})[c.type]||[],e=d.delegateCount,g=[].slice.call(arguments,0),h=!c.exclusive&&!c.namespace,i=f.event.special[c.type]||{},j=[],k,l,m,n,o,p,q,r,s,t,u;g[0]=c,c.delegateTarget=this;if(!i.preDispatch||i.preDispatch.call(this,c)!==!1){if(e&&(!c.button||c.type!=="click")){n=f(this),n.context=this.ownerDocument||this;for(m=c.target;m!=this;m=m.parentNode||this)if(m.disabled!==!0){p={},r=[],n[0]=m;for(k=0;k<e;k++)s=d[k],t=s.selector,p[t]===b&&(p[t]=s.quick?H(m,s.quick):n.is(t)),p[t]&&r.push(s);r.length&&j.push({elem:m,matches:r})}}d.length>e&&j.push({elem:this,matches:d.slice(e)});for(k=0;k<j.length&&!c.isPropagationStopped();k++){q=j[k],c.currentTarget=q.elem;for(l=0;l<q.matches.length&&!c.isImmediatePropagationStopped();l++){s=q.matches[l];if(h||!c.namespace&&!s.namespace||c.namespace_re&&c.namespace_re.test(s.namespace))c.data=s.data,c.handleObj=s,o=((f.event.special[s.origType]||{}).handle||s.handler).apply(q.elem,g),o!==b&&(c.result=o,o===!1&&(c.preventDefault(),c.stopPropagation()))}}i.postDispatch&&i.postDispatch.call(this,c);return c.result}},props:"attrChange attrName relatedNode srcElement altKey bubbles cancelable ctrlKey currentTarget eventPhase metaKey relatedTarget shiftKey target timeStamp view which".split(" "),fixHooks:{},keyHooks:{props:"char charCode key keyCode".split(" "),filter:function(a,b){a.which==null&&(a.which=b.charCode!=null?b.charCode:b.keyCode);return a}},mouseHooks:{props:"button buttons clientX clientY fromElement offsetX offsetY pageX pageY screenX screenY toElement".split(" "),filter:function(a,d){var e,f,g,h=d.button,i=d.fromElement;a.pageX==null&&d.clientX!=null&&(e=a.target.ownerDocument||c,f=e.documentElement,g=e.body,a.pageX=d.clientX+(f&&f.scrollLeft||g&&g.scrollLeft||0)-(f&&f.clientLeft||g&&g.clientLeft||0),a.pageY=d.clientY+(f&&f.scrollTop||g&&g.scrollTop||0)-(f&&f.clientTop||g&&g.clientTop||0)),!a.relatedTarget&&i&&(a.relatedTarget=i===a.target?d.toElement:i),!a.which&&h!==b&&(a.which=h&1?1:h&2?3:h&4?2:0);return a}},fix:function(a){if(a[f.expando])return a;var d,e,g=a,h=f.event.fixHooks[a.type]||{},i=h.props?this.props.concat(h.props):this.props;a=f.Event(g);for(d=i.length;d;)e=i[--d],a[e]=g[e];a.target||(a.target=g.srcElement||c),a.target.nodeType===3&&(a.target=a.target.parentNode),a.metaKey===b&&(a.metaKey=a.ctrlKey);return h.filter?h.filter(a,g):a},special:{ready:{setup:f.bindReady},load:{noBubble:!0},focus:{delegateType:"focusin"},blur:{delegateType:"focusout"},beforeunload:{setup:function(a,b,c){f.isWindow(this)&&(this.onbeforeunload=c)},teardown:function(a,b){this.onbeforeunload===b&&(this.onbeforeunload=null)}}},simulate:function(a,b,c,d){var e=f.extend(new f.Event,c,{type:a,isSimulated:!0,originalEvent:{}});d?f.event.trigger(e,null,b):f.event.dispatch.call(b,e),e.isDefaultPrevented()&&c.preventDefault()}},f.event.handle=f.event.dispatch,f.removeEvent=c.removeEventListener?function(a,b,c){a.removeEventListener&&a.removeEventListener(b,c,!1)}:function(a,b,c){a.detachEvent&&a.detachEvent("on"+b,c)},f.Event=function(a,b){if(!(this instanceof f.Event))return new f.Event(a,b);a&&a.type?(this.originalEvent=a,this.type=a.type,this.isDefaultPrevented=a.defaultPrevented||a.returnValue===!1||a.getPreventDefault&&a.getPreventDefault()?K:J):this.type=a,b&&f.extend(this,b),this.timeStamp=a&&a.timeStamp||f.now(),this[f.expando]=!0},f.Event.prototype={preventDefault:function(){this.isDefaultPrevented=K;var a=this.originalEvent;!a||(a.preventDefault?a.preventDefault():a.returnValue=!1)},stopPropagation:function(){this.isPropagationStopped=K;var a=this.originalEvent;!a||(a.stopPropagation&&a.stopPropagation(),a.cancelBubble=!0)},stopImmediatePropagation:function(){this.isImmediatePropagationStopped=K,this.stopPropagation()},isDefaultPrevented:J,isPropagationStopped:J,isImmediatePropagationStopped:J},f.each({mouseenter:"mouseover",mouseleave:"mouseout"},function(a,b){f.event.special[a]={delegateType:b,bindType:b,handle:function(a){var c=this,d=a.relatedTarget,e=a.handleObj,g=e.selector,h;if(!d||d!==c&&!f.contains(c,d))a.type=e.origType,h=e.handler.apply(this,arguments),a.type=b;return h}}}),f.support.submitBubbles||(f.event.special.submit={setup:function(){if(f.nodeName(this,"form"))return!1;f.event.add(this,"click._submit keypress._submit",function(a){var c=a.target,d=f.nodeName(c,"input")||f.nodeName(c,"button")?c.form:b;d&&!d._submit_attached&&(f.event.add(d,"submit._submit",function(a){a._submit_bubble=!0}),d._submit_attached=!0)})},postDispatch:function(a){a._submit_bubble&&(delete a._submit_bubble,this.parentNode&&!a.isTrigger&&f.event.simulate("submit",this.parentNode,a,!0))},teardown:function(){if(f.nodeName(this,"form"))return!1;f.event.remove(this,"._submit")}}),f.support.changeBubbles||(f.event.special.change={setup:function(){if(z.test(this.nodeName)){if(this.type==="checkbox"||this.type==="radio")f.event.add(this,"propertychange._change",function(a){a.originalEvent.propertyName==="checked"&&(this._just_changed=!0)}),f.event.add(this,"click._change",function(a){this._just_changed&&!a.isTrigger&&(this._just_changed=!1,f.event.simulate("change",this,a,!0))});return!1}f.event.add(this,"beforeactivate._change",function(a){var b=a.target;z.test(b.nodeName)&&!b._change_attached&&(f.event.add(b,"change._change",function(a){this.parentNode&&!a.isSimulated&&!a.isTrigger&&f.event.simulate("change",this.parentNode,a,!0)}),b._change_attached=!0)})},handle:function(a){var b=a.target;if(this!==b||a.isSimulated||a.isTrigger||b.type!=="radio"&&b.type!=="checkbox")return a.handleObj.handler.apply(this,arguments)},teardown:function(){f.event.remove(this,"._change");return z.test(this.nodeName)}}),f.support.focusinBubbles||f.each({focus:"focusin",blur:"focusout"},function(a,b){var d=0,e=function(a){f.event.simulate(b,a.target,f.event.fix(a),!0)};f.event.special[b]={setup:function(){d++===0&&c.addEventListener(a,e,!0)},teardown:function(){--d===0&&c.removeEventListener(a,e,!0)}}}),f.fn.extend({on:function(a,c,d,e,g){var h,i;if(typeof a=="object"){typeof c!="string"&&(d=d||c,c=b);for(i in a)this.on(i,c,d,a[i],g);return this}d==null&&e==null?(e=c,d=c=b):e==null&&(typeof c=="string"?(e=d,d=b):(e=d,d=c,c=b));if(e===!1)e=J;else if(!e)return this;g===1&&(h=e,e=function(a){f().off(a);return h.apply(this,arguments)},e.guid=h.guid||(h.guid=f.guid++));return this.each(function(){f.event.add(this,a,e,d,c)})},one:function(a,b,c,d){return this.on(a,b,c,d,1)},off:function(a,c,d){if(a&&a.preventDefault&&a.handleObj){var e=a.handleObj;f(a.delegateTarget).off(e.namespace?e.origType+"."+e.namespace:e.origType,e.selector,e.handler);return this}if(typeof a=="object"){for(var g in a)this.off(g,c,a[g]);return this}if(c===!1||typeof c=="function")d=c,c=b;d===!1&&(d=J);return this.each(function(){f.event.remove(this,a,d,c)})},bind:function(a,b,c){return this.on(a,null,b,c)},unbind:function(a,b){return this.off(a,null,b)},live:function(a,b,c){f(this.context).on(a,this.selector,b,c);return this},die:function(a,b){f(this.context).off(a,this.selector||"**",b);return this},delegate:function(a,b,c,d){return this.on(b,a,c,d)},undelegate:function(a,b,c){return arguments.length==1?this.off(a,"**"):this.off(b,a,c)},trigger:function(a,b){return this.each(function(){f.event.trigger(a,b,this)})},triggerHandler:function(a,b){if(this[0])return f.event.trigger(a,b,this[0],!0)},toggle:function(a){var b=arguments,c=a.guid||f.guid++,d=0,e=function(c){var e=(f._data(this,"lastToggle"+a.guid)||0)%d;f._data(this,"lastToggle"+a.guid,e+1),c.preventDefault();return b[e].apply(this,arguments)||!1};e.guid=c;while(d<b.length)b[d++].guid=c;return this.click(e)},hover:function(a,b){return this.mouseenter(a).mouseleave(b||a)}}),f.each("blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error contextmenu".split(" "),function(a,b){f.fn[b]=function(a,c){c==null&&(c=a,a=null);return arguments.length>0?this.on(b,null,a,c):this.trigger(b)},f.attrFn&&(f.attrFn[b]=!0),C.test(b)&&(f.event.fixHooks[b]=f.event.keyHooks),D.test(b)&&(f.event.fixHooks[b]=f.event.mouseHooks)}),function(){function x(a,b,c,e,f,g){for(var h=0,i=e.length;h<i;h++){var j=e[h];if(j){var k=!1;j=j[a];while(j){if(j[d]===c){k=e[j.sizset];break}if(j.nodeType===1){g||(j[d]=c,j.sizset=h);if(typeof b!="string"){if(j===b){k=!0;break}}else if(m.filter(b,[j]).length>0){k=j;break}}j=j[a]}e[h]=k}}}function w(a,b,c,e,f,g){for(var h=0,i=e.length;h<i;h++){var j=e[h];if(j){var k=!1;j=j[a];while(j){if(j[d]===c){k=e[j.sizset];break}j.nodeType===1&&!g&&(j[d]=c,j.sizset=h);if(j.nodeName.toLowerCase()===b){k=j;break}j=j[a]}e[h]=k}}}var a=/((?:\((?:\([^()]+\)|[^()]+)+\)|\[(?:\[[^\[\]]*\]|['"][^'"]*['"]|[^\[\]'"]+)+\]|\\.|[^ >+~,(\[\\]+)+|[>+~])(\s*,\s*)?((?:.|\r|\n)*)/g,d="sizcache"+(Math.random()+"").replace(".",""),e=0,g=Object.prototype.toString,h=!1,i=!0,j=/\\/g,k=/\r\n/g,l=/\W/;[0,0].sort(function(){i=!1;return 0});var m=function(b,d,e,f){e=e||[],d=d||c;var h=d;if(d.nodeType!==1&&d.nodeType!==9)return[];if(!b||typeof b!="string")return e;var i,j,k,l,n,q,r,t,u=!0,v=m.isXML(d),w=[],x=b;do{a.exec(""),i=a.exec(x);if(i){x=i[3],w.push(i[1]);if(i[2]){l=i[3];break}}}while(i);if(w.length>1&&p.exec(b))if(w.length===2&&o.relative[w[0]])j=y(w[0]+w[1],d,f);else{j=o.relative[w[0]]?[d]:m(w.shift(),d);while(w.length)b=w.shift(),o.relative[b]&&(b+=w.shift()),j=y(b,j,f)}else{!f&&w.length>1&&d.nodeType===9&&!v&&o.match.ID.test(w[0])&&!o.match.ID.test(w[w.length-1])&&(n=m.find(w.shift(),d,v),d=n.expr?m.filter(n.expr,n.set)[0]:n.set[0]);if(d){n=f?{expr:w.pop(),set:s(f)}:m.find(w.pop(),w.length===1&&(w[0]==="~"||w[0]==="+")&&d.parentNode?d.parentNode:d,v),j=n.expr?m.filter(n.expr,n.set):n.set,w.length>0?k=s(j):u=!1;while(w.length)q=w.pop(),r=q,o.relative[q]?r=w.pop():q="",r==null&&(r=d),o.relative[q](k,r,v)}else k=w=[]}k||(k=j),k||m.error(q||b);if(g.call(k)==="[object Array]")if(!u)e.push.apply(e,k);else if(d&&d.nodeType===1)for(t=0;k[t]!=null;t++)k[t]&&(k[t]===!0||k[t].nodeType===1&&m.contains(d,k[t]))&&e.push(j[t]);else for(t=0;k[t]!=null;t++)k[t]&&k[t].nodeType===1&&e.push(j[t]);else s(k,e);l&&(m(l,h,e,f),m.uniqueSort(e));return e};m.uniqueSort=function(a){if(u){h=i,a.sort(u);if(h)for(var b=1;b<a.length;b++)a[b]===a[b-1]&&a.splice(b--,1)}return a},m.matches=function(a,b){return m(a,null,null,b)},m.matchesSelector=function(a,b){return m(b,null,null,[a]).length>0},m.find=function(a,b,c){var d,e,f,g,h,i;if(!a)return[];for(e=0,f=o.order.length;e<f;e++){h=o.order[e];if(g=o.leftMatch[h].exec(a)){i=g[1],g.splice(1,1);if(i.substr(i.length-1)!=="\\"){g[1]=(g[1]||"").replace(j,""),d=o.find[h](g,b,c);if(d!=null){a=a.replace(o.match[h],"");break}}}}d||(d=typeof b.getElementsByTagName!="undefined"?b.getElementsByTagName("*"):[]);return{set:d,expr:a}},m.filter=function(a,c,d,e){var f,g,h,i,j,k,l,n,p,q=a,r=[],s=c,t=c&&c[0]&&m.isXML(c[0]);while(a&&c.length){for(h in o.filter)if((f=o.leftMatch[h].exec(a))!=null&&f[2]){k=o.filter[h],l=f[1],g=!1,f.splice(1,1);if(l.substr(l.length-1)==="\\")continue;s===r&&(r=[]);if(o.preFilter[h]){f=o.preFilter[h](f,s,d,r,e,t);if(!f)g=i=!0;else if(f===!0)continue}if(f)for(n=0;(j=s[n])!=null;n++)j&&(i=k(j,f,n,s),p=e^i,d&&i!=null?p?g=!0:s[n]=!1:p&&(r.push(j),g=!0));if(i!==b){d||(s=r),a=a.replace(o.match[h],"");if(!g)return[];break}}if(a===q)if(g==null)m.error(a);else break;q=a}return s},m.error=function(a){throw new Error("Syntax error, unrecognized expression: "+a)};var n=m.getText=function(a){var b,c,d=a.nodeType,e="";if(d){if(d===1||d===9||d===11){if(typeof a.textContent=="string")return a.textContent;if(typeof a.innerText=="string")return a.innerText.replace(k,"");for(a=a.firstChild;a;a=a.nextSibling)e+=n(a)}else if(d===3||d===4)return a.nodeValue}else for(b=0;c=a[b];b++)c.nodeType!==8&&(e+=n(c));return e},o=m.selectors={order:["ID","NAME","TAG"],match:{ID:/#((?:[\w\u00c0-\uFFFF\-]|\\.)+)/,CLASS:/\.((?:[\w\u00c0-\uFFFF\-]|\\.)+)/,NAME:/\[name=['"]*((?:[\w\u00c0-\uFFFF\-]|\\.)+)['"]*\]/,ATTR:/\[\s*((?:[\w\u00c0-\uFFFF\-]|\\.)+)\s*(?:(\S?=)\s*(?:(['"])(.*?)\3|(#?(?:[\w\u00c0-\uFFFF\-]|\\.)*)|)|)\s*\]/,TAG:/^((?:[\w\u00c0-\uFFFF\*\-]|\\.)+)/,CHILD:/:(only|nth|last|first)-child(?:\(\s*(even|odd|(?:[+\-]?\d+|(?:[+\-]?\d*)?n\s*(?:[+\-]\s*\d+)?))\s*\))?/,POS:/:(nth|eq|gt|lt|first|last|even|odd)(?:\((\d*)\))?(?=[^\-]|$)/,PSEUDO:/:((?:[\w\u00c0-\uFFFF\-]|\\.)+)(?:\((['"]?)((?:\([^\)]+\)|[^\(\)]*)+)\2\))?/},leftMatch:{},attrMap:{"class":"className","for":"htmlFor"},attrHandle:{href:function(a){return a.getAttribute("href")},type:function(a){return a.getAttribute("type")}},relative:{"+":function(a,b){var c=typeof b=="string",d=c&&!l.test(b),e=c&&!d;d&&(b=b.toLowerCase());for(var f=0,g=a.length,h;f<g;f++)if(h=a[f]){while((h=h.previousSibling)&&h.nodeType!==1);a[f]=e||h&&h.nodeName.toLowerCase()===b?h||!1:h===b}e&&m.filter(b,a,!0)},">":function(a,b){var c,d=typeof b=="string",e=0,f=a.length;if(d&&!l.test(b)){b=b.toLowerCase();for(;e<f;e++){c=a[e];if(c){var g=c.parentNode;a[e]=g.nodeName.toLowerCase()===b?g:!1}}}else{for(;e<f;e++)c=a[e],c&&(a[e]=d?c.parentNode:c.parentNode===b);d&&m.filter(b,a,!0)}},"":function(a,b,c){var d,f=e++,g=x;typeof b=="string"&&!l.test(b)&&(b=b.toLowerCase(),d=b,g=w),g("parentNode",b,f,a,d,c)},"~":function(a,b,c){var d,f=e++,g=x;typeof b=="string"&&!l.test(b)&&(b=b.toLowerCase(),d=b,g=w),g("previousSibling",b,f,a,d,c)}},find:{ID:function(a,b,c){if(typeof b.getElementById!="undefined"&&!c){var d=b.getElementById(a[1]);return d&&d.parentNode?[d]:[]}},NAME:function(a,b){if(typeof b.getElementsByName!="undefined"){var c=[],d=b.getElementsByName(a[1]);for(var e=0,f=d.length;e<f;e++)d[e].getAttribute("name")===a[1]&&c.push(d[e]);return c.length===0?null:c}},TAG:function(a,b){if(typeof b.getElementsByTagName!="undefined")return b.getElementsByTagName(a[1])}},preFilter:{CLASS:function(a,b,c,d,e,f){a=" "+a[1].replace(j,"")+" ";if(f)return a;for(var g=0,h;(h=b[g])!=null;g++)h&&(e^(h.className&&(" "+h.className+" ").replace(/[\t\n\r]/g," ").indexOf(a)>=0)?c||d.push(h):c&&(b[g]=!1));return!1},ID:function(a){return a[1].replace(j,"")},TAG:function(a,b){return a[1].replace(j,"").toLowerCase()},CHILD:function(a){if(a[1]==="nth"){a[2]||m.error(a[0]),a[2]=a[2].replace(/^\+|\s*/g,"");var b=/(-?)(\d*)(?:n([+\-]?\d*))?/.exec(a[2]==="even"&&"2n"||a[2]==="odd"&&"2n+1"||!/\D/.test(a[2])&&"0n+"+a[2]||a[2]);a[2]=b[1]+(b[2]||1)-0,a[3]=b[3]-0}else a[2]&&m.error(a[0]);a[0]=e++;return a},ATTR:function(a,b,c,d,e,f){var g=a[1]=a[1].replace(j,"");!f&&o.attrMap[g]&&(a[1]=o.attrMap[g]),a[4]=(a[4]||a[5]||"").replace(j,""),a[2]==="~="&&(a[4]=" "+a[4]+" ");return a},PSEUDO:function(b,c,d,e,f){if(b[1]==="not")if((a.exec(b[3])||"").length>1||/^\w/.test(b[3]))b[3]=m(b[3],null,null,c);else{var g=m.filter(b[3],c,d,!0^f);d||e.push.apply(e,g);return!1}else if(o.match.POS.test(b[0])||o.match.CHILD.test(b[0]))return!0;return b},POS:function(a){a.unshift(!0);return a}},filters:{enabled:function(a){return a.disabled===!1&&a.type!=="hidden"},disabled:function(a){return a.disabled===!0},checked:function(a){return a.checked===!0},selected:function(a){a.parentNode&&a.parentNode.selectedIndex;return a.selected===!0},parent:function(a){return!!a.firstChild},empty:function(a){return!a.firstChild},has:function(a,b,c){return!!m(c[3],a).length},header:function(a){return/h\d/i.test(a.nodeName)},text:function(a){var b=a.getAttribute("type"),c=a.type;return a.nodeName.toLowerCase()==="input"&&"text"===c&&(b===c||b===null)},radio:function(a){return a.nodeName.toLowerCase()==="input"&&"radio"===a.type},checkbox:function(a){return a.nodeName.toLowerCase()==="input"&&"checkbox"===a.type},file:function(a){return a.nodeName.toLowerCase()==="input"&&"file"===a.type},password:function(a){return a.nodeName.toLowerCase()==="input"&&"password"===a.type},submit:function(a){var b=a.nodeName.toLowerCase();return(b==="input"||b==="button")&&"submit"===a.type},image:function(a){return a.nodeName.toLowerCase()==="input"&&"image"===a.type},reset:function(a){var b=a.nodeName.toLowerCase();return(b==="input"||b==="button")&&"reset"===a.type},button:function(a){var b=a.nodeName.toLowerCase();return b==="input"&&"button"===a.type||b==="button"},input:function(a){return/input|select|textarea|button/i.test(a.nodeName)},focus:function(a){return a===a.ownerDocument.activeElement}},setFilters:{first:function(a,b){return b===0},last:function(a,b,c,d){return b===d.length-1},even:function(a,b){return b%2===0},odd:function(a,b){return b%2===1},lt:function(a,b,c){return b<c[3]-0},gt:function(a,b,c){return b>c[3]-0},nth:function(a,b,c){return c[3]-0===b},eq:function(a,b,c){return c[3]-0===b}},filter:{PSEUDO:function(a,b,c,d){var e=b[1],f=o.filters[e];if(f)return f(a,c,b,d);if(e==="contains")return(a.textContent||a.innerText||n([a])||"").indexOf(b[3])>=0;if(e==="not"){var g=b[3];for(var h=0,i=g.length;h<i;h++)if(g[h]===a)return!1;return!0}m.error(e)},CHILD:function(a,b){var c,e,f,g,h,i,j,k=b[1],l=a;switch(k){case"only":case"first":while(l=l.previousSibling)if(l.nodeType===1)return!1;if(k==="first")return!0;l=a;case"last":while(l=l.nextSibling)if(l.nodeType===1)return!1;return!0;case"nth":c=b[2],e=b[3];if(c===1&&e===0)return!0;f=b[0],g=a.parentNode;if(g&&(g[d]!==f||!a.nodeIndex)){i=0;for(l=g.firstChild;l;l=l.nextSibling)l.nodeType===1&&(l.nodeIndex=++i);g[d]=f}j=a.nodeIndex-e;return c===0?j===0:j%c===0&&j/c>=0}},ID:function(a,b){return a.nodeType===1&&a.getAttribute("id")===b},TAG:function(a,b){return b==="*"&&a.nodeType===1||!!a.nodeName&&a.nodeName.toLowerCase()===b},CLASS:function(a,b){return(" "+(a.className||a.getAttribute("class"))+" ").indexOf(b)>-1},ATTR:function(a,b){var c=b[1],d=m.attr?m.attr(a,c):o.attrHandle[c]?o.attrHandle[c](a):a[c]!=null?a[c]:a.getAttribute(c),e=d+"",f=b[2],g=b[4];return d==null?f==="!=":!f&&m.attr?d!=null:f==="="?e===g:f==="*="?e.indexOf(g)>=0:f==="~="?(" "+e+" ").indexOf(g)>=0:g?f==="!="?e!==g:f==="^="?e.indexOf(g)===0:f==="$="?e.substr(e.length-g.length)===g:f==="|="?e===g||e.substr(0,g.length+1)===g+"-":!1:e&&d!==!1},POS:function(a,b,c,d){var e=b[2],f=o.setFilters[e];if(f)return f(a,c,b,d)}}},p=o.match.POS,q=function(a,b){return"\\"+(b-0+1)};for(var r in o.match)o.match[r]=new RegExp(o.match[r].source+/(?![^\[]*\])(?![^\(]*\))/.source),o.leftMatch[r]=new RegExp(/(^(?:.|\r|\n)*?)/.source+o.match[r].source.replace(/\\(\d+)/g,q));o.match.globalPOS=p;var s=function(a,b){a=Array.prototype.slice.call(a,0);if(b){b.push.apply(b,a);return b}return a};try{Array.prototype.slice.call(c.documentElement.childNodes,0)[0].nodeType}catch(t){s=function(a,b){var c=0,d=b||[];if(g.call(a)==="[object Array]")Array.prototype.push.apply(d,a);else if(typeof a.length=="number")for(var e=a.length;c<e;c++)d.push(a[c]);else for(;a[c];c++)d.push(a[c]);return d}}var u,v;c.documentElement.compareDocumentPosition?u=function(a,b){if(a===b){h=!0;return 0}if(!a.compareDocumentPosition||!b.compareDocumentPosition)return a.compareDocumentPosition?-1:1;return a.compareDocumentPosition(b)&4?-1:1}:(u=function(a,b){if(a===b){h=!0;return 0}if(a.sourceIndex&&b.sourceIndex)return a.sourceIndex-b.sourceIndex;var c,d,e=[],f=[],g=a.parentNode,i=b.parentNode,j=g;if(g===i)return v(a,b);if(!g)return-1;if(!i)return 1;while(j)e.unshift(j),j=j.parentNode;j=i;while(j)f.unshift(j),j=j.parentNode;c=e.length,d=f.length;for(var k=0;k<c&&k<d;k++)if(e[k]!==f[k])return v(e[k],f[k]);return k===c?v(a,f[k],-1):v(e[k],b,1)},v=function(a,b,c){if(a===b)return c;var d=a.nextSibling;while(d){if(d===b)return-1;d=d.nextSibling}return 1}),function(){var a=c.createElement("div"),d="script"+(new Date).getTime(),e=c.documentElement;a.innerHTML="<a name='"+d+"'/>",e.insertBefore(a,e.firstChild),c.getElementById(d)&&(o.find.ID=function(a,c,d){if(typeof c.getElementById!="undefined"&&!d){var e=c.getElementById(a[1]);return e?e.id===a[1]||typeof e.getAttributeNode!="undefined"&&e.getAttributeNode("id").nodeValue===a[1]?[e]:b:[]}},o.filter.ID=function(a,b){var c=typeof a.getAttributeNode!="undefined"&&a.getAttributeNode("id");return a.nodeType===1&&c&&c.nodeValue===b}),e.removeChild(a),e=a=null}(),function(){var a=c.createElement("div");a.appendChild(c.createComment("")),a.getElementsByTagName("*").length>0&&(o.find.TAG=function(a,b){var c=b.getElementsByTagName(a[1]);if(a[1]==="*"){var d=[];for(var e=0;c[e];e++)c[e].nodeType===1&&d.push(c[e]);c=d}return c}),a.innerHTML="<a href='#'></a>",a.firstChild&&typeof a.firstChild.getAttribute!="undefined"&&a.firstChild.getAttribute("href")!=="#"&&(o.attrHandle.href=function(a){return a.getAttribute("href",2)}),a=null}(),c.querySelectorAll&&function(){var a=m,b=c.createElement("div"),d="__sizzle__";b.innerHTML="<p class='TEST'></p>";if(!b.querySelectorAll||b.querySelectorAll(".TEST").length!==0){m=function(b,e,f,g){e=e||c;if(!g&&!m.isXML(e)){var h=/^(\w+$)|^\.([\w\-]+$)|^#([\w\-]+$)/.exec(b);if(h&&(e.nodeType===1||e.nodeType===9)){if(h[1])return s(e.getElementsByTagName(b),f);if(h[2]&&o.find.CLASS&&e.getElementsByClassName)return s(e.getElementsByClassName(h[2]),f)}if(e.nodeType===9){if(b==="body"&&e.body)return s([e.body],f);if(h&&h[3]){var i=e.getElementById(h[3]);if(!i||!i.parentNode)return s([],f);if(i.id===h[3])return s([i],f)}try{return s(e.querySelectorAll(b),f)}catch(j){}}else if(e.nodeType===1&&e.nodeName.toLowerCase()!=="object"){var k=e,l=e.getAttribute("id"),n=l||d,p=e.parentNode,q=/^\s*[+~]/.test(b);l?n=n.replace(/'/g,"\\$&"):e.setAttribute("id",n),q&&p&&(e=e.parentNode);try{if(!q||p)return s(e.querySelectorAll("[id='"+n+"'] "+b),f)}catch(r){}finally{l||k.removeAttribute("id")}}}return a(b,e,f,g)};for(var e in a)m[e]=a[e];b=null}}(),function(){var a=c.documentElement,b=a.matchesSelector||a.mozMatchesSelector||a.webkitMatchesSelector||a.msMatchesSelector;if(b){var d=!b.call(c.createElement("div"),"div"),e=!1;try{b.call(c.documentElement,"[test!='']:sizzle")}catch(f){e=!0}m.matchesSelector=function(a,c){c=c.replace(/\=\s*([^'"\]]*)\s*\]/g,"='$1']");if(!m.isXML(a))try{if(e||!o.match.PSEUDO.test(c)&&!/!=/.test(c)){var f=b.call(a,c);if(f||!d||a.document&&a.document.nodeType!==11)return f}}catch(g){}return m(c,null,null,[a]).length>0}}}(),function(){var a=c.createElement("div");a.innerHTML="<div class='test e'></div><div class='test'></div>";if(!!a.getElementsByClassName&&a.getElementsByClassName("e").length!==0){a.lastChild.className="e";if(a.getElementsByClassName("e").length===1)return;o.order.splice(1,0,"CLASS"),o.find.CLASS=function(a,b,c){if(typeof b.getElementsByClassName!="undefined"&&!c)return b.getElementsByClassName(a[1])},a=null}}(),c.documentElement.contains?m.contains=function(a,b){return a!==b&&(a.contains?a.contains(b):!0)}:c.documentElement.compareDocumentPosition?m.contains=function(a,b){return!!(a.compareDocumentPosition(b)&16)}:m.contains=function(){return!1},m.isXML=function(a){var b=(a?a.ownerDocument||a:0).documentElement;return b?b.nodeName!=="HTML":!1};var y=function(a,b,c){var d,e=[],f="",g=b.nodeType?[b]:b;while(d=o.match.PSEUDO.exec(a))f+=d[0],a=a.replace(o.match.PSEUDO,"");a=o.relative[a]?a+"*":a;for(var h=0,i=g.length;h<i;h++)m(a,g[h],e,c);return m.filter(f,e)};m.attr=f.attr,m.selectors.attrMap={},f.find=m,f.expr=m.selectors,f.expr[":"]=f.expr.filters,f.unique=m.uniqueSort,f.text=m.getText,f.isXMLDoc=m.isXML,f.contains=m.contains}();var L=/Until$/,M=/^(?:parents|prevUntil|prevAll)/,N=/,/,O=/^.[^:#\[\.,]*$/,P=Array.prototype.slice,Q=f.expr.match.globalPOS,R={children:!0,contents:!0,next:!0,prev:!0};f.fn.extend({find:function(a){var b=this,c,d;if(typeof a!="string")return f(a).filter(function(){for(c=0,d=b.length;c<d;c++)if(f.contains(b[c],this))return!0});var e=this.pushStack("","find",a),g,h,i;for(c=0,d=this.length;c<d;c++){g=e.length,f.find(a,this[c],e);if(c>0)for(h=g;h<e.length;h++)for(i=0;i<g;i++)if(e[i]===e[h]){e.splice(h--,1);break}}return e},has:function(a){var b=f(a);return this.filter(function(){for(var a=0,c=b.length;a<c;a++)if(f.contains(this,b[a]))return!0})},not:function(a){return this.pushStack(T(this,a,!1),"not",a)},filter:function(a){return this.pushStack(T(this,a,!0),"filter",a)},is:function(a){return!!a&&(typeof a=="string"?Q.test(a)?f(a,this.context).index(this[0])>=0:f.filter(a,this).length>0:this.filter(a).length>0)},closest:function(a,b){var c=[],d,e,g=this[0];if(f.isArray(a)){var h=1;while(g&&g.ownerDocument&&g!==b){for(d=0;d<a.length;d++)f(g).is(a[d])&&c.push({selector:a[d],elem:g,level:h});g=g.parentNode,h++}return c}var i=Q.test(a)||typeof a!="string"?f(a,b||this.context):0;for(d=0,e=this.length;d<e;d++){g=this[d];while(g){if(i?i.index(g)>-1:f.find.matchesSelector(g,a)){c.push(g);break}g=g.parentNode;if(!g||!g.ownerDocument||g===b||g.nodeType===11)break}}c=c.length>1?f.unique(c):c;return this.pushStack(c,"closest",a)},index:function(a){if(!a)return this[0]&&this[0].parentNode?this.prevAll().length:-1;if(typeof a=="string")return f.inArray(this[0],f(a));return f.inArray(a.jquery?a[0]:a,this)},add:function(a,b){var c=typeof a=="string"?f(a,b):f.makeArray(a&&a.nodeType?[a]:a),d=f.merge(this.get(),c);return this.pushStack(S(c[0])||S(d[0])?d:f.unique(d))},andSelf:function(){return this.add(this.prevObject)}}),f.each({parent:function(a){var b=a.parentNode;return b&&b.nodeType!==11?b:null},parents:function(a){return f.dir(a,"parentNode")},parentsUntil:function(a,b,c){return f.dir(a,"parentNode",c)},next:function(a){return f.nth(a,2,"nextSibling")},prev:function(a){return f.nth(a,2,"previousSibling")},nextAll:function(a){return f.dir(a,"nextSibling")},prevAll:function(a){return f.dir(a,"previousSibling")},nextUntil:function(a,b,c){return f.dir(a,"nextSibling",c)},prevUntil:function(a,b,c){return f.dir(a,"previousSibling",c)},siblings:function(a){return f.sibling((a.parentNode||{}).firstChild,a)},children:function(a){return f.sibling(a.firstChild)},contents:function(a){return f.nodeName(a,"iframe")?a.contentDocument||a.contentWindow.document:f.makeArray(a.childNodes)}},function(a,b){f.fn[a]=function(c,d){var e=f.map(this,b,c);L.test(a)||(d=c),d&&typeof d=="string"&&(e=f.filter(d,e)),e=this.length>1&&!R[a]?f.unique(e):e,(this.length>1||N.test(d))&&M.test(a)&&(e=e.reverse());return this.pushStack(e,a,P.call(arguments).join(","))}}),f.extend({filter:function(a,b,c){c&&(a=":not("+a+")");return b.length===1?f.find.matchesSelector(b[0],a)?[b[0]]:[]:f.find.matches(a,b)},dir:function(a,c,d){var e=[],g=a[c];while(g&&g.nodeType!==9&&(d===b||g.nodeType!==1||!f(g).is(d)))g.nodeType===1&&e.push(g),g=g[c];return e},nth:function(a,b,c,d){b=b||1;var e=0;for(;a;a=a[c])if(a.nodeType===1&&++e===b)break;return a},sibling:function(a,b){var c=[];for(;a;a=a.nextSibling)a.nodeType===1&&a!==b&&c.push(a);return c}});var V="abbr|article|aside|audio|bdi|canvas|data|datalist|details|figcaption|figure|footer|header|hgroup|mark|meter|nav|output|progress|section|summary|time|video",W=/ jQuery\d+="(?:\d+|null)"/g,X=/^\s+/,Y=/<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:]+)[^>]*)\/>/ig,Z=/<([\w:]+)/,$=/<tbody/i,_=/<|&#?\w+;/,ba=/<(?:script|style)/i,bb=/<(?:script|object|embed|option|style)/i,bc=new RegExp("<(?:"+V+")[\\s/>]","i"),bd=/checked\s*(?:[^=]|=\s*.checked.)/i,be=/\/(java|ecma)script/i,bf=/^\s*<!(?:\[CDATA\[|\-\-)/,bg={option:[1,"<select multiple='multiple'>","</select>"],legend:[1,"<fieldset>","</fieldset>"],thead:[1,"<table>","</table>"],tr:[2,"<table><tbody>","</tbody></table>"],td:[3,"<table><tbody><tr>","</tr></tbody></table>"],col:[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"],area:[1,"<map>","</map>"],_default:[0,"",""]},bh=U(c);bg.optgroup=bg.option,bg.tbody=bg.tfoot=bg.colgroup=bg.caption=bg.thead,bg.th=bg.td,f.support.htmlSerialize||(bg._default=[1,"div<div>","</div>"]),f.fn.extend({text:function(a){return f.access(this,function(a){return a===b?f.text(this):this.empty().append((this[0]&&this[0].ownerDocument||c).createTextNode(a))},null,a,arguments.length)},wrapAll:function(a){if(f.isFunction(a))return this.each(function(b){f(this).wrapAll(a.call(this,b))});if(this[0]){var b=f(a,this[0].ownerDocument).eq(0).clone(!0);this[0].parentNode&&b.insertBefore(this[0]),b.map(function(){var a=this;while(a.firstChild&&a.firstChild.nodeType===1)a=a.firstChild;return a}).append(this)}return this},wrapInner:function(a){if(f.isFunction(a))return this.each(function(b){f(this).wrapInner(a.call(this,b))});return this.each(function(){var b=f(this),c=b.contents();c.length?c.wrapAll(a):b.append(a)})},wrap:function(a){var b=f.isFunction(a);return this.each(function(c){f(this).wrapAll(b?a.call(this,c):a)})},unwrap:function(){return this.parent().each(function(){f.nodeName(this,"body")||f(this).replaceWith(this.childNodes)}).end()},append:function(){return this.domManip(arguments,!0,function(a){this.nodeType===1&&this.appendChild(a)})},prepend:function(){return this.domManip(arguments,!0,function(a){this.nodeType===1&&this.insertBefore(a,this.firstChild)})},before:function(){if(this[0]&&this[0].parentNode)return this.domManip(arguments,!1,function(a){this.parentNode.insertBefore(a,this)});if(arguments.length){var a=f
.clean(arguments);a.push.apply(a,this.toArray());return this.pushStack(a,"before",arguments)}},after:function(){if(this[0]&&this[0].parentNode)return this.domManip(arguments,!1,function(a){this.parentNode.insertBefore(a,this.nextSibling)});if(arguments.length){var a=this.pushStack(this,"after",arguments);a.push.apply(a,f.clean(arguments));return a}},remove:function(a,b){for(var c=0,d;(d=this[c])!=null;c++)if(!a||f.filter(a,[d]).length)!b&&d.nodeType===1&&(f.cleanData(d.getElementsByTagName("*")),f.cleanData([d])),d.parentNode&&d.parentNode.removeChild(d);return this},empty:function(){for(var a=0,b;(b=this[a])!=null;a++){b.nodeType===1&&f.cleanData(b.getElementsByTagName("*"));while(b.firstChild)b.removeChild(b.firstChild)}return this},clone:function(a,b){a=a==null?!1:a,b=b==null?a:b;return this.map(function(){return f.clone(this,a,b)})},html:function(a){return f.access(this,function(a){var c=this[0]||{},d=0,e=this.length;if(a===b)return c.nodeType===1?c.innerHTML.replace(W,""):null;if(typeof a=="string"&&!ba.test(a)&&(f.support.leadingWhitespace||!X.test(a))&&!bg[(Z.exec(a)||["",""])[1].toLowerCase()]){a=a.replace(Y,"<$1></$2>");try{for(;d<e;d++)c=this[d]||{},c.nodeType===1&&(f.cleanData(c.getElementsByTagName("*")),c.innerHTML=a);c=0}catch(g){}}c&&this.empty().append(a)},null,a,arguments.length)},replaceWith:function(a){if(this[0]&&this[0].parentNode){if(f.isFunction(a))return this.each(function(b){var c=f(this),d=c.html();c.replaceWith(a.call(this,b,d))});typeof a!="string"&&(a=f(a).detach());return this.each(function(){var b=this.nextSibling,c=this.parentNode;f(this).remove(),b?f(b).before(a):f(c).append(a)})}return this.length?this.pushStack(f(f.isFunction(a)?a():a),"replaceWith",a):this},detach:function(a){return this.remove(a,!0)},domManip:function(a,c,d){var e,g,h,i,j=a[0],k=[];if(!f.support.checkClone&&arguments.length===3&&typeof j=="string"&&bd.test(j))return this.each(function(){f(this).domManip(a,c,d,!0)});if(f.isFunction(j))return this.each(function(e){var g=f(this);a[0]=j.call(this,e,c?g.html():b),g.domManip(a,c,d)});if(this[0]){i=j&&j.parentNode,f.support.parentNode&&i&&i.nodeType===11&&i.childNodes.length===this.length?e={fragment:i}:e=f.buildFragment(a,this,k),h=e.fragment,h.childNodes.length===1?g=h=h.firstChild:g=h.firstChild;if(g){c=c&&f.nodeName(g,"tr");for(var l=0,m=this.length,n=m-1;l<m;l++)d.call(c?bi(this[l],g):this[l],e.cacheable||m>1&&l<n?f.clone(h,!0,!0):h)}k.length&&f.each(k,function(a,b){b.src?f.ajax({type:"GET",global:!1,url:b.src,async:!1,dataType:"script"}):f.globalEval((b.text||b.textContent||b.innerHTML||"").replace(bf,"/*$0*/")),b.parentNode&&b.parentNode.removeChild(b)})}return this}}),f.buildFragment=function(a,b,d){var e,g,h,i,j=a[0];b&&b[0]&&(i=b[0].ownerDocument||b[0]),i.createDocumentFragment||(i=c),a.length===1&&typeof j=="string"&&j.length<512&&i===c&&j.charAt(0)==="<"&&!bb.test(j)&&(f.support.checkClone||!bd.test(j))&&(f.support.html5Clone||!bc.test(j))&&(g=!0,h=f.fragments[j],h&&h!==1&&(e=h)),e||(e=i.createDocumentFragment(),f.clean(a,i,e,d)),g&&(f.fragments[j]=h?e:1);return{fragment:e,cacheable:g}},f.fragments={},f.each({appendTo:"append",prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(a,b){f.fn[a]=function(c){var d=[],e=f(c),g=this.length===1&&this[0].parentNode;if(g&&g.nodeType===11&&g.childNodes.length===1&&e.length===1){e[b](this[0]);return this}for(var h=0,i=e.length;h<i;h++){var j=(h>0?this.clone(!0):this).get();f(e[h])[b](j),d=d.concat(j)}return this.pushStack(d,a,e.selector)}}),f.extend({clone:function(a,b,c){var d,e,g,h=f.support.html5Clone||f.isXMLDoc(a)||!bc.test("<"+a.nodeName+">")?a.cloneNode(!0):bo(a);if((!f.support.noCloneEvent||!f.support.noCloneChecked)&&(a.nodeType===1||a.nodeType===11)&&!f.isXMLDoc(a)){bk(a,h),d=bl(a),e=bl(h);for(g=0;d[g];++g)e[g]&&bk(d[g],e[g])}if(b){bj(a,h);if(c){d=bl(a),e=bl(h);for(g=0;d[g];++g)bj(d[g],e[g])}}d=e=null;return h},clean:function(a,b,d,e){var g,h,i,j=[];b=b||c,typeof b.createElement=="undefined"&&(b=b.ownerDocument||b[0]&&b[0].ownerDocument||c);for(var k=0,l;(l=a[k])!=null;k++){typeof l=="number"&&(l+="");if(!l)continue;if(typeof l=="string")if(!_.test(l))l=b.createTextNode(l);else{l=l.replace(Y,"<$1></$2>");var m=(Z.exec(l)||["",""])[1].toLowerCase(),n=bg[m]||bg._default,o=n[0],p=b.createElement("div"),q=bh.childNodes,r;b===c?bh.appendChild(p):U(b).appendChild(p),p.innerHTML=n[1]+l+n[2];while(o--)p=p.lastChild;if(!f.support.tbody){var s=$.test(l),t=m==="table"&&!s?p.firstChild&&p.firstChild.childNodes:n[1]==="<table>"&&!s?p.childNodes:[];for(i=t.length-1;i>=0;--i)f.nodeName(t[i],"tbody")&&!t[i].childNodes.length&&t[i].parentNode.removeChild(t[i])}!f.support.leadingWhitespace&&X.test(l)&&p.insertBefore(b.createTextNode(X.exec(l)[0]),p.firstChild),l=p.childNodes,p&&(p.parentNode.removeChild(p),q.length>0&&(r=q[q.length-1],r&&r.parentNode&&r.parentNode.removeChild(r)))}var u;if(!f.support.appendChecked)if(l[0]&&typeof (u=l.length)=="number")for(i=0;i<u;i++)bn(l[i]);else bn(l);l.nodeType?j.push(l):j=f.merge(j,l)}if(d){g=function(a){return!a.type||be.test(a.type)};for(k=0;j[k];k++){h=j[k];if(e&&f.nodeName(h,"script")&&(!h.type||be.test(h.type)))e.push(h.parentNode?h.parentNode.removeChild(h):h);else{if(h.nodeType===1){var v=f.grep(h.getElementsByTagName("script"),g);j.splice.apply(j,[k+1,0].concat(v))}d.appendChild(h)}}}return j},cleanData:function(a){var b,c,d=f.cache,e=f.event.special,g=f.support.deleteExpando;for(var h=0,i;(i=a[h])!=null;h++){if(i.nodeName&&f.noData[i.nodeName.toLowerCase()])continue;c=i[f.expando];if(c){b=d[c];if(b&&b.events){for(var j in b.events)e[j]?f.event.remove(i,j):f.removeEvent(i,j,b.handle);b.handle&&(b.handle.elem=null)}g?delete i[f.expando]:i.removeAttribute&&i.removeAttribute(f.expando),delete d[c]}}}});var bp=/alpha\([^)]*\)/i,bq=/opacity=([^)]*)/,br=/([A-Z]|^ms)/g,bs=/^[\-+]?(?:\d*\.)?\d+$/i,bt=/^-?(?:\d*\.)?\d+(?!px)[^\d\s]+$/i,bu=/^([\-+])=([\-+.\de]+)/,bv=/^margin/,bw={position:"absolute",visibility:"hidden",display:"block"},bx=["Top","Right","Bottom","Left"],by,bz,bA;f.fn.css=function(a,c){return f.access(this,function(a,c,d){return d!==b?f.style(a,c,d):f.css(a,c)},a,c,arguments.length>1)},f.extend({cssHooks:{opacity:{get:function(a,b){if(b){var c=by(a,"opacity");return c===""?"1":c}return a.style.opacity}}},cssNumber:{fillOpacity:!0,fontWeight:!0,lineHeight:!0,opacity:!0,orphans:!0,widows:!0,zIndex:!0,zoom:!0},cssProps:{"float":f.support.cssFloat?"cssFloat":"styleFloat"},style:function(a,c,d,e){if(!!a&&a.nodeType!==3&&a.nodeType!==8&&!!a.style){var g,h,i=f.camelCase(c),j=a.style,k=f.cssHooks[i];c=f.cssProps[i]||i;if(d===b){if(k&&"get"in k&&(g=k.get(a,!1,e))!==b)return g;return j[c]}h=typeof d,h==="string"&&(g=bu.exec(d))&&(d=+(g[1]+1)*+g[2]+parseFloat(f.css(a,c)),h="number");if(d==null||h==="number"&&isNaN(d))return;h==="number"&&!f.cssNumber[i]&&(d+="px");if(!k||!("set"in k)||(d=k.set(a,d))!==b)try{j[c]=d}catch(l){}}},css:function(a,c,d){var e,g;c=f.camelCase(c),g=f.cssHooks[c],c=f.cssProps[c]||c,c==="cssFloat"&&(c="float");if(g&&"get"in g&&(e=g.get(a,!0,d))!==b)return e;if(by)return by(a,c)},swap:function(a,b,c){var d={},e,f;for(f in b)d[f]=a.style[f],a.style[f]=b[f];e=c.call(a);for(f in b)a.style[f]=d[f];return e}}),f.curCSS=f.css,c.defaultView&&c.defaultView.getComputedStyle&&(bz=function(a,b){var c,d,e,g,h=a.style;b=b.replace(br,"-$1").toLowerCase(),(d=a.ownerDocument.defaultView)&&(e=d.getComputedStyle(a,null))&&(c=e.getPropertyValue(b),c===""&&!f.contains(a.ownerDocument.documentElement,a)&&(c=f.style(a,b))),!f.support.pixelMargin&&e&&bv.test(b)&&bt.test(c)&&(g=h.width,h.width=c,c=e.width,h.width=g);return c}),c.documentElement.currentStyle&&(bA=function(a,b){var c,d,e,f=a.currentStyle&&a.currentStyle[b],g=a.style;f==null&&g&&(e=g[b])&&(f=e),bt.test(f)&&(c=g.left,d=a.runtimeStyle&&a.runtimeStyle.left,d&&(a.runtimeStyle.left=a.currentStyle.left),g.left=b==="fontSize"?"1em":f,f=g.pixelLeft+"px",g.left=c,d&&(a.runtimeStyle.left=d));return f===""?"auto":f}),by=bz||bA,f.each(["height","width"],function(a,b){f.cssHooks[b]={get:function(a,c,d){if(c)return a.offsetWidth!==0?bB(a,b,d):f.swap(a,bw,function(){return bB(a,b,d)})},set:function(a,b){return bs.test(b)?b+"px":b}}}),f.support.opacity||(f.cssHooks.opacity={get:function(a,b){return bq.test((b&&a.currentStyle?a.currentStyle.filter:a.style.filter)||"")?parseFloat(RegExp.$1)/100+"":b?"1":""},set:function(a,b){var c=a.style,d=a.currentStyle,e=f.isNumeric(b)?"alpha(opacity="+b*100+")":"",g=d&&d.filter||c.filter||"";c.zoom=1;if(b>=1&&f.trim(g.replace(bp,""))===""){c.removeAttribute("filter");if(d&&!d.filter)return}c.filter=bp.test(g)?g.replace(bp,e):g+" "+e}}),f(function(){f.support.reliableMarginRight||(f.cssHooks.marginRight={get:function(a,b){return f.swap(a,{display:"inline-block"},function(){return b?by(a,"margin-right"):a.style.marginRight})}})}),f.expr&&f.expr.filters&&(f.expr.filters.hidden=function(a){var b=a.offsetWidth,c=a.offsetHeight;return b===0&&c===0||!f.support.reliableHiddenOffsets&&(a.style&&a.style.display||f.css(a,"display"))==="none"},f.expr.filters.visible=function(a){return!f.expr.filters.hidden(a)}),f.each({margin:"",padding:"",border:"Width"},function(a,b){f.cssHooks[a+b]={expand:function(c){var d,e=typeof c=="string"?c.split(" "):[c],f={};for(d=0;d<4;d++)f[a+bx[d]+b]=e[d]||e[d-2]||e[0];return f}}});var bC=/%20/g,bD=/\[\]$/,bE=/\r?\n/g,bF=/#.*$/,bG=/^(.*?):[ \t]*([^\r\n]*)\r?$/mg,bH=/^(?:color|date|datetime|datetime-local|email|hidden|month|number|password|range|search|tel|text|time|url|week)$/i,bI=/^(?:about|app|app\-storage|.+\-extension|file|res|widget):$/,bJ=/^(?:GET|HEAD)$/,bK=/^\/\//,bL=/\?/,bM=/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,bN=/^(?:select|textarea)/i,bO=/\s+/,bP=/([?&])_=[^&]*/,bQ=/^([\w\+\.\-]+:)(?:\/\/([^\/?#:]*)(?::(\d+))?)?/,bR=f.fn.load,bS={},bT={},bU,bV,bW=["*/"]+["*"];try{bU=e.href}catch(bX){bU=c.createElement("a"),bU.href="",bU=bU.href}bV=bQ.exec(bU.toLowerCase())||[],f.fn.extend({load:function(a,c,d){if(typeof a!="string"&&bR)return bR.apply(this,arguments);if(!this.length)return this;var e=a.indexOf(" ");if(e>=0){var g=a.slice(e,a.length);a=a.slice(0,e)}var h="GET";c&&(f.isFunction(c)?(d=c,c=b):typeof c=="object"&&(c=f.param(c,f.ajaxSettings.traditional),h="POST"));var i=this;f.ajax({url:a,type:h,dataType:"html",data:c,complete:function(a,b,c){c=a.responseText,a.isResolved()&&(a.done(function(a){c=a}),i.html(g?f("<div>").append(c.replace(bM,"")).find(g):c)),d&&i.each(d,[c,b,a])}});return this},serialize:function(){return f.param(this.serializeArray())},serializeArray:function(){return this.map(function(){return this.elements?f.makeArray(this.elements):this}).filter(function(){return this.name&&!this.disabled&&(this.checked||bN.test(this.nodeName)||bH.test(this.type))}).map(function(a,b){var c=f(this).val();return c==null?null:f.isArray(c)?f.map(c,function(a,c){return{name:b.name,value:a.replace(bE,"\r\n")}}):{name:b.name,value:c.replace(bE,"\r\n")}}).get()}}),f.each("ajaxStart ajaxStop ajaxComplete ajaxError ajaxSuccess ajaxSend".split(" "),function(a,b){f.fn[b]=function(a){return this.on(b,a)}}),f.each(["get","post"],function(a,c){f[c]=function(a,d,e,g){f.isFunction(d)&&(g=g||e,e=d,d=b);return f.ajax({type:c,url:a,data:d,success:e,dataType:g})}}),f.extend({getScript:function(a,c){return f.get(a,b,c,"script")},getJSON:function(a,b,c){return f.get(a,b,c,"json")},ajaxSetup:function(a,b){b?b$(a,f.ajaxSettings):(b=a,a=f.ajaxSettings),b$(a,b);return a},ajaxSettings:{url:bU,isLocal:bI.test(bV[1]),global:!0,type:"GET",contentType:"application/x-www-form-urlencoded; charset=UTF-8",processData:!0,async:!0,accepts:{xml:"application/xml, text/xml",html:"text/html",text:"text/plain",json:"application/json, text/javascript","*":bW},contents:{xml:/xml/,html:/html/,json:/json/},responseFields:{xml:"responseXML",text:"responseText"},converters:{"* text":a.String,"text html":!0,"text json":f.parseJSON,"text xml":f.parseXML},flatOptions:{context:!0,url:!0}},ajaxPrefilter:bY(bS),ajaxTransport:bY(bT),ajax:function(a,c){function w(a,c,l,m){if(s!==2){s=2,q&&clearTimeout(q),p=b,n=m||"",v.readyState=a>0?4:0;var o,r,u,w=c,x=l?ca(d,v,l):b,y,z;if(a>=200&&a<300||a===304){if(d.ifModified){if(y=v.getResponseHeader("Last-Modified"))f.lastModified[k]=y;if(z=v.getResponseHeader("Etag"))f.etag[k]=z}if(a===304)w="notmodified",o=!0;else try{r=cb(d,x),w="success",o=!0}catch(A){w="parsererror",u=A}}else{u=w;if(!w||a)w="error",a<0&&(a=0)}v.status=a,v.statusText=""+(c||w),o?h.resolveWith(e,[r,w,v]):h.rejectWith(e,[v,w,u]),v.statusCode(j),j=b,t&&g.trigger("ajax"+(o?"Success":"Error"),[v,d,o?r:u]),i.fireWith(e,[v,w]),t&&(g.trigger("ajaxComplete",[v,d]),--f.active||f.event.trigger("ajaxStop"))}}typeof a=="object"&&(c=a,a=b),c=c||{};var d=f.ajaxSetup({},c),e=d.context||d,g=e!==d&&(e.nodeType||e instanceof f)?f(e):f.event,h=f.Deferred(),i=f.Callbacks("once memory"),j=d.statusCode||{},k,l={},m={},n,o,p,q,r,s=0,t,u,v={readyState:0,setRequestHeader:function(a,b){if(!s){var c=a.toLowerCase();a=m[c]=m[c]||a,l[a]=b}return this},getAllResponseHeaders:function(){return s===2?n:null},getResponseHeader:function(a){var c;if(s===2){if(!o){o={};while(c=bG.exec(n))o[c[1].toLowerCase()]=c[2]}c=o[a.toLowerCase()]}return c===b?null:c},overrideMimeType:function(a){s||(d.mimeType=a);return this},abort:function(a){a=a||"abort",p&&p.abort(a),w(0,a);return this}};h.promise(v),v.success=v.done,v.error=v.fail,v.complete=i.add,v.statusCode=function(a){if(a){var b;if(s<2)for(b in a)j[b]=[j[b],a[b]];else b=a[v.status],v.then(b,b)}return this},d.url=((a||d.url)+"").replace(bF,"").replace(bK,bV[1]+"//"),d.dataTypes=f.trim(d.dataType||"*").toLowerCase().split(bO),d.crossDomain==null&&(r=bQ.exec(d.url.toLowerCase()),d.crossDomain=!(!r||r[1]==bV[1]&&r[2]==bV[2]&&(r[3]||(r[1]==="http:"?80:443))==(bV[3]||(bV[1]==="http:"?80:443)))),d.data&&d.processData&&typeof d.data!="string"&&(d.data=f.param(d.data,d.traditional)),bZ(bS,d,c,v);if(s===2)return!1;t=d.global,d.type=d.type.toUpperCase(),d.hasContent=!bJ.test(d.type),t&&f.active++===0&&f.event.trigger("ajaxStart");if(!d.hasContent){d.data&&(d.url+=(bL.test(d.url)?"&":"?")+d.data,delete d.data),k=d.url;if(d.cache===!1){var x=f.now(),y=d.url.replace(bP,"$1_="+x);d.url=y+(y===d.url?(bL.test(d.url)?"&":"?")+"_="+x:"")}}(d.data&&d.hasContent&&d.contentType!==!1||c.contentType)&&v.setRequestHeader("Content-Type",d.contentType),d.ifModified&&(k=k||d.url,f.lastModified[k]&&v.setRequestHeader("If-Modified-Since",f.lastModified[k]),f.etag[k]&&v.setRequestHeader("If-None-Match",f.etag[k])),v.setRequestHeader("Accept",d.dataTypes[0]&&d.accepts[d.dataTypes[0]]?d.accepts[d.dataTypes[0]]+(d.dataTypes[0]!=="*"?", "+bW+"; q=0.01":""):d.accepts["*"]);for(u in d.headers)v.setRequestHeader(u,d.headers[u]);if(d.beforeSend&&(d.beforeSend.call(e,v,d)===!1||s===2)){v.abort();return!1}for(u in{success:1,error:1,complete:1})v[u](d[u]);p=bZ(bT,d,c,v);if(!p)w(-1,"No Transport");else{v.readyState=1,t&&g.trigger("ajaxSend",[v,d]),d.async&&d.timeout>0&&(q=setTimeout(function(){v.abort("timeout")},d.timeout));try{s=1,p.send(l,w)}catch(z){if(s<2)w(-1,z);else throw z}}return v},param:function(a,c){var d=[],e=function(a,b){b=f.isFunction(b)?b():b,d[d.length]=encodeURIComponent(a)+"="+encodeURIComponent(b)};c===b&&(c=f.ajaxSettings.traditional);if(f.isArray(a)||a.jquery&&!f.isPlainObject(a))f.each(a,function(){e(this.name,this.value)});else for(var g in a)b_(g,a[g],c,e);return d.join("&").replace(bC,"+")}}),f.extend({active:0,lastModified:{},etag:{}});var cc=f.now(),cd=/(\=)\?(&|$)|\?\?/i;f.ajaxSetup({jsonp:"callback",jsonpCallback:function(){return f.expando+"_"+cc++}}),f.ajaxPrefilter("json jsonp",function(b,c,d){var e=typeof b.data=="string"&&/^application\/x\-www\-form\-urlencoded/.test(b.contentType);if(b.dataTypes[0]==="jsonp"||b.jsonp!==!1&&(cd.test(b.url)||e&&cd.test(b.data))){var g,h=b.jsonpCallback=f.isFunction(b.jsonpCallback)?b.jsonpCallback():b.jsonpCallback,i=a[h],j=b.url,k=b.data,l="$1"+h+"$2";b.jsonp!==!1&&(j=j.replace(cd,l),b.url===j&&(e&&(k=k.replace(cd,l)),b.data===k&&(j+=(/\?/.test(j)?"&":"?")+b.jsonp+"="+h))),b.url=j,b.data=k,a[h]=function(a){g=[a]},d.always(function(){a[h]=i,g&&f.isFunction(i)&&a[h](g[0])}),b.converters["script json"]=function(){g||f.error(h+" was not called");return g[0]},b.dataTypes[0]="json";return"script"}}),f.ajaxSetup({accepts:{script:"text/javascript, application/javascript, application/ecmascript, application/x-ecmascript"},contents:{script:/javascript|ecmascript/},converters:{"text script":function(a){f.globalEval(a);return a}}}),f.ajaxPrefilter("script",function(a){a.cache===b&&(a.cache=!1),a.crossDomain&&(a.type="GET",a.global=!1)}),f.ajaxTransport("script",function(a){if(a.crossDomain){var d,e=c.head||c.getElementsByTagName("head")[0]||c.documentElement;return{send:function(f,g){d=c.createElement("script"),d.async="async",a.scriptCharset&&(d.charset=a.scriptCharset),d.src=a.url,d.onload=d.onreadystatechange=function(a,c){if(c||!d.readyState||/loaded|complete/.test(d.readyState))d.onload=d.onreadystatechange=null,e&&d.parentNode&&e.removeChild(d),d=b,c||g(200,"success")},e.insertBefore(d,e.firstChild)},abort:function(){d&&d.onload(0,1)}}}});var ce=a.ActiveXObject?function(){for(var a in cg)cg[a](0,1)}:!1,cf=0,cg;f.ajaxSettings.xhr=a.ActiveXObject?function(){return!this.isLocal&&ch()||ci()}:ch,function(a){f.extend(f.support,{ajax:!!a,cors:!!a&&"withCredentials"in a})}(f.ajaxSettings.xhr()),f.support.ajax&&f.ajaxTransport(function(c){if(!c.crossDomain||f.support.cors){var d;return{send:function(e,g){var h=c.xhr(),i,j;c.username?h.open(c.type,c.url,c.async,c.username,c.password):h.open(c.type,c.url,c.async);if(c.xhrFields)for(j in c.xhrFields)h[j]=c.xhrFields[j];c.mimeType&&h.overrideMimeType&&h.overrideMimeType(c.mimeType),!c.crossDomain&&!e["X-Requested-With"]&&(e["X-Requested-With"]="XMLHttpRequest");try{for(j in e)h.setRequestHeader(j,e[j])}catch(k){}h.send(c.hasContent&&c.data||null),d=function(a,e){var j,k,l,m,n;try{if(d&&(e||h.readyState===4)){d=b,i&&(h.onreadystatechange=f.noop,ce&&delete cg[i]);if(e)h.readyState!==4&&h.abort();else{j=h.status,l=h.getAllResponseHeaders(),m={},n=h.responseXML,n&&n.documentElement&&(m.xml=n);try{m.text=h.responseText}catch(a){}try{k=h.statusText}catch(o){k=""}!j&&c.isLocal&&!c.crossDomain?j=m.text?200:404:j===1223&&(j=204)}}}catch(p){e||g(-1,p)}m&&g(j,k,m,l)},!c.async||h.readyState===4?d():(i=++cf,ce&&(cg||(cg={},f(a).unload(ce)),cg[i]=d),h.onreadystatechange=d)},abort:function(){d&&d(0,1)}}}});var cj={},ck,cl,cm=/^(?:toggle|show|hide)$/,cn=/^([+\-]=)?([\d+.\-]+)([a-z%]*)$/i,co,cp=[["height","marginTop","marginBottom","paddingTop","paddingBottom"],["width","marginLeft","marginRight","paddingLeft","paddingRight"],["opacity"]],cq;f.fn.extend({show:function(a,b,c){var d,e;if(a||a===0)return this.animate(ct("show",3),a,b,c);for(var g=0,h=this.length;g<h;g++)d=this[g],d.style&&(e=d.style.display,!f._data(d,"olddisplay")&&e==="none"&&(e=d.style.display=""),(e===""&&f.css(d,"display")==="none"||!f.contains(d.ownerDocument.documentElement,d))&&f._data(d,"olddisplay",cu(d.nodeName)));for(g=0;g<h;g++){d=this[g];if(d.style){e=d.style.display;if(e===""||e==="none")d.style.display=f._data(d,"olddisplay")||""}}return this},hide:function(a,b,c){if(a||a===0)return this.animate(ct("hide",3),a,b,c);var d,e,g=0,h=this.length;for(;g<h;g++)d=this[g],d.style&&(e=f.css(d,"display"),e!=="none"&&!f._data(d,"olddisplay")&&f._data(d,"olddisplay",e));for(g=0;g<h;g++)this[g].style&&(this[g].style.display="none");return this},_toggle:f.fn.toggle,toggle:function(a,b,c){var d=typeof a=="boolean";f.isFunction(a)&&f.isFunction(b)?this._toggle.apply(this,arguments):a==null||d?this.each(function(){var b=d?a:f(this).is(":hidden");f(this)[b?"show":"hide"]()}):this.animate(ct("toggle",3),a,b,c);return this},fadeTo:function(a,b,c,d){return this.filter(":hidden").css("opacity",0).show().end().animate({opacity:b},a,c,d)},animate:function(a,b,c,d){function g(){e.queue===!1&&f._mark(this);var b=f.extend({},e),c=this.nodeType===1,d=c&&f(this).is(":hidden"),g,h,i,j,k,l,m,n,o,p,q;b.animatedProperties={};for(i in a){g=f.camelCase(i),i!==g&&(a[g]=a[i],delete a[i]);if((k=f.cssHooks[g])&&"expand"in k){l=k.expand(a[g]),delete a[g];for(i in l)i in a||(a[i]=l[i])}}for(g in a){h=a[g],f.isArray(h)?(b.animatedProperties[g]=h[1],h=a[g]=h[0]):b.animatedProperties[g]=b.specialEasing&&b.specialEasing[g]||b.easing||"swing";if(h==="hide"&&d||h==="show"&&!d)return b.complete.call(this);c&&(g==="height"||g==="width")&&(b.overflow=[this.style.overflow,this.style.overflowX,this.style.overflowY],f.css(this,"display")==="inline"&&f.css(this,"float")==="none"&&(!f.support.inlineBlockNeedsLayout||cu(this.nodeName)==="inline"?this.style.display="inline-block":this.style.zoom=1))}b.overflow!=null&&(this.style.overflow="hidden");for(i in a)j=new f.fx(this,b,i),h=a[i],cm.test(h)?(q=f._data(this,"toggle"+i)||(h==="toggle"?d?"show":"hide":0),q?(f._data(this,"toggle"+i,q==="show"?"hide":"show"),j[q]()):j[h]()):(m=cn.exec(h),n=j.cur(),m?(o=parseFloat(m[2]),p=m[3]||(f.cssNumber[i]?"":"px"),p!=="px"&&(f.style(this,i,(o||1)+p),n=(o||1)/j.cur()*n,f.style(this,i,n+p)),m[1]&&(o=(m[1]==="-="?-1:1)*o+n),j.custom(n,o,p)):j.custom(n,h,""));return!0}var e=f.speed(b,c,d);if(f.isEmptyObject(a))return this.each(e.complete,[!1]);a=f.extend({},a);return e.queue===!1?this.each(g):this.queue(e.queue,g)},stop:function(a,c,d){typeof a!="string"&&(d=c,c=a,a=b),c&&a!==!1&&this.queue(a||"fx",[]);return this.each(function(){function h(a,b,c){var e=b[c];f.removeData(a,c,!0),e.stop(d)}var b,c=!1,e=f.timers,g=f._data(this);d||f._unmark(!0,this);if(a==null)for(b in g)g[b]&&g[b].stop&&b.indexOf(".run")===b.length-4&&h(this,g,b);else g[b=a+".run"]&&g[b].stop&&h(this,g,b);for(b=e.length;b--;)e[b].elem===this&&(a==null||e[b].queue===a)&&(d?e[b](!0):e[b].saveState(),c=!0,e.splice(b,1));(!d||!c)&&f.dequeue(this,a)})}}),f.each({slideDown:ct("show",1),slideUp:ct("hide",1),slideToggle:ct("toggle",1),fadeIn:{opacity:"show"},fadeOut:{opacity:"hide"},fadeToggle:{opacity:"toggle"}},function(a,b){f.fn[a]=function(a,c,d){return this.animate(b,a,c,d)}}),f.extend({speed:function(a,b,c){var d=a&&typeof a=="object"?f.extend({},a):{complete:c||!c&&b||f.isFunction(a)&&a,duration:a,easing:c&&b||b&&!f.isFunction(b)&&b};d.duration=f.fx.off?0:typeof d.duration=="number"?d.duration:d.duration in f.fx.speeds?f.fx.speeds[d.duration]:f.fx.speeds._default;if(d.queue==null||d.queue===!0)d.queue="fx";d.old=d.complete,d.complete=function(a){f.isFunction(d.old)&&d.old.call(this),d.queue?f.dequeue(this,d.queue):a!==!1&&f._unmark(this)};return d},easing:{linear:function(a){return a},swing:function(a){return-Math.cos(a*Math.PI)/2+.5}},timers:[],fx:function(a,b,c){this.options=b,this.elem=a,this.prop=c,b.orig=b.orig||{}}}),f.fx.prototype={update:function(){this.options.step&&this.options.step.call(this.elem,this.now,this),(f.fx.step[this.prop]||f.fx.step._default)(this)},cur:function(){if(this.elem[this.prop]!=null&&(!this.elem.style||this.elem.style[this.prop]==null))return this.elem[this.prop];var a,b=f.css(this.elem,this.prop);return isNaN(a=parseFloat(b))?!b||b==="auto"?0:b:a},custom:function(a,c,d){function h(a){return e.step(a)}var e=this,g=f.fx;this.startTime=cq||cr(),this.end=c,this.now=this.start=a,this.pos=this.state=0,this.unit=d||this.unit||(f.cssNumber[this.prop]?"":"px"),h.queue=this.options.queue,h.elem=this.elem,h.saveState=function(){f._data(e.elem,"fxshow"+e.prop)===b&&(e.options.hide?f._data(e.elem,"fxshow"+e.prop,e.start):e.options.show&&f._data(e.elem,"fxshow"+e.prop,e.end))},h()&&f.timers.push(h)&&!co&&(co=setInterval(g.tick,g.interval))},show:function(){var a=f._data(this.elem,"fxshow"+this.prop);this.options.orig[this.prop]=a||f.style(this.elem,this.prop),this.options.show=!0,a!==b?this.custom(this.cur(),a):this.custom(this.prop==="width"||this.prop==="height"?1:0,this.cur()),f(this.elem).show()},hide:function(){this.options.orig[this.prop]=f._data(this.elem,"fxshow"+this.prop)||f.style(this.elem,this.prop),this.options.hide=!0,this.custom(this.cur(),0)},step:function(a){var b,c,d,e=cq||cr(),g=!0,h=this.elem,i=this.options;if(a||e>=i.duration+this.startTime){this.now=this.end,this.pos=this.state=1,this.update(),i.animatedProperties[this.prop]=!0;for(b in i.animatedProperties)i.animatedProperties[b]!==!0&&(g=!1);if(g){i.overflow!=null&&!f.support.shrinkWrapBlocks&&f.each(["","X","Y"],function(a,b){h.style["overflow"+b]=i.overflow[a]}),i.hide&&f(h).hide();if(i.hide||i.show)for(b in i.animatedProperties)f.style(h,b,i.orig[b]),f.removeData(h,"fxshow"+b,!0),f.removeData(h,"toggle"+b,!0);d=i.complete,d&&(i.complete=!1,d.call(h))}return!1}i.duration==Infinity?this.now=e:(c=e-this.startTime,this.state=c/i.duration,this.pos=f.easing[i.animatedProperties[this.prop]](this.state,c,0,1,i.duration),this.now=this.start+(this.end-this.start)*this.pos),this.update();return!0}},f.extend(f.fx,{tick:function(){var a,b=f.timers,c=0;for(;c<b.length;c++)a=b[c],!a()&&b[c]===a&&b.splice(c--,1);b.length||f.fx.stop()},interval:13,stop:function(){clearInterval(co),co=null},speeds:{slow:600,fast:200,_default:400},step:{opacity:function(a){f.style(a.elem,"opacity",a.now)},_default:function(a){a.elem.style&&a.elem.style[a.prop]!=null?a.elem.style[a.prop]=a.now+a.unit:a.elem[a.prop]=a.now}}}),f.each(cp.concat.apply([],cp),function(a,b){b.indexOf("margin")&&(f.fx.step[b]=function(a){f.style(a.elem,b,Math.max(0,a.now)+a.unit)})}),f.expr&&f.expr.filters&&(f.expr.filters.animated=function(a){return f.grep(f.timers,function(b){return a===b.elem}).length});var cv,cw=/^t(?:able|d|h)$/i,cx=/^(?:body|html)$/i;"getBoundingClientRect"in c.documentElement?cv=function(a,b,c,d){try{d=a.getBoundingClientRect()}catch(e){}if(!d||!f.contains(c,a))return d?{top:d.top,left:d.left}:{top:0,left:0};var g=b.body,h=cy(b),i=c.clientTop||g.clientTop||0,j=c.clientLeft||g.clientLeft||0,k=h.pageYOffset||f.support.boxModel&&c.scrollTop||g.scrollTop,l=h.pageXOffset||f.support.boxModel&&c.scrollLeft||g.scrollLeft,m=d.top+k-i,n=d.left+l-j;return{top:m,left:n}}:cv=function(a,b,c){var d,e=a.offsetParent,g=a,h=b.body,i=b.defaultView,j=i?i.getComputedStyle(a,null):a.currentStyle,k=a.offsetTop,l=a.offsetLeft;while((a=a.parentNode)&&a!==h&&a!==c){if(f.support.fixedPosition&&j.position==="fixed")break;d=i?i.getComputedStyle(a,null):a.currentStyle,k-=a.scrollTop,l-=a.scrollLeft,a===e&&(k+=a.offsetTop,l+=a.offsetLeft,f.support.doesNotAddBorder&&(!f.support.doesAddBorderForTableAndCells||!cw.test(a.nodeName))&&(k+=parseFloat(d.borderTopWidth)||0,l+=parseFloat(d.borderLeftWidth)||0),g=e,e=a.offsetParent),f.support.subtractsBorderForOverflowNotVisible&&d.overflow!=="visible"&&(k+=parseFloat(d.borderTopWidth)||0,l+=parseFloat(d.borderLeftWidth)||0),j=d}if(j.position==="relative"||j.position==="static")k+=h.offsetTop,l+=h.offsetLeft;f.support.fixedPosition&&j.position==="fixed"&&(k+=Math.max(c.scrollTop,h.scrollTop),l+=Math.max(c.scrollLeft,h.scrollLeft));return{top:k,left:l}},f.fn.offset=function(a){if(arguments.length)return a===b?this:this.each(function(b){f.offset.setOffset(this,a,b)});var c=this[0],d=c&&c.ownerDocument;if(!d)return null;if(c===d.body)return f.offset.bodyOffset(c);return cv(c,d,d.documentElement)},f.offset={bodyOffset:function(a){var b=a.offsetTop,c=a.offsetLeft;f.support.doesNotIncludeMarginInBodyOffset&&(b+=parseFloat(f.css(a,"marginTop"))||0,c+=parseFloat(f.css(a,"marginLeft"))||0);return{top:b,left:c}},setOffset:function(a,b,c){var d=f.css(a,"position");d==="static"&&(a.style.position="relative");var e=f(a),g=e.offset(),h=f.css(a,"top"),i=f.css(a,"left"),j=(d==="absolute"||d==="fixed")&&f.inArray("auto",[h,i])>-1,k={},l={},m,n;j?(l=e.position(),m=l.top,n=l.left):(m=parseFloat(h)||0,n=parseFloat(i)||0),f.isFunction(b)&&(b=b.call(a,c,g)),b.top!=null&&(k.top=b.top-g.top+m),b.left!=null&&(k.left=b.left-g.left+n),"using"in b?b.using.call(a,k):e.css(k)}},f.fn.extend({position:function(){if(!this[0])return null;var a=this[0],b=this.offsetParent(),c=this.offset(),d=cx.test(b[0].nodeName)?{top:0,left:0}:b.offset();c.top-=parseFloat(f.css(a,"marginTop"))||0,c.left-=parseFloat(f.css(a,"marginLeft"))||0,d.top+=parseFloat(f.css(b[0],"borderTopWidth"))||0,d.left+=parseFloat(f.css(b[0],"borderLeftWidth"))||0;return{top:c.top-d.top,left:c.left-d.left}},offsetParent:function(){return this.map(function(){var a=this.offsetParent||c.body;while(a&&!cx.test(a.nodeName)&&f.css(a,"position")==="static")a=a.offsetParent;return a})}}),f.each({scrollLeft:"pageXOffset",scrollTop:"pageYOffset"},function(a,c){var d=/Y/.test(c);f.fn[a]=function(e){return f.access(this,function(a,e,g){var h=cy(a);if(g===b)return h?c in h?h[c]:f.support.boxModel&&h.document.documentElement[e]||h.document.body[e]:a[e];h?h.scrollTo(d?f(h).scrollLeft():g,d?g:f(h).scrollTop()):a[e]=g},a,e,arguments.length,null)}}),f.each({Height:"height",Width:"width"},function(a,c){var d="client"+a,e="scroll"+a,g="offset"+a;f.fn["inner"+a]=function(){var a=this[0];return a?a.style?parseFloat(f.css(a,c,"padding")):this[c]():null},f.fn["outer"+a]=function(a){var b=this[0];return b?b.style?parseFloat(f.css(b,c,a?"margin":"border")):this[c]():null},f.fn[c]=function(a){return f.access(this,function(a,c,h){var i,j,k,l;if(f.isWindow(a)){i=a.document,j=i.documentElement[d];return f.support.boxModel&&j||i.body&&i.body[d]||j}if(a.nodeType===9){i=a.documentElement;if(i[d]>=i[e])return i[d];return Math.max(a.body[e],i[e],a.body[g],i[g])}if(h===b){k=f.css(a,c),l=parseFloat(k);return f.isNumeric(l)?l:k}f(a).css(c,h)},c,a,arguments.length,null)}}),a.jQuery=a.$=f,typeof define=="function"&&define.amd&&define.amd.jQuery&&define("jquery",[],function(){return f})})(window);
// mapping and identification of resource types
define('types', [], function() {
    
    // get canonical type name
    function map(name) {
        return typeMap[name] || name;
    }
    // get label for type
    function label(type) {
        return labels[map(type)] || 'Uncategorized';
    }
    // get plural lable for type
    function pluralLabel(type) {
        type = map(type);
        return type in pluralLabels ? labels[type] : labels[type] + 's';
    }
    // get type from CSS class(es)
    function fromClass(cls) {
        var classes = (cls || '').split(/\s+/),
            i = classes.length,
            match;
        while (i--)
            if (match = classes[i].match(/awld-type-(.+)/))
                return map(match[1]);
    }
    
    // set up types
    var TYPE_PERSON     = 'person',
        TYPE_PLACE      = 'place',
        TYPE_EVENT      = 'event',
        TYPE_CITATION   = 'citation',
        TYPE_TEXT       = 'text',
        TYPE_OBJECT     = 'object',
        TYPE_DESCRIPTION = 'description',
        // type maps
        types = [TYPE_CITATION, TYPE_EVENT, TYPE_PERSON, 
                 TYPE_PLACE, TYPE_OBJECT, TYPE_TEXT, TYPE_DESCRIPTION],
        labels = {},
        pluralLabels = {},
        typeMap = {};
    
    // set labels
    labels[TYPE_PERSON]     = 'Person';
    labels[TYPE_PLACE]      = 'Place';
    labels[TYPE_EVENT]      = 'Event';
    labels[TYPE_CITATION]   = 'Bibliographic Citation';
    labels[TYPE_TEXT]       = 'Text';
    labels[TYPE_OBJECT]     = 'Physical Object';
    labels[TYPE_DESCRIPTION] = 'Description';
    
    // map alternate type names
    typeMap['dc:Agent']     = TYPE_PERSON;
    typeMap['foaf:Person']  = TYPE_PERSON;
    typeMap['dc:Location']  = TYPE_PLACE;
    typeMap['dc:BibliographicResource'] = TYPE_CITATION;
    typeMap['dcmi:PhysicalObject']      = TYPE_OBJECT;
    typeMap['dcmi:Event']   = TYPE_EVENT;
    typeMap['dcmi:Text']    = TYPE_TEXT;
    typeMap['dc:description'] = TYPE_DESCRIPTION;
    
    return {
        types: types,
        map: map,
        label: label,
        pluralLabel: pluralLabel,
        fromClass: fromClass
    }
});

define('registry', {
    'http://arachne.uni-koeln.de/item/': 'arachne.uni-koeln.de/arachne.uni-koeln.de',
    // redirects done in such a way that awld.js won't work 'http://arachne.uni-koeln.de/entity/': 'arachne.uni-koeln.de/arachne.uni-koeln.de',
    'http://data.perseus.org/citations/urn:cts': 'perseus/urn-cts',
    'http://data.perseus.org/people/smith': 'perseus/smith',
    'http://ecatalogue.art.yale.edu/detail.htm?objectId=': 'ecatalogue.art.yale.edu/ecatalogue.art.yale.edu',
    'http://en.wikipedia.org/wiki': 'wikipedia/page',
    'http://eol.org/pages': 'eol/eol',
    'http://finds.org.uk/database/artefacts': 'finds.org.uk/finds.org.uk',
    'http://fr.wikipedia.org/wiki': 'wikipedia/page',
    'http://www.geonames.org': 'geonames/place',
    'http://lccn.loc.gov': 'loc/lccn',
    // xhtml too invalid to work 'http://metmuseum.org/Collections/': 'metmuseum.org/metmuseum.org.js',
    'http://nomisma.org/id': 'nomisma/nomisma',
    'http://numismatics.org/collection': 'numismatics.org/numismatics.org',
    'http://opencontext.org': 'opencontext/opencontext',
    'http://pelagios.dme.ait.ac.at/api/places/http%3A%2F%2Fpleiades.stoa.org%2Fplaces%2F': 'pelagios.dme.ait.ac.at/place',
    'http://pleiades.stoa.org/places': 'pleiades/place',
    'http://wikipedia.org/wiki': 'wikipedia/page',
    'http://www.trismegistos.org/text': 'trismegistos/text',
    'http://www.papyri.info': 'papyri.info/text',
    'http://www.smb.museum/ikmk/object.php': 'www.smb.museum/www.smb.museum',
    'http://www.sudoc.fr/': 'www.sudoc.fr/www.sudoc.fr',
    'http://www.worldcat.org/oclc': 'worldcat/oclc',
});

// Core UI elements: index, popup

// define('ui',['jquery', 'mustache', 'types', 'text!ui/core.css', 'text!ui/index.html', 'text!ui/index-grp.html', 'text!ui/pop.html', 'text!ui/details.html'], function($, Mustache, types, coreCss, indexTemplate, groupTemplate, popHtml, detailTemplate) {

define('ui',['jquery', 'mustache', 'types'], function($, Mustache, types) {

// these are the mustache templates. This works but a more elegant solution would be nice. Perhaps a template.js file.

      var indexTemplate = '\
<div id="aw-index" class="awld">\
    <hr/>\
    <div class="aw-index">\
        <div class="aw-panel">\
            <div class="aw-ctrl">\
                <span>Show by:</span> <div>Type</div> <div class="off">Source</div>\
            </div>\
            <div>{{#t}}{{> grp}}{{/t}}</div>\
            <div style="display:none;">{{#m}}{{> grp}}{{/m}}</div>\
        </div>\
        <div class="aw-tab">\
            Ancient World Data: <span class="refs">{{c}} Reference{{p}}</span>\
        </div>\
    </div>\
</div>';

      var groupTemplate = '\
<div class="aw-group">\
    <div class="awld-heading">{{name}}</div>\
    {{#res}}\
    <p><a href="{{href}}" target="_blank">{{name}}</a></p>\
    {{/res}}\
</div>';

      var popHtml = '\
<div class="awld-pop">\
    <div class="awld-pop-inner">\
        <div class="awld-content awld"></div>\
        <div class="arrow"></div>\
    </div>\
</div>';

       var detailTemplate = '\
<div class="awld-heading">{{#?.type}}<span class="res-type">{{type}}:</span>{{/?.type}} {{name}}</div>\
<div><a href="{{href}}" target="_blank">{{href}}</a></div>\
{{#?.latlon}}\
    <div class="media"><img src="http://maps.google.com/maps/api/staticmap?size=120x120&amp;zoom=4&amp;markers=color:blue%7C{{latlon}}&amp;sensor=false&amp;maptype=terrain"/></div>\
{{/?.latlon}}\
{{#imageURI}}\
    <div class="media"><img style="max-width:150px" src="{{imageURI}}"/></div>\
{{/imageURI}}\
<p>{{{description}}}</p>';
             
        var modules,
            $pop,
            popTimer;
            
        // utility - make a map of common resource data
        function resMap(res) {
            var data = res.data || {},
                type = types.label(res.type);
            return $.extend({}, data, { 
                href: res.href, 
                type: type,
                name: res.name(),
                // seriously, though, Mustache
                '?': {
                    latlon: !!data.latlon,
                    type: type && type != 'Uncategorized'
                }
            });
        }
        
        // load stylesheet
        function loadStyles(styles) {
            // put in baseUrl (images, etc)
            styles = styles.replace(/\/\/\//g, awld.baseUrl);
            //var $style = $('<style>' + styles + '</style>').appendTo('head');
            var $style = $('<link rel="stylesheet"  href="'+awld.baseUrl+'/ui/core.css" type="text/css"></link>').appendTo('head');
        
        }
        
        // create the index of known references
        function makeIndex() {
            // get resources grouped by module
            var mdata = modules.map(function(module) {
                    return { 
                        name: module.name,
                        res: module.resources.map(resMap)
                    };
                }),
                // get all resources
                resources = mdata.reduce(function(agg, d) {
                    return agg.concat(d.res); 
                }, []),
                count = resources.length,
                plural = count != 1 ? 's' : '',
                // get resources grouped by type
                tdata = [],
                // XXX: what about types set after resource load?
                typeGroups = resources.reduce(function(agg, res) {
                    var type = res.type;
                    if (!(type in agg))
                        agg[type] = tdata[tdata.length] = { name: type, res: [] };
                    agg[type].res.push(res);
                    return agg;
                }, {}),
                // render the index
                $index = $(Mustache.render(indexTemplate, {
                    c: count,
                    p: plural,
                    m: mdata,
                    t: tdata.sort(function(a,b) { return a.name > b.name ? 1 : -1 })
                }, { grp: groupTemplate })),
                // cache DOM refs
                $panel = $('.aw-panel', $index)
                    .add('hr', $index),
                $content = $panel.find('.aw-group');
                
            // add toggle handler
            $('.refs', $index).toggle(function() {
                hidePopup();
                $panel.show();
                $content.slideToggle('fast');
            }, function() {
                $content.slideToggle('fast', function() {
                    $panel.hide();
                });
            });
            
            // add type/source tab handler
            // Note: this won't be sufficient if more tabs are added
            $('.aw-ctrl', $index).delegate('div.off', 'click', function() {
                // toggle tabs
                $('.aw-ctrl div', $index)
                    .toggleClass('off');
                // toggle listings
                $('.aw-panel > div', $index)
                    .not('.aw-ctrl')
                    .toggle();
            });
            
            // update names when loaded
            modules.forEach(function(module) {
                module.resources.forEach(function(res) {
                    res.ready(function() {
                        if (res.data)
                            $index.find('a[href="' + res.href + '"]').text(res.name());
                    });
                });
            });
            return $index;
        }
        
        // add the index if the placeholder is found
        function addIndex(selector) {
            var $el = $(selector).first();
            if ($el.length) $el.append(makeIndex());
        }
        
        // show a pop-up window with resource details.
        // Elements adapted from Twitter Bootstrap v2.0.3
        // https://github.com/twitter/bootstrap
        // Copyright 2012 Twitter, Inc
        // Licensed under the Apache License v2.0
        // http://www.apache.org/licenses/LICENSE-2.0
        // Designed and built with all the love in the world @twitter by @mdo and @fat.
        function showPopup($ref, content) {
            // get window
            $pop = $pop || $(popHtml);
            // set content
            function setContent(html) {
               // wrap in root level element to make it valid xml for xml contexts
                html = "<div class='xml_wraper'>"+html+"</div>";
                $('.awld-content', $pop)
                    .html(html);
                $('.awld-pop-inner', $pop)
                    .toggleClass('loading', !html);
            }
            // clear previous content
            setContent('');
            if ($.isFunction(content)) {
                // this is a promise; give it a callback
                content(setContent);
            } else setContent(content);
            // set up position
            $pop.remove()
                .css({ top: 0, left: 0, display: 'block' })
                .appendTo(document.body);
            // determine position
            var pos = $.extend({}, $ref.offset(), {
                    width: $ref[0].offsetWidth,
                    height: $ref[0].offsetHeight
                }),
                actualWidth = $pop[0].offsetWidth,
                actualHeight = $pop[0].offsetHeight,
                winw = $(window).width(),
                padding = 5,
                hpos = pos.left + pos.width / 2 - actualWidth / 2,
                vpos = pos.top + pos.height / 2 - actualHeight / 2,
                // set position styles
                posStyle = hpos < padding ? // too far left?
                    // position: right
                    {placement: 'right', top: vpos, left: pos.left + pos.width} :
                        hpos + actualWidth + padding > winw ? // too far right?
                            // position: left
                            {placement: 'left', top: vpos, left: pos.left - actualWidth} :
                                pos.top - actualHeight < padding + window.scrollY ? // too far up?
                                    // position: bottom
                                    {placement: 'bottom', top: pos.top + pos.height, left: hpos} :
                                        // otherwise, position: top
                                        {placement: 'top', top: pos.top - actualHeight, left: hpos};
                                        
            $pop.css(posStyle)
                .removeClass('top bottom left right')
                .addClass(posStyle.placement);
        }
        
        function hidePopup() {
            if ($pop) $pop.remove();
        }
        
        // add functionality to show popups on hover
        function addPopup($ref, content) {
            var popupClose = awld.popupClose;
            if (popupClose == 'manual') {
                // require manual close
                $ref.mouseover(function() {
                    showPopup($ref, content);
                });
            } else {
                // automatically close after a given delay
                var clearTimer = function() {
                        if (popTimer) clearTimeout(popTimer);
                        popTimer = 0;
                    },
                    startTimer = function() {
                        clearTimer();
                        popTimer = setTimeout(function() {
                            hidePopup();
                            popTimer = 0;
                        }, popupClose);
                    };
                // set hover handler
                $ref.hover(function() {
                    clearTimer();
                    showPopup($ref, content);
                    // set handlers on the popup
                    $pop.bind('mouseover', clearTimer)
                        .bind('mouseleave', function() {
                            clearTimer();
                            hidePopup();
                            $pop.unbind('mouseleave mouseover');
                        });
                }, function() {
                    startTimer();
                });
            }
        }
        
        // simple detail view
        function detailView(res) {
            return Mustache.render(detailTemplate, resMap(res));
        }
        
        // initialize core
        function init(loadedModules) {
            modules = loadedModules;
            //if (modules.length) loadStyles(coreCss);
            if (modules.length) loadStyles('');
            addIndex('.awld-index');
        }
        
        return { 
            name: 'core',
            loadStyles: loadStyles,
            addIndex: addIndex,
            showPopup: showPopup,
            hidePopup: hidePopup,
            addPopup: addPopup,
            detailView: detailView,
            init: init
        };
});

/*!
 * Copyright (c) 2012, Institute for the Study of the Ancient World, New York University
 * Licensed under the BSD License (see LICENSE.txt)
 * @author Nick Rabinowitz
 * @author Sebastian Heath
 */

// removed in production by uglify
if (typeof DEBUG === 'undefined') {
    DEBUG = !(window.console === 'undefined');
    AWLD_VERSION = 'debug';
    // POPUP_CLOSE = 'manual';
    POPUP_CLOSE = 'auto';
    // BASE_URL = '../../src/';
    // cache busting for development
    require.config({
        urlArgs: "bust=" +  (new Date()).getTime()
    });
}

(function(window) {
    if (DEBUG) console.log('AWLD.js loaded');
        
    // utility: simple object extend
    function extend(obj, settings) {
        for (var prop in settings) {
            obj[prop] = settings[prop];
        }
    }
    
    // utility: is this a string?
    function isString(obj) {
        return typeof obj == 'string';
    }
    
    var additionalModules = {},
        // check for baseUrl, autoinit
        docScripts = document.getElementsByTagName('script'),
        scriptEl = docScripts[docScripts.length - 1],
        scriptSrc = scriptEl.src,
        defaultBaseUrl = scriptSrc.replace(/awld\.js.*/, ''),
        autoInit = !!scriptSrc.match(/autoinit/),
    
    /**
     * @name awld
     * @namespace
     * Root namespace for the library
     */
    awld = {

       /**
        * @type Boolean
        * debug flag
       */
        debug: false,

        /**
         * @type String
         * Base URL for dependencies; library and module 
         * dependencies will be loaded relative to this URL. 
         * See http://requirejs.org/docs/api.html#config for
         * more information.
         */
        baseUrl: defaultBaseUrl,
        
        /**
         * @type String
         * Path for modules, relative to baseUrl
         */
        modulePath: 'modules/',
        
        /**
         * @type String
         * Path for libraries, relative to baseUrl
         */
        libPath: 'lib/',
        
        /**
         * @type Object
         * Special path definitions for various dependencies.
         * See http://requirejs.org/docs/api.html#config for
         * more information.
         */
        paths: {},
        
        /**
         * @type String
         * Version number
         */
        version: AWLD_VERSION,
        
        /**
         * @type Object[]
         * Array of loaded modules
         */
        modules: [],
        
        /**
         * @type Object
         * Map of loaded modules, keyed by module path
         */
        moduleMap: {},
        
        /**
         * @type Boolean
         * Whether to auto-load data for all identified URIs
         */
        autoLoad: true,
         
        /**
         * @name alwd.popupClose
         * @type String|Number
         * How the popup window should be closed. Options are either a number 
         * (milliseconds to wait before closing) or the string 'manual'.
         */
        popupClose: POPUP_CLOSE,
        
        /**
         * @name alwd.scope
         * @type String|DOM Element
         * Selector or element to limit the scope of automatic resource identification.
         */
        
        /**
         * Register an additional module for awld.js to load (if its URIs are found)
         * @function
         * @param {String} uriRoot      Root for resource URIs managed by this module
         * @param {String} path         Path to the module, either a fully qualified URL or
         *                              a path relative to awld.js
         */
        registerModule: function(uriRoot, path) {
            additionalModules[uriRoot] = path;
        },
        
        /**
         * Extend the awld object with custom settings.
         * @function
         * @param {Object} settings     Hash of settings to apply
         */
        extend: function(settings) {
            extend(awld, settings);
        }
        
    },
    
    /**
     * @function
     * Initialize the library, loading and running modules based on page content
     */
    init = awld.init = function(opts) {
        if (DEBUG) console.log('Initializing library');
        
        // process arguments
        var isScope = isString(opts) || (opts && (opts.nodeType || opts.jquery)),
            isPlainObject = opts === Object(opts) && !isScope;
            
        // an object argument is configuration
        if (isPlainObject) awld.extend(opts);
        
        var scope = isScope ? opts : awld.scope,
            // check for existing jQuery
            jQuery = window.jQuery,
            // check for old versions of jQuery
            oldjQuery = jQuery && !!jQuery.fn.jquery.match(/^1\.[0-4]/),
            paths = awld.paths,
            libPath = awld.libPath,
            modulePath = awld.modulePath,
            onload = awld.onLoad,
            localJqueryPath = libPath + 'jquery/jquery-1.7.2.min',
            noConflict;
        
        // check for jQuery 
        if (!jQuery || oldjQuery) {
            // load if it's not available or doesn't meet min standards
            paths.jquery = localJqueryPath;
            noConflict = oldjQuery;
        } else {
            // register the current jQuery
            define('jquery', [], function() { return jQuery; });
        }
        
        // add libraries - XXX: better way?
        paths.handlebars = libPath + 'handlebars.runtime';
        paths.mustache = libPath + 'mustache.0.5.0-dev';
        
        // set up require
        require.config({
            baseUrl: awld.baseUrl,
            paths: paths 
        });
        
        // load registry and initialize modules
        require(['jquery', 'registry', 'ui', 'types'], function($, registry, ui, types) {
        
            // add any additional modules
            $.extend(registry, additionalModules);
        
            // deal with jQuery versions if necessary
            if (noConflict) $.noConflict(true);
            
            // add a jquery-dependent utility
            awld.accessor = function(xml) {
                $xml = $(xml);
                return function(selector, attr) {
                    var text = $(selector, $xml).map(function() {
                            return attr ? $(this).attr(attr) : $(this).text();
                        }).toArray();
                    return text.length > 1 ? text : text[0];
                };
            };
            
            /**
             * @name awld.Resource
             * @class
             * Base class for resources
             */
            var Resource = awld.Resource = function(opts) {
                var readyHandlers = [],
                    module = opts.module,
                    noFetch = module.noFetch,
                    dataType = module.dataType,
                    jsonp = dataType == 'jsonp',
                    cors = module.corsEnabled,
                    parseData = module.parseData,
                    fetching = false,
                    loaded = false,
                    yqlUrl = function(uri) {
                        return 'http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20' + dataType +
                            '%20where%20url%3D%22' + uri + '%22&format=' + dataType +
                            '&diagnostics=false&callback=?';
                    };
                return $.extend({
                    // do something when data is loaded
                    ready: function(f) {
                        if (loaded || noFetch) f();
                        else {
                            readyHandlers.push(f);
                            this.fetch();
                        }
                    },
                    // load data for this resource
                    fetch: function() {
                        // don't allow multiple reqs
                        if (!fetching && !noFetch) {
                            fetching = true;
                            var res = this,
                                parseResponse = parseData,
                                options = $.extend({
                                    url: res.uri,
                                    dataType: dataType,
                                    success: function(data) {
                                        // save data
                                        try {
                                            res.data = parseResponse(data);
                                            // potentially set type
                                            if (!res.type) res.type = types.map(module.getType(data));
                                        } catch(e) {
                                            if (DEBUG) console.error('Error loading data for ' + res.uri,  data, e);
                                        }
                                        // invoke any handlers
                                        readyHandlers.forEach(function(f) { 
                                            f(res);
                                        });
                                        loaded = res.loaded = true;
                                        if (DEBUG) console.log('Loaded resource', res.uri);
                                    },
                                    error: function() {
                                        if (DEBUG) console.error('Resource request failed', arguments);
                                    }
                                }, module.ajaxOptions),
                                // make a request using YQL as a JSONP proxy
                                makeYqlRequest = function() {
                                    if (DEBUG) console.log('Making YQL request for ' + res.uri);
                                    options.url = yqlUrl(options.url);
                                    options.dataType = 'jsonp';
                                    parseResponse = function(data) {
                                        data = data && (data.results && data.results[0] || data.query.results) || {};
                                        return parseData(data);
                                    };
                                    $.ajax(options);
                                };
                            // allow CORS to fallback on YQL
                            if (!jsonp && cors) {
                                options.error = function() {
                                    if (DEBUG) console.warn('CORS fail for ' + res.uri);
                                    makeYqlRequest();
                                };
                            }
                            // make the request
                            if (DEBUG) console.log('Fetching ' + res.uri);
                            if (jsonp || cors || module.local) $.ajax(options);
                            else makeYqlRequest();
                        }
                    },
                    name: function() {
                        return this.data && this.data.name || this.linkText;
                    }
                }, opts);
            };
            
            /**
             * @name awld.Modules
             * @class
             * Base class for modules
             */
            var Module = awld.Module = function(opts) {
                var cache = {},
                    identity = function(d) { return d; },
                    noop = function() {};
                return $.extend({
                    // by default, retrieve and cache all resources
                    init: function() {
                        var module = this,
                            resources = module.resources = [];
                        // create Resource for each unique URI
                        module.resourceMap = module.$refs.toArray()
                            .reduce(function(agg, el) {
                                var $ref = $(el),
                                    href = $ref.attr('href'),
                                    type = types.fromClass($ref.attr('class')) || types.map(module.type);
                                if (!(href in agg)) {
                                    agg[href] = Resource({
                                        module: module,
                                        uri: module.toDataUri(href),
                                        href: href,
                                        linkText: $ref.attr('title') || $ref.text(),
                                        type: type
                                    });
                                    // add to array
                                    resources.push(agg[href]);
                                }
                                // add resource to element
                                $ref.data('resource', agg[href]);
                                return agg;
                            }, {});
                        // auto load if requested
                        if (awld.autoLoad) {
                            resources.forEach(function(res) {
                                res.fetch();
                            });
                        }
                        // add pop-up for each resource
                        module.$refs.each(function() {
                            var $ref = $(this),
                                res = $ref.data('resource');
                            // do a jig to deal with unloaded resources
                            ui.addPopup($ref, function(callback) {
                                res.ready(function() {
                                    callback(module.detailView(res));
                                });
                            });
                        });
                        // hook for further initialization
                        module.initialize();
                    },
                    // translate human URI to API URI - default is the same
                    toDataUri: identity,
                    // parse data returned from server
                    parseData: identity,
                    // set type based on data
                    getType: noop,
                    dataType: 'json',
                    // detail view for popup window
                    detailView: ui.detailView,
                    initialize: noop
                }, opts);
            };
            
            // load machinery
            var target = 0,
                loaded = 0,
                modules = awld.modules,
                loadMgr = function(moduleName, module) {
                    if (DEBUG) console.log('Loaded module: ' + moduleName);
                    // add to lists
                    awld.moduleMap[moduleName] = module;
                    modules.push(module);
                    // check for complete
                    if (++loaded == target) {
                        if (DEBUG) console.log('All modules loaded');
                        awld.loaded = true;
                        // init ui
                        ui.init(modules);
                    }
                };
            
            // wrap in ready, as this looks through the DOM
            $(function() {
            
                // constrain scope based on markup
                var scopeSelector = '.awld-scope';
                if (!scope && $(scopeSelector).length)
                    scope = scopeSelector;
            
                // look for modules to initialize
                $.each(registry, function(uriBase, moduleName) {
                    // look for links with this URI base
                    var $refs = $('a[href^="' + uriBase + '"]', scope),
                        path = moduleName.indexOf('http') === 0 ? moduleName : modulePath + moduleName;
                    if ($refs.length) {
                        if (DEBUG) console.log('Found links for module: ' + moduleName);
                        target++;
                        // load module
                        require([path], function(module) {
                            // initialize with cached references
                            module.$refs = $refs;
                            module.moduleName = moduleName;
                            module = Module(module);
                            module.init();
                            // update manager
                            loadMgr(moduleName, module);
                        });
                    }   
                });
                
            });
            
        });
    };
    
    // add to global namespace
    window.awld = awld;
    
    if (autoInit) init();
    
})(window);

define("awld", function(){});

// Module: Arachne Item/Entity HTML

define('modules/arachne.uni-koeln.de/arachne.uni-koeln.de',['jquery'], function($) {
    return {
        name: 'Arachne Item',
        dataType: 'html',
        type: 'object',
        parseData: function(html) {
            var getText = awld.accessor(html);

            var imageURI = getText('img[src*="image.php"]', 'src');
            imageURI = typeof imageURI === 'string'? imageURI : imageURI[0];
            imageURI = 'http://arachne.uni-koeln.de/arachne/'+imageURI;

            return {
                name: "Arachne " + getText('#project_title'),
                //description: getText(''),
                imageURI: imageURI,
            };
        },
    };
});

// Module: Yale Art Museum  HTML

define('modules/ecatalogue.art.yale.edu/ecatalogue.art.yale.edu',['jquery'], function($) {
    return {
        name: 'Yale Art Museum Object',
        type: 'object',
        dataType: 'html',
        parseData: function(html) {
            var getText = awld.accessor(html);

            var name = getText('.d-title');
            name = typeof name === 'undefined' ? "Object" :  name;
            
            var description = getText('.d-smallm');
            description = typeof name === 'undefined' ? '' : description;

            var imageURI = getText('#dtl-refimg','src');

            return {
                name: name,
                description: description,
                imageURI: imageURI,
            };
        },
    };
});

// Module: Encyclopedia of Life HTML

define('modules/eol/eol',['jquery'], function($) {
    return {
        name: 'EOL Entries',
        type: 'description',
        dataType: 'html',
        parseData: function(html) {
            var getText = awld.accessor(html);

            var name = getText('h1.scientific_name');
            name = typeof name === 'undefined' ? "EOL Entry" : "EOL Entry: " + name;
            
            var description = getText('#text_summary .copy');
            description = typeof name === 'undefined' ? '' : description;

            return {
                name: name,
                description: description,
            };
        },
    };
});

// Module: OpenContext HTML

define('modules/finds.org.uk/finds.org.uk',['jquery'], function($) {
    return {
        name: 'Portable Antiquities Scheme Object',
        dataType: 'html',
        type: 'object',
        corsEnabled: true,
        parseData: function(html) {
            var getText = awld.accessor(html);
            var imageURI = 'http://finds.org.uk/' + getText('a[rel="lightbox"] img', 'src')
            return {
                name: "PAS " + getText('a[rel="lightbox"]', 'title'),
                description: '<br/><img style="max-width:150" src="'+imageURI+'"/>'
            };
        },
    };
});

// Module: Nomisma.org API

define('modules/geonames/place',['jquery'], function($) {
    gncodes = [ {"code" : { "term":"A.ADM1", "title":"first-order administrative division", "description":"a primary administrative division of a country, such as a state in the united states" }}, {"code" : { "term":"A.ADM2", "title":"second-order administrative division", "description":"a subdivision of a first-order administrative division" }}, {"code" : { "term":"A.ADM3", "title":"third-order administrative division", "description":"a subdivision of a second-order administrative division" }}, {"code" : { "term":"A.ADM4", "title":"fourth-order administrative division", "description":"a subdivision of a third-order administrative division" }}, {"code" : { "term":"A.ADM5", "title":"fifth-order administrative division", "description":"a subdivision of a fourth-order administrative division" }}, {"code" : { "term":"A.ADMD", "title":"administrative division", "description":"an administrative division of a country, undifferentiated as to administrative level" }}, {"code" : { "term":"A.LTER", "title":"leased area", "description":"a tract of land leased to another country, usually for military installations" }}, {"code" : { "term":"A.PCL", "title":"political entity" }}, {"code" : { "term":"A.PCLD", "title":"dependent political entity" }}, {"code" : { "term":"A.PCLF", "title":"freely associated state" }}, {"code" : { "term":"A.PCLI", "title":"independent political entity" }}, {"code" : { "term":"A.PCLIX", "title":"section of independent political entity" }}, {"code" : { "term":"A.PCLS", "title":"semi-independent political entity" }}, {"code" : { "term":"A.PRSH", "title":"parish", "description":"an ecclesiastical district" }}, {"code" : { "term":"A.TERR", "title":"territory" }}, {"code" : { "term":"A.ZN", "title":"zone" }}, {"code" : { "term":"A.ZNB", "title":"buffer zone", "description":"a zone recognized as a buffer between two nations in which military presence is minimal or absent" }}, {"code" : { "term":"H.AIRS", "title":"seaplane landing area", "description":"a place on a waterbody where floatplanes land and take off" }}, {"code" : { "term":"H.ANCH", "title":"anchorage", "description":"an area where vessels may anchor" }}, {"code" : { "term":"H.BAY", "title":"bay", "description":"a coastal indentation between two capes or headlands, larger than a cove but smaller than a gulf" }}, {"code" : { "term":"H.BAYS", "title":"bays", "description":"coastal indentations between two capes or headlands, larger than a cove but smaller than a gulf" }}, {"code" : { "term":"H.BGHT", "title":"bight(s)", "description":"an open body of water forming a slight recession in a coastline" }}, {"code" : { "term":"H.BNK", "title":"bank(s)", "description":"an elevation, typically located on a shelf, over which the depth of water is relatively shallow but sufficient for most surface navigation" }}, {"code" : { "term":"H.BNKR", "title":"stream bank", "description":"a sloping margin of a stream channel which normally confines the stream to its channel on land" }}, {"code" : { "term":"H.BNKX", "title":"section of bank" }}, {"code" : { "term":"H.BOG", "title":"bog(s)", "description":"a wetland characterized by peat forming sphagnum moss, sedge, and other acid-water plants" }}, {"code" : { "term":"H.CAPG", "title":"icecap", "description":"a dome-shaped mass of glacial ice covering an area of mountain summits or other high lands; smaller than an ice sheet" }}, {"code" : { "term":"H.CHN", "title":"channel", "description":"the deepest part of a stream, bay, lagoon, or strait, through which the main current flows" }}, {"code" : { "term":"H.CHNL", "title":"lake channel(s)", "description":"that part of a lake having water deep enough for navigation between islands, shoals, etc." }}, {"code" : { "term":"H.CHNM", "title":"marine channel", "description":"that part of a body of water deep enough for navigation through an area otherwise not suitable" }}, {"code" : { "term":"H.CHNN", "title":"navigation channel", "description":"a buoyed channel of sufficient depth for the safe navigation of vessels" }}, {"code" : { "term":"H.CNFL", "title":"confluence", "description":"a place where two or more streams or intermittent streams flow together" }}, {"code" : { "term":"H.CNL", "title":"canal", "description":"an artificial watercourse" }}, {"code" : { "term":"H.CNLA", "title":"aqueduct", "description":"a conduit used to carry water" }}, {"code" : { "term":"H.CNLB", "title":"canal bend", "description":"a conspicuously curved or bent section of a canal" }}, {"code" : { "term":"H.CNLD", "title":"drainage canal", "description":"an artificial waterway carrying water away from a wetland or from drainage ditches" }}, {"code" : { "term":"H.CNLI", "title":"irrigation canal", "description":"a canal which serves as a main conduit for irrigation water" }}, {"code" : { "term":"H.CNLN", "title":"navigation canal(s)", "description":"a watercourse constructed for navigation of vessels" }}, {"code" : { "term":"H.CNLQ", "title":"abandoned canal" }}, {"code" : { "term":"H.CNLSB", "title":"underground irrigation canal(s)", "description":"a gently inclined underground tunnel bringing water for irrigation from aquifers" }}, {"code" : { "term":"H.CNLX", "title":"section of canal" }}, {"code" : { "term":"H.COVE", "title":"cove(s)", "description":"a small coastal indentation, smaller than a bay" }}, {"code" : { "term":"H.CRKT", "title":"tidal creek(s)", "description":"a meandering channel in a coastal wetland subject to bi-directional tidal currents" }}, {"code" : { "term":"H.CRNT", "title":"current", "description":"a horizontal flow of water in a given direction with uniform velocity" }}, {"code" : { "term":"H.CUTF", "title":"cutoff", "description":"a channel formed as a result of a stream cutting through a meander neck" }}, {"code" : { "term":"H.DCK", "title":"dock(s)", "description":"a waterway between two piers, or cut into the land for the berthing of ships" }}, {"code" : { "term":"H.DCKB", "title":"docking basin", "description":"a part of a harbor where ships dock" }}, {"code" : { "term":"H.DOMG", "title":"icecap dome", "description":"a comparatively elevated area on an icecap" }}, {"code" : { "term":"H.DPRG", "title":"icecap depression", "description":"a comparatively depressed area on an icecap" }}, {"code" : { "term":"H.DTCH", "title":"ditch", "description":"a small artificial watercourse dug for draining or irrigating the land" }}, {"code" : { "term":"H.DTCHD", "title":"drainage ditch", "description":"a ditch which serves to drain the land" }}, {"code" : { "term":"H.DTCHI", "title":"irrigation ditch", "description":"a ditch which serves to distribute irrigation water" }}, {"code" : { "term":"H.DTCHM", "title":"ditch mouth(s)", "description":"an area where a drainage ditch enters a lagoon, lake or bay" }}, {"code" : { "term":"H.ESTY", "title":"estuary", "description":"a funnel-shaped stream mouth or embayment where fresh water mixes with sea water under tidal influences" }}, {"code" : { "term":"H.FISH", "title":"fishing area", "description":"a fishing ground, bank or area where fishermen go to catch fish" }}, {"code" : { "term":"H.FJD", "title":"fjord", "description":"a long, narrow, steep-walled, deep-water arm of the sea at high latitudes, usually along mountainous coasts" }}, {"code" : { "term":"H.FJDS", "title":"fjords", "description":"long, narrow, steep-walled, deep-water arms of the sea at high latitudes, usually along mountainous coasts" }}, {"code" : { "term":"H.FLLS", "title":"waterfall(s)", "description":"a perpendicular or very steep descent of the water of a stream" }}, {"code" : { "term":"H.FLLSX", "title":"section of waterfall(s)" }}, {"code" : { "term":"H.FLTM", "title":"mud flat(s)", "description":"a relatively level area of mud either between high and low tide lines, or subject to flooding" }}, {"code" : { "term":"H.FLTT", "title":"tidal flat(s)", "description":"a large flat area of mud or sand attached to the shore and alternately covered and uncovered by the tide" }}, {"code" : { "term":"H.GLCR", "title":"glacier(s)", "description":"a mass of ice, usually at high latitudes or high elevations, with sufficient thickness to flow away from the source area in lobes, tongues, or masses" }}, {"code" : { "term":"H.GULF", "title":"gulf", "description":"a large recess in the coastline, larger than a bay" }}, {"code" : { "term":"H.GYSR", "title":"geyser", "description":"a type of hot spring with intermittent eruptions of jets of hot water and steam" }}, {"code" : { "term":"H.HBR", "title":"harbor(s)", "description":"a haven or space of deep water so sheltered by the adjacent land as to afford a safe anchorage for ships" }}, {"code" : { "term":"H.HBRX", "title":"section of harbor" }}, {"code" : { "term":"H.INLT", "title":"inlet", "description":"a narrow waterway extending into the land, or connecting a bay or lagoon with a larger body of water" }}, {"code" : { "term":"H.INLTQ", "title":"former inlet", "description":"an inlet which has been filled in, or blocked by deposits" }}, {"code" : { "term":"H.LBED", "title":"lake bed(s)", "description":"a dried up or drained area of a former lake" }}, {"code" : { "term":"H.LGN", "title":"lagoon", "description":"a shallow coastal waterbody, completely or partly separated from a larger body of water by a barrier island, coral reef or other depositional feature" }}, {"code" : { "term":"H.LGNS", "title":"lagoons", "description":"shallow coastal waterbodies, completely or partly separated from a larger body of water by a barrier island, coral reef or other depositional feature" }}, {"code" : { "term":"H.LGNX", "title":"section of lagoon" }}, {"code" : { "term":"H.LK", "title":"lake", "description":"a large inland body of standing water" }}, {"code" : { "term":"H.LKC", "title":"crater lake", "description":"a lake in a crater or caldera" }}, {"code" : { "term":"H.LKI", "title":"intermittent lake" }}, {"code" : { "term":"H.LKN", "title":"salt lake", "description":"an inland body of salt water with no outlet" }}, {"code" : { "term":"H.LKNI", "title":"intermittent salt lake" }}, {"code" : { "term":"H.LKO", "title":"oxbow lake", "description":"a crescent-shaped lake commonly found adjacent to meandering streams" }}, {"code" : { "term":"H.LKOI", "title":"intermittent oxbow lake" }}, {"code" : { "term":"H.LKS", "title":"lakes", "description":"large inland bodies of standing water" }}, {"code" : { "term":"H.LKSB", "title":"underground lake", "description":"a standing body of water in a cave" }}, {"code" : { "term":"H.LKSC", "title":"crater lakes", "description":"lakes in a crater or caldera" }}, {"code" : { "term":"H.LKSI", "title":"intermittent lakes" }}, {"code" : { "term":"H.LKSN", "title":"salt lakes", "description":"inland bodies of salt water with no outlet" }}, {"code" : { "term":"H.LKSNI", "title":"intermittent salt lakes" }}, {"code" : { "term":"H.LKX", "title":"section of lake" }}, {"code" : { "term":"H.MFGN", "title":"salt evaporation ponds", "description":"diked salt ponds used in the production of solar evaporated salt" }}, {"code" : { "term":"H.MGV", "title":"mangrove swamp", "description":"a tropical tidal mud flat characterized by mangrove vegetation" }}, {"code" : { "term":"H.MOOR", "title":"moor(s)", "description":"an area of open ground overlaid with wet peaty soils" }}, {"code" : { "term":"H.MRSH", "title":"marsh(es)", "description":"a wetland dominated by grass-like vegetation" }}, {"code" : { "term":"H.MRSHN", "title":"salt marsh", "description":"a flat area, subject to periodic salt water inundation, dominated by grassy salt-tolerant plants" }}, {"code" : { "term":"H.NRWS", "title":"narrows", "description":"a navigable narrow part of a bay, strait, river, etc." }}, {"code" : { "term":"H.OCN", "title":"ocean", "description":"one of the major divisions of the vast expanse of salt water covering part of the earth" }}, {"code" : { "term":"H.OVF", "title":"overfalls", "description":"an area of breaking waves caused by the meeting of currents or by waves moving against the current" }}, {"code" : { "term":"H.PND", "title":"pond", "description":"a small standing waterbody" }}, {"code" : { "term":"H.PNDI", "title":"intermittent pond" }}, {"code" : { "term":"H.PNDN", "title":"salt pond", "description":"a small standing body of salt water often in a marsh or swamp, usually along a seacoast" }}, {"code" : { "term":"H.PNDNI", "title":"intermittent salt pond(s)" }}, {"code" : { "term":"H.PNDS", "title":"ponds", "description":"small standing waterbodies" }}, {"code" : { "term":"H.PNDSF", "title":"fishponds", "description":"ponds or enclosures in which fish are kept or raised" }}, {"code" : { "term":"H.PNDSI", "title":"intermittent ponds" }}, {"code" : { "term":"H.PNDSN", "title":"salt ponds", "description":"small standing bodies of salt water often in a marsh or swamp, usually along a seacoast" }}, {"code" : { "term":"H.POOL", "title":"pool(s)", "description":"a small and comparatively still, deep part of a larger body of water such as a stream or harbor; or a small body of standing water" }}, {"code" : { "term":"H.POOLI", "title":"intermittent pool" }}, {"code" : { "term":"H.RCH", "title":"reach", "description":"a straight section of a navigable stream or channel between two bends" }}, {"code" : { "term":"H.RDGG", "title":"icecap ridge", "description":"a linear elevation on an icecap" }}, {"code" : { "term":"H.RDST", "title":"roadstead", "description":"an open anchorage affording less protection than a harbor" }}, {"code" : { "term":"H.RF", "title":"reef(s)", "description":"a surface-navigation hazard composed of consolidated material" }}, {"code" : { "term":"H.RFC", "title":"coral reef(s)", "description":"a surface-navigation hazard composed of coral" }}, {"code" : { "term":"H.RFX", "title":"section of reef" }}, {"code" : { "term":"H.RPDS", "title":"rapids", "description":"a turbulent section of a stream associated with a steep, irregular stream bed" }}, {"code" : { "term":"H.RSV", "title":"reservoir(s)", "description":"an artificial pond or lake" }}, {"code" : { "term":"H.RSVI", "title":"intermittent reservoir" }}, {"code" : { "term":"H.RSVT", "title":"water tank", "description":"a contained pool or tank of water at, below, or above ground level" }}, {"code" : { "term":"H.RVN", "title":"ravine(s)", "description":"a small, narrow, deep, steep-sided stream channel, smaller than a gorge" }}, {"code" : { "term":"H.SBKH", "title":"sabkha(s)", "description":"a salt flat or salt encrusted plain subject to periodic inundation from flooding or high tides" }}, {"code" : { "term":"H.SD", "title":"sound", "description":"a long arm of the sea forming a channel between the mainland and an island or islands; or connecting two larger bodies of water" }}, {"code" : { "term":"H.SEA", "title":"sea", "description":"a large body of salt water more or less confined by continuous land or chains of islands forming a subdivision of an ocean" }}, {"code" : { "term":"H.SHOL", "title":"shoal(s)", "description":"a surface-navigation hazard composed of unconsolidated material" }}, {"code" : { "term":"H.SILL", "title":"sill", "description":"the low part of an underwater gap or saddle separating basins, including a similar feature at the mouth of a fjord" }}, {"code" : { "term":"H.SPNG", "title":"spring(s)", "description":"a place where ground water flows naturally out of the ground" }}, {"code" : { "term":"H.SPNS", "title":"sulphur spring(s)", "description":"a place where sulphur ground water flows naturally out of the ground" }}, {"code" : { "term":"H.SPNT", "title":"hot spring(s)", "description":"a place where hot ground water flows naturally out of the ground" }}, {"code" : { "term":"H.STM", "title":"stream", "description":"a body of running water moving to a lower level in a channel on land" }}, {"code" : { "term":"H.STMA", "title":"anabranch", "description":"a diverging branch flowing out of a main stream and rejoining it downstream" }}, {"code" : { "term":"H.STMB", "title":"stream bend", "description":"a conspicuously curved or bent segment of a stream" }}, {"code" : { "term":"H.STMC", "title":"canalized stream", "description":"a stream that has been substantially ditched, diked, or straightened" }}, {"code" : { "term":"H.STMD", "title":"distributary(-ies)", "description":"a branch which flows away from the main stream, as in a delta or irrigation canal" }}, {"code" : { "term":"H.STMH", "title":"headwaters", "description":"the source and upper part of a stream, including the upper drainage basin" }}, {"code" : { "term":"H.STMI", "title":"intermittent stream" }}, {"code" : { "term":"H.STMIX", "title":"section of intermittent stream" }}, {"code" : { "term":"H.STMM", "title":"stream mouth(s)", "description":"a place where a stream discharges into a lagoon, lake, or the sea" }}, {"code" : { "term":"H.STMQ", "title":"abandoned watercourse", "description":"a former stream or distributary no longer carrying flowing water, but still evident due to lakes, wetland, topographic or vegetation patterns" }}, {"code" : { "term":"H.STMS", "title":"streams", "description":"bodies of running water moving to a lower level in a channel on land" }}, {"code" : { "term":"H.STMSB", "title":"lost river", "description":"a surface stream that disappears into an underground channel, or dries up in an arid area" }}, {"code" : { "term":"H.STMX", "title":"section of stream" }}, {"code" : { "term":"H.STRT", "title":"strait", "description":"a relatively narrow waterway, usually narrower and less extensive than a sound, connecting two larger bodies of water" }}, {"code" : { "term":"H.SWMP", "title":"swamp", "description":"a wetland dominated by tree vegetation" }}, {"code" : { "term":"H.SYSI", "title":"irrigation system", "description":"a network of ditches and one or more of the following elements: water supply, reservoir, canal, pump, well, drain, etc." }}, {"code" : { "term":"H.TNLC", "title":"canal tunnel", "description":"a tunnel through which a canal passes" }}, {"code" : { "term":"H.WAD", "title":"wadi", "description":"a valley or ravine, bounded by relatively steep banks, which in the rainy season becomes a watercourse; found primarily in north africa and the middle east" }}, {"code" : { "term":"H.WADB", "title":"wadi bend", "description":"a conspicuously curved or bent segment of a wadi" }}, {"code" : { "term":"H.WADJ", "title":"wadi junction", "description":"a place where two or more wadies join" }}, {"code" : { "term":"H.WADM", "title":"wadi mouth", "description":"the lower terminus of a wadi where it widens into an adjoining floodplain, depression, or waterbody" }}, {"code" : { "term":"H.WADS", "title":"wadies", "description":"valleys or ravines, bounded by relatively steep banks, which in the rainy season become watercourses; found primarily in north africa and the middle east" }}, {"code" : { "term":"H.WADX", "title":"section of wadi" }}, {"code" : { "term":"H.WHRL", "title":"whirlpool", "description":"a turbulent, rotating movement of water in a stream" }}, {"code" : { "term":"H.WLL", "title":"well", "description":"a cylindrical hole, pit, or tunnel drilled or dug down to a depth from which water, oil, or gas can be pumped or brought to the surface" }}, {"code" : { "term":"H.WLLQ", "title":"abandoned well" }}, {"code" : { "term":"H.WLLS", "title":"wells", "description":"cylindrical holes, pits, or tunnels drilled or dug down to a depth from which water, oil, or gas can be pumped or brought to the surface" }}, {"code" : { "term":"H.WTLD", "title":"wetland", "description":"an area subject to inundation, usually characterized by bog, marsh, or swamp vegetation" }}, {"code" : { "term":"H.WTLDI", "title":"intermittent wetland" }}, {"code" : { "term":"H.WTRC", "title":"watercourse", "description":"a natural, well-defined channel produced by flowing water, or an artificial channel designed to carry flowing water" }}, {"code" : { "term":"H.WTRH", "title":"waterhole(s)", "description":"a natural hole, hollow, or small depression that contains water, used by man and animals, especially in arid areas" }}, {"code" : { "term":"L.AGRC", "title":"agricultural colony", "description":"a tract of land set aside for agricultural settlement" }}, {"code" : { "term":"L.AMUS", "title":"amusement park", "description":"amusement park are theme parks, adventure parks offering entertainment, similar to funfairs but with a fix location" }}, {"code" : { "term":"L.AREA", "title":"area", "description":"a tract of land without homogeneous character or boundaries" }}, {"code" : { "term":"L.BSND", "title":"drainage basin", "description":"an area drained by a stream" }}, {"code" : { "term":"L.BSNP", "title":"petroleum basin", "description":"an area underlain by an oil-rich structural basin" }}, {"code" : { "term":"L.BTL", "title":"battlefield", "description":"a site of a land battle of historical importance" }}, {"code" : { "term":"L.CLG", "title":"clearing", "description":"an area in a forest with trees removed" }}, {"code" : { "term":"L.CMN", "title":"common", "description":"a park or pasture for community use" }}, {"code" : { "term":"L.CNS", "title":"concession area", "description":"a lease of land by a government for economic development, e.g., mining, forestry" }}, {"code" : { "term":"L.COLF", "title":"coalfield", "description":"a region in which coal deposits of possible economic value occur" }}, {"code" : { "term":"L.CONT", "title":"continent", "description":"continent : europe, africa, asia, north america, south america, oceania,antarctica" }}, {"code" : { "term":"L.CST", "title":"coast", "description":"a zone of variable width straddling the shoreline" }}, {"code" : { "term":"L.CTRB", "title":"business center", "description":"a place where a number of businesses are located" }}, {"code" : { "term":"L.DEVH", "title":"housing development", "description":"a tract of land on which many houses of similar design are built according to a development plan" }}, {"code" : { "term":"L.FLD", "title":"field(s)", "description":"an open as opposed to wooded area" }}, {"code" : { "term":"L.FLDI", "title":"irrigated field(s)", "description":"a tract of level or terraced land which is irrigated" }}, {"code" : { "term":"L.GASF", "title":"gasfield", "description":"an area containing a subterranean store of natural gas of economic value" }}, {"code" : { "term":"L.GRAZ", "title":"grazing area", "description":"an area of grasses and shrubs used for grazing" }}, {"code" : { "term":"L.GVL", "title":"gravel area", "description":"an area covered with gravel" }}, {"code" : { "term":"L.INDS", "title":"industrial area", "description":"an area characterized by industrial activity" }}, {"code" : { "term":"L.LAND", "title":"arctic land", "description":"a tract of land in the arctic" }}, {"code" : { "term":"L.LCTY", "title":"locality", "description":"a minor area or place of unspecified or mixed character and indefinite boundaries" }}, {"code" : { "term":"L.MILB", "title":"military base", "description":"a place used by an army or other armed service for storing arms and supplies, and for accommodating and training troops, a base from which operations can be initiated" }}, {"code" : { "term":"L.MNA", "title":"mining area", "description":"an area of mine sites where minerals and ores are extracted" }}, {"code" : { "term":"L.MVA", "title":"maneuver area", "description":"a tract of land where military field exercises are carried out" }}, {"code" : { "term":"L.NVB", "title":"naval base", "description":"an area used to store supplies, provide barracks for troops and naval personnel, a port for naval vessels, and from which operations are initiated" }}, {"code" : { "term":"L.OAS", "title":"oasis(-es)", "description":"an area in a desert made productive by the availability of water" }}, {"code" : { "term":"L.OILF", "title":"oilfield", "description":"an area containing a subterranean store of petroleum of economic value" }}, {"code" : { "term":"L.PEAT", "title":"peat cutting area", "description":"an area where peat is harvested" }}, {"code" : { "term":"L.PRK", "title":"park", "description":"an area, often of forested land, maintained as a place of beauty, or for recreation" }}, {"code" : { "term":"L.PRT", "title":"port", "description":"a place provided with terminal and transfer facilities for loading and discharging waterborne cargo or passengers, usually located in a harbor" }}, {"code" : { "term":"L.QCKS", "title":"quicksand", "description":"an area where loose sand with water moving through it may become unstable when heavy objects are placed at the surface, causing them to sink" }}, {"code" : { "term":"L.REP", "title":"republic" }}, {"code" : { "term":"L.RES", "title":"reserve", "description":"a tract of public land reserved for future use or restricted as to use" }}, {"code" : { "term":"L.RESA", "title":"agricultural reserve", "description":"a tract of land reserved for agricultural reclamation and/or development" }}, {"code" : { "term":"L.RESF", "title":"forest reserve", "description":"a forested area set aside for preservation or controlled use" }}, {"code" : { "term":"L.RESH", "title":"hunting reserve", "description":"a tract of land used primarily for hunting" }}, {"code" : { "term":"L.RESN", "title":"nature reserve", "description":"an area reserved for the maintenance of a natural habitat" }}, {"code" : { "term":"L.RESP", "title":"palm tree reserve", "description":"an area of palm trees where use is controlled" }}, {"code" : { "term":"L.RESV", "title":"reservation", "description":"a tract of land set aside for aboriginal, tribal, or native populations" }}, {"code" : { "term":"L.RESW", "title":"wildlife reserve", "description":"a tract of public land reserved for the preservation of wildlife" }}, {"code" : { "term":"L.RGN", "title":"region", "description":"an area distinguished by one or more observable physical or cultural characteristics" }}, {"code" : { "term":"L.RGNE", "title":"economic region", "description":"a region of a country established for economic development or for statistical purposes" }}, {"code" : { "term":"L.RGNL", "title":"lake region", "description":"a tract of land distinguished by numerous lakes" }}, {"code" : { "term":"L.RNGA", "title":"artillery range", "description":"a tract of land used for artillery firing practice" }}, {"code" : { "term":"L.SALT", "title":"salt area", "description":"a shallow basin or flat where salt accumulates after periodic inundation" }}, {"code" : { "term":"L.SNOW", "title":"snowfield", "description":"an area of permanent snow and ice forming the accumulation area of a glacier" }}, {"code" : { "term":"L.TRB", "title":"tribal area", "description":"a tract of land used by nomadic or other tribes" }}, {"code" : { "term":"L.ZZZZZ", "title":"master source holdings list" }}, {"code" : { "term":"P.PPL", "title":"populated place", "description":"a city, town, village, or other agglomeration of buildings where people live and work" }}, {"code" : { "term":"P.PPLA", "title":"seat of a first-order administrative division", "description":"seat of a first-order administrative division (pplc takes precedence over ppla)" }}, {"code" : { "term":"P.PPLA2", "title":"seat of a second-order administrative division" }}, {"code" : { "term":"P.PPLA3", "title":"seat of a third-order administrative division" }}, {"code" : { "term":"P.PPLA4", "title":"seat of a fourth-order administrative division" }}, {"code" : { "term":"P.PPLC", "title":"capital of a political entity" }}, {"code" : { "term":"P.PPLF", "title":"farm village", "description":"a populated place where the population is largely engaged in agricultural activities" }}, {"code" : { "term":"P.PPLG", "title":"seat of government of a political entity" }}, {"code" : { "term":"P.PPLL", "title":"populated locality", "description":"an area similar to a locality but with a small group of dwellings or other buildings" }}, {"code" : { "term":"P.PPLQ", "title":"abandoned populated place" }}, {"code" : { "term":"P.PPLR", "title":"religious populated place", "description":"a populated place whose population is largely engaged in religious occupations" }}, {"code" : { "term":"P.PPLS", "title":"populated places", "description":"cities, towns, villages, or other agglomerations of buildings where people live and work" }}, {"code" : { "term":"P.PPLW", "title":"destroyed populated place", "description":"a village, town or city destroyed by a natural disaster, or by war" }}, {"code" : { "term":"P.PPLX", "title":"section of populated place" }}, {"code" : { "term":"P.STLMT", "title":"israeli settlement" }}, {"code" : { "term":"R.CSWY", "title":"causeway", "description":"a raised roadway across wet ground or shallow water" }}, {"code" : { "term":"R.CSWYQ", "title":"former causeway", "description":"a causeway no longer used for transportation" }}, {"code" : { "term":"R.OILP", "title":"oil pipeline", "description":"a pipeline used for transporting oil" }}, {"code" : { "term":"R.PRMN", "title":"promenade", "description":"a place for public walking, usually along a beach front" }}, {"code" : { "term":"R.PTGE", "title":"portage", "description":"a place where boats, goods, etc., are carried overland between navigable waters" }}, {"code" : { "term":"R.RD", "title":"road", "description":"an open way with improved surface for transportation of animals, people and vehicles" }}, {"code" : { "term":"R.RDA", "title":"ancient road", "description":"the remains of a road used by ancient cultures" }}, {"code" : { "term":"R.RDB", "title":"road bend", "description":"a conspicuously curved or bent section of a road" }}, {"code" : { "term":"R.RDCUT", "title":"road cut", "description":"an excavation cut through a hill or ridge for a road" }}, {"code" : { "term":"R.RDJCT", "title":"road junction", "description":"a place where two or more roads join" }}, {"code" : { "term":"R.RJCT", "title":"railroad junction", "description":"a place where two or more railroad tracks join" }}, {"code" : { "term":"R.RR", "title":"railroad", "description":"a permanent twin steel-rail track on which freight and passenger cars move long distances" }}, {"code" : { "term":"R.RRQ", "title":"abandoned railroad" }}, {"code" : { "term":"R.RTE", "title":"caravan route", "description":"the route taken by caravans" }}, {"code" : { "term":"R.RYD", "title":"railroad yard", "description":"a system of tracks used for the making up of trains, and switching and storing freight cars" }}, {"code" : { "term":"R.ST", "title":"street", "description":"a paved urban thoroughfare" }}, {"code" : { "term":"R.STKR", "title":"stock route", "description":"a route taken by livestock herds" }}, {"code" : { "term":"R.TNL", "title":"tunnel", "description":"a subterranean passageway for transportation" }}, {"code" : { "term":"R.TNLN", "title":"natural tunnel", "description":"a cave that is open at both ends" }}, {"code" : { "term":"R.TNLRD", "title":"road tunnel", "description":"a tunnel through which a road passes" }}, {"code" : { "term":"R.TNLRR", "title":"railroad tunnel", "description":"a tunnel through which a railroad passes" }}, {"code" : { "term":"R.TNLS", "title":"tunnels", "description":"subterranean passageways for transportation" }}, {"code" : { "term":"R.TRL", "title":"trail", "description":"a path, track, or route used by pedestrians, animals, or off-road vehicles" }}, {"code" : { "term":"S.ADMF", "title":"administrative facility", "description":"a government building" }}, {"code" : { "term":"S.AGRF", "title":"agricultural facility", "description":"a building and/or tract of land used for improving agriculture" }}, {"code" : { "term":"S.AIRB", "title":"airbase", "description":"an area used to store supplies, provide barracks for air force personnel, hangars and runways for aircraft, and from which operations are initiated" }}, {"code" : { "term":"S.AIRF", "title":"airfield", "description":"a place on land where aircraft land and take off; no facilities provided for the commercial handling of passengers and cargo" }}, {"code" : { "term":"S.AIRH", "title":"heliport", "description":"a place where helicopters land and take off" }}, {"code" : { "term":"S.AIRP", "title":"airport", "description":"a place where aircraft regularly land and take off, with runways, navigational aids, and major facilities for the commercial handling of passengers and cargo" }}, {"code" : { "term":"S.AIRQ", "title":"abandoned airfield" }}, {"code" : { "term":"S.AMTH", "title":"amphitheater", "description":"an oval or circular structure with rising tiers of seats about a stage or open space" }}, {"code" : { "term":"S.ANS", "title":"ancient site", "description":"a place where archeological remains, old structures, or cultural artifacts are located" }}, {"code" : { "term":"S.AQC", "title":"aquaculture facility", "description":"facility or area for the cultivation of aquatic animals and plants, especially fish, shellfish, and seaweed, in natural or controlled marine or freshwater environments; underwater agriculture" }}, {"code" : { "term":"S.ARCH", "title":"arch", "description":"a natural or man-made structure in the form of an arch" }}, {"code" : { "term":"S.ASTR", "title":"astronomical station", "description":"a point on the earth whose position has been determined by observations of celestial bodies" }}, {"code" : { "term":"S.ASYL", "title":"asylum", "description":"a facility where the insane are cared for and protected" }}, {"code" : { "term":"S.ATHF", "title":"athletic field", "description":"a tract of land used for playing team sports, and athletic track and field events" }}, {"code" : { "term":"S.ATM", "title":"automatic teller machine", "description":"an unattended electronic machine in a public place, connected to a data system and related equipment and activated by a bank customer to obtain cash withdrawals and other banking services." }}, {"code" : { "term":"S.BANK", "title":"bank", "description":"a business establishment in which money is kept for saving or commercial purposes or is invested, supplied for loans, or exchanged." }}, {"code" : { "term":"S.BCN", "title":"beacon", "description":"a fixed artificial navigation mark" }}, {"code" : { "term":"S.BDG", "title":"bridge", "description":"a structure erected across an obstacle such as a stream, road, etc., in order to carry roads, railroads, and pedestrians across" }}, {"code" : { "term":"S.BDGQ", "title":"ruined bridge", "description":"a destroyed or decayed bridge which is no longer functional" }}, {"code" : { "term":"S.BLDG", "title":"building(s)", "description":"a structure built for permanent use, as a house, factory, etc." }}, {"code" : { "term":"S.BLDO", "title":"office building", "description":"commercial building where business and/or services are conducted" }}, {"code" : { "term":"S.BP", "title":"boundary marker", "description":"a fixture marking a point along a boundary" }}, {"code" : { "term":"S.BRKS", "title":"barracks", "description":"a building for lodging military personnel" }}, {"code" : { "term":"S.BRKW", "title":"breakwater", "description":"a structure erected to break the force of waves at the entrance to a harbor or port" }}, {"code" : { "term":"S.BSTN", "title":"baling station", "description":"a facility for baling agricultural products" }}, {"code" : { "term":"S.BTYD", "title":"boatyard", "description":"a waterside facility for servicing, repairing, and building small vessels" }}, {"code" : { "term":"S.BUR", "title":"burial cave(s)", "description":"a cave used for human burials" }}, {"code" : { "term":"S.BUSTN", "title":"bus station", "description":"a facility comprising ticket office, platforms, etc. for loading and unloading passengers" }}, {"code" : { "term":"S.BUSTP", "title":"bus stop", "description":"a place lacking station facilities" }}, {"code" : { "term":"S.CARN", "title":"cairn", "description":"a heap of stones erected as a landmark or for other purposes" }}, {"code" : { "term":"S.CAVE", "title":"cave(s)", "description":"an underground passageway or chamber, or cavity on the side of a cliff" }}, {"code" : { "term":"S.CCL", "title":"centre continuous learning", "description":"centres for continuous learning" }}, {"code" : { "term":"S.CH", "title":"church", "description":"a building for public christian worship" }}, {"code" : { "term":"S.CMP", "title":"camp(s)", "description":"a site occupied by tents, huts, or other shelters for temporary use" }}, {"code" : { "term":"S.CMPL", "title":"logging camp", "description":"a camp used by loggers" }}, {"code" : { "term":"S.CMPLA", "title":"labor camp", "description":"a camp used by migrant or temporary laborers" }}, {"code" : { "term":"S.CMPMN", "title":"mining camp", "description":"a camp used by miners" }}, {"code" : { "term":"S.CMPO", "title":"oil camp", "description":"a camp used by oilfield workers" }}, {"code" : { "term":"S.CMPQ", "title":"abandoned camp" }}, {"code" : { "term":"S.CMPRF", "title":"refugee camp", "description":"a camp used by refugees" }}, {"code" : { "term":"S.CMTY", "title":"cemetery", "description":"a burial place or ground" }}, {"code" : { "term":"S.COMC", "title":"communication center", "description":"a facility, including buildings, antennae, towers and electronic equipment for receiving and transmitting information" }}, {"code" : { "term":"S.CRRL", "title":"corral(s)", "description":"a pen or enclosure for confining or capturing animals" }}, {"code" : { "term":"S.CSNO", "title":"casino", "description":"a building used for entertainment, especially gambling" }}, {"code" : { "term":"S.CSTL", "title":"castle", "description":"a large fortified building or set of buildings" }}, {"code" : { "term":"S.CSTM", "title":"customs house", "description":"a building in a port where customs and duties are paid, and where vessels are entered and cleared" }}, {"code" : { "term":"S.CTHSE", "title":"courthouse", "description":"a building in which courts of law are held" }}, {"code" : { "term":"S.CTRA", "title":"atomic center", "description":"a facility where atomic research is carried out" }}, {"code" : { "term":"S.CTRCM", "title":"community center", "description":"a facility for community recreation and other activities" }}, {"code" : { "term":"S.CTRF", "title":"facility center", "description":"a place where more than one facility is situated" }}, {"code" : { "term":"S.CTRM", "title":"medical center", "description":"a complex of health care buildings including two or more of the following: hospital, medical school, clinic, pharmacy, doctor's offices, etc." }}, {"code" : { "term":"S.CTRR", "title":"religious center", "description":"a facility where more than one religious activity is carried out, e.g., retreat, school, monastery, worship" }}, {"code" : { "term":"S.CTRS", "title":"space center", "description":"a facility for launching, tracking, or controlling satellites and space vehicles" }}, {"code" : { "term":"S.CVNT", "title":"convent", "description":"a building where a community of nuns lives in seclusion" }}, {"code" : { "term":"S.DAM", "title":"dam", "description":"a barrier constructed across a stream to impound water" }}, {"code" : { "term":"S.DAMQ", "title":"ruined dam", "description":"a destroyed or decayed dam which is no longer functional" }}, {"code" : { "term":"S.DAMSB", "title":"sub-surface dam", "description":"a dam put down to bedrock in a sand river" }}, {"code" : { "term":"S.DARY", "title":"dairy", "description":"a facility for the processing, sale and distribution of milk or milk products" }}, {"code" : { "term":"S.DCKD", "title":"dry dock", "description":"a dock providing support for a vessel, and means for removing the water so that the bottom of the vessel can be exposed" }}, {"code" : { "term":"S.DCKY", "title":"dockyard", "description":"a facility for servicing, building, or repairing ships" }}, {"code" : { "term":"S.DIKE", "title":"dike", "description":"an earth or stone embankment usually constructed for flood or stream control" }}, {"code" : { "term":"S.DIP", "title":"diplomatic facility", "description":"office, residence, or facility of a foreign government, which may include an embassy, consulate, chancery, office of charge d?affaires, or other diplomatic, economic, military, or cultural mission" }}, {"code" : { "term":"S.DPOF", "title":"fuel depot", "description":"an area where fuel is stored" }}, {"code" : { "term":"S.EST", "title":"estate(s)", "description":"a large commercialized agricultural landholding with associated buildings and other facilities" }}, {"code" : { "term":"S.ESTB", "title":"banana plantation", "description":"an estate that specializes in the growing of bananas" }}, {"code" : { "term":"S.ESTC", "title":"cotton plantation", "description":"an estate specializing in the cultivation of cotton" }}, {"code" : { "term":"S.ESTO", "title":"oil palm plantation", "description":"an estate specializing in the cultivation of oil palm trees" }}, {"code" : { "term":"S.ESTR", "title":"rubber plantation", "description":"an estate which specializes in growing and tapping rubber trees" }}, {"code" : { "term":"S.ESTSG", "title":"sugar plantation", "description":"an estate that specializes in growing sugar cane" }}, {"code" : { "term":"S.ESTSL", "title":"sisal plantation", "description":"an estate that specializes in growing sisal" }}, {"code" : { "term":"S.ESTT", "title":"tea plantation", "description":"an estate which specializes in growing tea bushes" }}, {"code" : { "term":"S.ESTX", "title":"section of estate" }}, {"code" : { "term":"S.FCL", "title":"facility", "description":"a building or buildings housing a center, institute, foundation, hospital, prison, mission, courthouse, etc." }}, {"code" : { "term":"S.FNDY", "title":"foundry", "description":"a building or works where metal casting is carried out" }}, {"code" : { "term":"S.FRM", "title":"farm", "description":"a tract of land with associated buildings devoted to agriculture" }}, {"code" : { "term":"S.FRMQ", "title":"abandoned farm" }}, {"code" : { "term":"S.FRMS", "title":"farms", "description":"tracts of land with associated buildings devoted to agriculture" }}, {"code" : { "term":"S.FRMT", "title":"farmstead", "description":"the buildings and adjacent service areas of a farm" }}, {"code" : { "term":"S.FT", "title":"fort", "description":"a defensive structure or earthworks" }}, {"code" : { "term":"S.FY", "title":"ferry", "description":"a boat or other floating conveyance and terminal facilities regularly used to transport people and vehicles across a waterbody" }}, {"code" : { "term":"S.GATE", "title":"gate", "description":"a controlled access entrance or exit" }}, {"code" : { "term":"S.GDN", "title":"garden(s)", "description":"an enclosure for displaying selected plant or animal life" }}, {"code" : { "term":"S.GHAT", "title":"ghat", "description":"a set of steps leading to a river, which are of religious significance, and at their base is usually a platform for bathing" }}, {"code" : { "term":"S.GHSE", "title":"guest house", "description":"a house used to provide lodging for paying guests" }}, {"code" : { "term":"S.GOSP", "title":"gas-oil separator plant", "description":"a facility for separating gas from oil" }}, {"code" : { "term":"S.GOVL", "title":"local government office", "description":"a facility housing local governmental offices, usually a city, town, or village hall" }}, {"code" : { "term":"S.GRVE", "title":"grave", "description":"a burial site" }}, {"code" : { "term":"S.HERM", "title":"hermitage", "description":"a secluded residence, usually for religious sects" }}, {"code" : { "term":"S.HLT", "title":"halting place", "description":"a place where caravans stop for rest" }}, {"code" : { "term":"S.HSE", "title":"house(s)", "description":"a building used as a human habitation" }}, {"code" : { "term":"S.HSEC", "title":"country house", "description":"a large house, mansion, or chateau, on a large estate" }}, {"code" : { "term":"S.HSP", "title":"hospital", "description":"a building in which sick or injured, especially those confined to bed, are medically treated" }}, {"code" : { "term":"S.HSPC", "title":"clinic", "description":"a medical facility associated with a hospital for outpatients" }}, {"code" : { "term":"S.HSPD", "title":"dispensary", "description":"a building where medical or dental aid is dispensed" }}, {"code" : { "term":"S.HSPL", "title":"leprosarium", "description":"an asylum or hospital for lepers" }}, {"code" : { "term":"S.HSTS", "title":"historical site", "description":"a place of historical importance" }}, {"code" : { "term":"S.HTL", "title":"hotel", "description":"a building providing lodging and/or meals for the public" }}, {"code" : { "term":"S.HUT", "title":"hut", "description":"a small primitive house" }}, {"code" : { "term":"S.HUTS", "title":"huts", "description":"small primitive houses" }}, {"code" : { "term":"S.INSM", "title":"military installation", "description":"a facility for use of and control by armed forces" }}, {"code" : { "term":"S.ITTR", "title":"research institute", "description":"a facility where research is carried out" }}, {"code" : { "term":"S.JTY", "title":"jetty", "description":"a structure built out into the water at a river mouth or harbor entrance to regulate currents and silting" }}, {"code" : { "term":"S.LDNG", "title":"landing", "description":"a place where boats receive or discharge passengers and freight, but lacking most port facilities" }}, {"code" : { "term":"S.LEPC", "title":"leper colony", "description":"a settled area inhabited by lepers in relative isolation" }}, {"code" : { "term":"S.LIBR", "title":"library", "description":"a place in which information resources such as books are kept for reading, reference, or lending." }}, {"code" : { "term":"S.LNDF", "title":"landfill", "description":"a place for trash and garbage disposal in which the waste is buried between layers of earth to build up low-lying land" }}, {"code" : { "term":"S.LOCK", "title":"lock(s)", "description":"a basin in a waterway with gates at each end by means of which vessels are passed from one water level to another" }}, {"code" : { "term":"S.LTHSE", "title":"lighthouse", "description":"a distinctive structure exhibiting a major navigation light" }}, {"code" : { "term":"S.MALL", "title":"mall", "description":"a large, often enclosed shopping complex containing various stores, businesses, and restaurants usually accessible by common passageways." }}, {"code" : { "term":"S.MAR", "title":"marina", "description":"a harbor facility for small boats, yachts, etc." }}, {"code" : { "term":"S.MFG", "title":"factory", "description":"one or more buildings where goods are manufactured, processed or fabricated" }}, {"code" : { "term":"S.MFGB", "title":"brewery", "description":"one or more buildings where beer is brewed" }}, {"code" : { "term":"S.MFGC", "title":"cannery", "description":"a building where food items are canned" }}, {"code" : { "term":"S.MFGCU", "title":"copper works", "description":"a facility for processing copper ore" }}, {"code" : { "term":"S.MFGLM", "title":"limekiln", "description":"a furnace in which limestone is reduced to lime" }}, {"code" : { "term":"S.MFGM", "title":"munitions plant", "description":"a factory where ammunition is made" }}, {"code" : { "term":"S.MFGPH", "title":"phosphate works", "description":"a facility for producing fertilizer" }}, {"code" : { "term":"S.MFGQ", "title":"abandoned factory" }}, {"code" : { "term":"S.MFGSG", "title":"sugar refinery", "description":"a facility for converting raw sugar into refined sugar" }}, {"code" : { "term":"S.MKT", "title":"market", "description":"a place where goods are bought and sold at regular intervals" }}, {"code" : { "term":"S.ML", "title":"mill(s)", "description":"a building housing machines for transforming, shaping, finishing, grinding, or extracting products" }}, {"code" : { "term":"S.MLM", "title":"ore treatment plant", "description":"a facility for improving the metal content of ore by concentration" }}, {"code" : { "term":"S.MLO", "title":"olive oil mill", "description":"a mill where oil is extracted from olives" }}, {"code" : { "term":"S.MLSG", "title":"sugar mill", "description":"a facility where sugar cane is processed into raw sugar" }}, {"code" : { "term":"S.MLSGQ", "title":"former sugar mill", "description":"a sugar mill no longer used as a sugar mill" }}, {"code" : { "term":"S.MLSW", "title":"sawmill", "description":"a mill where logs or lumber are sawn to specified shapes and sizes" }}, {"code" : { "term":"S.MLWND", "title":"windmill", "description":"a mill or water pump powered by wind" }}, {"code" : { "term":"S.MLWTR", "title":"water mill", "description":"a mill powered by running water" }}, {"code" : { "term":"S.MN", "title":"mine(s)", "description":"a site where mineral ores are extracted from the ground by excavating surface pits and subterranean passages" }}, {"code" : { "term":"S.MNAU", "title":"gold mine(s)", "description":"a mine where gold ore, or alluvial gold is extracted" }}, {"code" : { "term":"S.MNC", "title":"coal mine(s)", "description":"a mine where coal is extracted" }}, {"code" : { "term":"S.MNCR", "title":"chrome mine(s)", "description":"a mine where chrome ore is extracted" }}, {"code" : { "term":"S.MNCU", "title":"copper mine(s)", "description":"a mine where copper ore is extracted" }}, {"code" : { "term":"S.MNDT", "title":"diatomite mine(s)", "description":"a place where diatomaceous earth is extracted" }}, {"code" : { "term":"S.MNFE", "title":"iron mine(s)", "description":"a mine where iron ore is extracted" }}, {"code" : { "term":"S.MNMT", "title":"monument", "description":"a commemorative structure or statue" }}, {"code" : { "term":"S.MNN", "title":"salt mine(s)", "description":"a mine from which salt is extracted" }}, {"code" : { "term":"S.MNNI", "title":"nickel mine(s)", "description":"a mine where nickel ore is extracted" }}, {"code" : { "term":"S.MNPB", "title":"lead mine(s)", "description":"a mine where lead ore is extracted" }}, {"code" : { "term":"S.MNPL", "title":"placer mine(s)", "description":"a place where heavy metals are concentrated and running water is used to extract them from unconsolidated sediments" }}, {"code" : { "term":"S.MNQ", "title":"abandoned mine" }}, {"code" : { "term":"S.MNQR", "title":"quarry(-ies)", "description":"a surface mine where building stone or gravel and sand, etc. are extracted" }}, {"code" : { "term":"S.MNSN", "title":"tin mine(s)", "description":"a mine where tin ore is extracted" }}, {"code" : { "term":"S.MOLE", "title":"mole", "description":"a massive structure of masonry or large stones serving as a pier or breakwater" }}, {"code" : { "term":"S.MSQE", "title":"mosque", "description":"a building for public islamic worship" }}, {"code" : { "term":"S.MSSN", "title":"mission", "description":"a place characterized by dwellings, school, church, hospital and other facilities operated by a religious group for the purpose of providing charitable services and to propagate religion" }}, {"code" : { "term":"S.MSSNQ", "title":"abandoned mission" }}, {"code" : { "term":"S.MSTY", "title":"monastery", "description":"a building and grounds where a community of monks lives in seclusion" }}, {"code" : { "term":"S.MTRO", "title":"metro station", "description":"metro station (underground, tube, or métro)" }}, {"code" : { "term":"S.MUS", "title":"museum", "description":"a building where objects of permanent interest in one or more of the arts and sciences are preserved and exhibited" }}, {"code" : { "term":"S.NOV", "title":"novitiate", "description":"a religious house or school where novices are trained" }}, {"code" : { "term":"S.NSY", "title":"nursery(-ies)", "description":"a place where plants are propagated for transplanting or grafting" }}, {"code" : { "term":"S.OBPT", "title":"observation point", "description":"a wildlife or scenic observation point" }}, {"code" : { "term":"S.OBS", "title":"observatory", "description":"a facility equipped for observation of atmospheric or space phenomena" }}, {"code" : { "term":"S.OBSR", "title":"radio observatory", "description":"a facility equipped with an array of antennae for receiving radio waves from space" }}, {"code" : { "term":"S.OILJ", "title":"oil pipeline junction", "description":"a section of an oil pipeline where two or more pipes join together" }}, {"code" : { "term":"S.OILQ", "title":"abandoned oil well" }}, {"code" : { "term":"S.OILR", "title":"oil refinery", "description":"a facility for converting crude oil into refined petroleum products" }}, {"code" : { "term":"S.OILT", "title":"tank farm", "description":"a tract of land occupied by large, cylindrical, metal tanks in which oil or liquid petrochemicals are stored" }}, {"code" : { "term":"S.OILW", "title":"oil well", "description":"a well from which oil may be pumped" }}, {"code" : { "term":"S.OPRA", "title":"opera house", "description":"a theater designed chiefly for the performance of operas." }}, {"code" : { "term":"S.PAL", "title":"palace", "description":"a large stately house, often a royal or presidential residence" }}, {"code" : { "term":"S.PGDA", "title":"pagoda", "description":"a tower-like storied structure, usually a buddhist shrine" }}, {"code" : { "term":"S.PIER", "title":"pier", "description":"a structure built out into navigable water on piles providing berthing for ships and recreation" }}, {"code" : { "term":"S.PKLT", "title":"parking lot", "description":"an area used for parking vehicles" }}, {"code" : { "term":"S.PMPO", "title":"oil pumping station", "description":"a facility for pumping oil through a pipeline" }}, {"code" : { "term":"S.PMPW", "title":"water pumping station", "description":"a facility for pumping water from a major well or through a pipeline" }}, {"code" : { "term":"S.PO", "title":"post office", "description":"a public building in which mail is received, sorted and distributed" }}, {"code" : { "term":"S.PP", "title":"police post", "description":"a building in which police are stationed" }}, {"code" : { "term":"S.PPQ", "title":"abandoned police post" }}, {"code" : { "term":"S.PRKGT", "title":"park gate", "description":"a controlled access to a park" }}, {"code" : { "term":"S.PRKHQ", "title":"park headquarters", "description":"a park administrative facility" }}, {"code" : { "term":"S.PRN", "title":"prison", "description":"a facility for confining prisoners" }}, {"code" : { "term":"S.PRNJ", "title":"reformatory", "description":"a facility for confining, training, and reforming young law offenders" }}, {"code" : { "term":"S.PRNQ", "title":"abandoned prison" }}, {"code" : { "term":"S.PS", "title":"power station", "description":"a facility for generating electric power" }}, {"code" : { "term":"S.PSH", "title":"hydroelectric power station", "description":"a building where electricity is generated from water power" }}, {"code" : { "term":"S.PSTB", "title":"border post", "description":"a post or station at an international boundary for the regulation of movement of people and goods" }}, {"code" : { "term":"S.PSTC", "title":"customs post", "description":"a building at an international boundary where customs and duties are paid on goods" }}, {"code" : { "term":"S.PSTP", "title":"patrol post", "description":"a post from which patrols are sent out" }}, {"code" : { "term":"S.PYR", "title":"pyramid", "description":"an ancient massive structure of square ground plan with four triangular faces meeting at a point and used for enclosing tombs" }}, {"code" : { "term":"S.PYRS", "title":"pyramids", "description":"ancient massive structures of square ground plan with four triangular faces meeting at a point and used for enclosing tombs" }}, {"code" : { "term":"S.QUAY", "title":"quay", "description":"a structure of solid construction along a shore or bank which provides berthing for ships and which generally provides cargo handling facilities" }}, {"code" : { "term":"S.RDCR", "title":"traffic circle", "description":"a road junction formed around a central circle about which traffic moves in one direction only" }}, {"code" : { "term":"S.RECG", "title":"golf course", "description":"a recreation field where golf is played" }}, {"code" : { "term":"S.RECR", "title":"racetrack", "description":"a track where races are held" }}, {"code" : { "term":"S.REST", "title":"restaurant", "description":"a place where meals are served to the public" }}, {"code" : { "term":"S.RET", "title":"store", "description":"a building where goods and/or services are offered for sale" }}, {"code" : { "term":"S.RHSE", "title":"resthouse", "description":"a structure maintained for the rest and shelter of travelers" }}, {"code" : { "term":"S.RKRY", "title":"rookery", "description":"a breeding place of a colony of birds or seals" }}, {"code" : { "term":"S.RLG", "title":"religious site", "description":"an ancient site of significant religious importance" }}, {"code" : { "term":"S.RLGR", "title":"retreat", "description":"a place of temporary seclusion, especially for religious groups" }}, {"code" : { "term":"S.RNCH", "title":"ranch(es)", "description":"a large farm specializing in extensive grazing of livestock" }}, {"code" : { "term":"S.RSD", "title":"railroad siding", "description":"a short track parallel to and joining the main track" }}, {"code" : { "term":"S.RSGNL", "title":"railroad signal", "description":"a signal at the entrance of a particular section of track governing the movement of trains" }}, {"code" : { "term":"S.RSRT", "title":"resort", "description":"a specialized facility for vacation, health, or participation sports activities" }}, {"code" : { "term":"S.RSTN", "title":"railroad station", "description":"a facility comprising ticket office, platforms, etc. for loading and unloading train passengers and freight" }}, {"code" : { "term":"S.RSTNQ", "title":"abandoned railroad station" }}, {"code" : { "term":"S.RSTP", "title":"railroad stop", "description":"a place lacking station facilities where trains stop to pick up and unload passengers and freight" }}, {"code" : { "term":"S.RSTPQ", "title":"abandoned railroad stop" }}, {"code" : { "term":"S.RUIN", "title":"ruin(s)", "description":"a destroyed or decayed structure which is no longer functional" }}, {"code" : { "term":"S.SCH", "title":"school", "description":"building(s) where instruction in one or more branches of knowledge takes place" }}, {"code" : { "term":"S.SCHA", "title":"agricultural school", "description":"a school with a curriculum focused on agriculture" }}, {"code" : { "term":"S.SCHC", "title":"college", "description":"the grounds and buildings of an institution of higher learning" }}, {"code" : { "term":"S.SCHD", "title":"driving school", "description":"driving school" }}, {"code" : { "term":"S.SCHL", "title":"language school", "description":"language schools & institutions" }}, {"code" : { "term":"S.SCHM", "title":"military school", "description":"a school at which military science forms the core of the curriculum" }}, {"code" : { "term":"S.SCHN", "title":"maritime school", "description":"a school at which maritime sciences form the core of the curriculum" }}, {"code" : { "term":"S.SCHT", "title":"technical school", "description":"post-secondary school with a specifically technical or vocational curriculum" }}, {"code" : { "term":"S.SECP", "title":"state exam prep centre", "description":"state exam preparation centres" }}, {"code" : { "term":"S.SHPF", "title":"sheepfold", "description":"a fence or wall enclosure for sheep and other small herd animals" }}, {"code" : { "term":"S.SHRN", "title":"shrine", "description":"a structure or place memorializing a person or religious concept" }}, {"code" : { "term":"S.SHSE", "title":"storehouse", "description":"a building for storing goods, especially provisions" }}, {"code" : { "term":"S.SLCE", "title":"sluice", "description":"a conduit or passage for carrying off surplus water from a waterbody, usually regulated by means of a sluice gate" }}, {"code" : { "term":"S.SNTR", "title":"sanatorium", "description":"a facility where victims of physical or mental disorders are treated" }}, {"code" : { "term":"S.SPA", "title":"spa", "description":"a resort area usually developed around a medicinal spring" }}, {"code" : { "term":"S.SPLY", "title":"spillway", "description":"a passage or outlet through which surplus water flows over, around or through a dam" }}, {"code" : { "term":"S.SQR", "title":"square", "description":"a broad, open, public area near the center of a town or city" }}, {"code" : { "term":"S.STBL", "title":"stable", "description":"a building for the shelter and feeding of farm animals, especially horses" }}, {"code" : { "term":"S.STDM", "title":"stadium", "description":"a structure with an enclosure for athletic games with tiers of seats for spectators" }}, {"code" : { "term":"S.STNB", "title":"scientific research base", "description":"a scientific facility used as a base from which research is carried out or monitored" }}, {"code" : { "term":"S.STNC", "title":"coast guard station", "description":"a facility from which the coast is guarded by armed vessels" }}, {"code" : { "term":"S.STNE", "title":"experiment station", "description":"a facility for carrying out experiments" }}, {"code" : { "term":"S.STNF", "title":"forest station", "description":"a collection of buildings and facilities for carrying out forest management" }}, {"code" : { "term":"S.STNI", "title":"inspection station", "description":"a station at which vehicles, goods, and people are inspected" }}, {"code" : { "term":"S.STNM", "title":"meteorological station", "description":"a station at which weather elements are recorded" }}, {"code" : { "term":"S.STNR", "title":"radio station", "description":"a facility for producing and transmitting information by radio waves" }}, {"code" : { "term":"S.STNS", "title":"satellite station", "description":"a facility for tracking and communicating with orbiting satellites" }}, {"code" : { "term":"S.STNW", "title":"whaling station", "description":"a facility for butchering whales and processing train oil" }}, {"code" : { "term":"S.STPS", "title":"steps", "description":"stones or slabs placed for ease in ascending or descending a steep slope" }}, {"code" : { "term":"S.SWT", "title":"sewage treatment plant", "description":"facility for the processing of sewage and/or wastewater" }}, {"code" : { "term":"S.THTR", "title":"theater", "description":"a building, room, or outdoor structure for the presentation of plays, films, or other dramatic performances" }}, {"code" : { "term":"S.TMB", "title":"tomb(s)", "description":"a structure for interring bodies" }}, {"code" : { "term":"S.TMPL", "title":"temple(s)", "description":"an edifice dedicated to religious worship" }}, {"code" : { "term":"S.TNKD", "title":"cattle dipping tank", "description":"a small artificial pond used for immersing cattle in chemically treated water for disease control" }}, {"code" : { "term":"S.TOWR", "title":"tower", "description":"a high conspicuous structure, typically much higher than its diameter" }}, {"code" : { "term":"S.TRANT", "title":"transit terminal", "description":"facilities for the handling of vehicular freight and passengers" }}, {"code" : { "term":"S.TRIG", "title":"triangulation station", "description":"a point on the earth whose position has been determined by triangulation" }}, {"code" : { "term":"S.TRMO", "title":"oil pipeline terminal", "description":"a tank farm or loading facility at the end of an oil pipeline" }}, {"code" : { "term":"S.TWO", "title":"temp work office", "description":"temporary work offices" }}, {"code" : { "term":"S.UNIO", "title":"postgrad & mba", "description":"post universitary education institutes (post graduate studies and highly specialised master programs) & mba" }}, {"code" : { "term":"S.UNIP", "title":"university prep school", "description":"university preparation schools & institutions" }}, {"code" : { "term":"S.UNIV", "title":"university", "description":"an institution for higher learning with teaching and research facilities constituting a graduate school and professional schools that award master's degrees and doctorates and an undergraduate division that awards bachelor's degrees." }}, {"code" : { "term":"S.USGE", "title":"united states government establishment", "description":"a facility operated by the united states government in panama" }}, {"code" : { "term":"S.VETF", "title":"veterinary facility", "description":"a building or camp at which veterinary services are available" }}, {"code" : { "term":"S.WALL", "title":"wall", "description":"a thick masonry structure, usually enclosing a field or building, or forming the side of a structure" }}, {"code" : { "term":"S.WALLA", "title":"ancient wall", "description":"the remains of a linear defensive stone structure" }}, {"code" : { "term":"S.WEIR", "title":"weir(s)", "description":"a small dam in a stream, designed to raise the water level or to divert stream flow through a desired channel" }}, {"code" : { "term":"S.WHRF", "title":"wharf(-ves)", "description":"a structure of open rather than solid construction along a shore or a bank which provides berthing for ships and cargo-handling facilities" }}, {"code" : { "term":"S.WRCK", "title":"wreck", "description":"the site of the remains of a wrecked vessel" }}, {"code" : { "term":"S.WTRW", "title":"waterworks", "description":"a facility for supplying potable water through a water source and a system of pumps and filtration beds" }}, {"code" : { "term":"S.ZNF", "title":"free trade zone", "description":"an area, usually a section of a port, where goods may be received and shipped free of customs duty and of most customs regulations" }}, {"code" : { "term":"S.ZOO", "title":"zoo", "description":"a zoological garden or park where wild animals are kept for exhibition" }}, {"code" : { "term":"T.ASPH", "title":"asphalt lake", "description":"a small basin containing naturally occurring asphalt" }}, {"code" : { "term":"T.ATOL", "title":"atoll(s)", "description":"a ring-shaped coral reef which has closely spaced islands on it encircling a lagoon" }}, {"code" : { "term":"T.BAR", "title":"bar", "description":"a shallow ridge or mound of coarse unconsolidated material in a stream channel, at the mouth of a stream, estuary, or lagoon and in the wave-break zone along coasts" }}, {"code" : { "term":"T.BCH", "title":"beach", "description":"a shore zone of coarse unconsolidated sediment that extends from the low-water line to the highest reach of storm waves" }}, {"code" : { "term":"T.BCHS", "title":"beaches", "description":"a shore zone of coarse unconsolidated sediment that extends from the low-water line to the highest reach of storm waves" }}, {"code" : { "term":"T.BDLD", "title":"badlands", "description":"an area characterized by a maze of very closely spaced, deep, narrow, steep-sided ravines, and sharp crests and pinnacles" }}, {"code" : { "term":"T.BLDR", "title":"boulder field", "description":"a high altitude or high latitude bare, flat area covered with large angular rocks" }}, {"code" : { "term":"T.BLHL", "title":"blowhole(s)", "description":"a hole in coastal rock through which sea water is forced by a rising tide or waves and spurted through an outlet into the air" }}, {"code" : { "term":"T.BLOW", "title":"blowout(s)", "description":"a small depression in sandy terrain, caused by wind erosion" }}, {"code" : { "term":"T.BNCH", "title":"bench", "description":"a long, narrow bedrock platform bounded by steeper slopes above and below, usually overlooking a waterbody" }}, {"code" : { "term":"T.BUTE", "title":"butte(s)", "description":"a small, isolated, usually flat-topped hill with steep sides" }}, {"code" : { "term":"T.CAPE", "title":"cape", "description":"a land area, more prominent than a point, projecting into the sea and marking a notable change in coastal direction" }}, {"code" : { "term":"T.CFT", "title":"cleft(s)", "description":"a deep narrow slot, notch, or groove in a coastal cliff" }}, {"code" : { "term":"T.CLDA", "title":"caldera", "description":"a depression measuring kilometers across formed by the collapse of a volcanic mountain" }}, {"code" : { "term":"T.CLF", "title":"cliff(s)", "description":"a high, steep to perpendicular slope overlooking a waterbody or lower area" }}, {"code" : { "term":"T.CNYN", "title":"canyon", "description":"a deep, narrow valley with steep sides cutting into a plateau or mountainous area" }}, {"code" : { "term":"T.CONE", "title":"cone(s)", "description":"a conical landform composed of mud or volcanic material" }}, {"code" : { "term":"T.CRDR", "title":"corridor", "description":"a strip or area of land having significance as an access way" }}, {"code" : { "term":"T.CRQ", "title":"cirque", "description":"a bowl-like hollow partially surrounded by cliffs or steep slopes at the head of a glaciated valley" }}, {"code" : { "term":"T.CRQS", "title":"cirques", "description":"bowl-like hollows partially surrounded by cliffs or steep slopes at the head of a glaciated valley" }}, {"code" : { "term":"T.CRTR", "title":"crater(s)", "description":"a generally circular saucer or bowl-shaped depression caused by volcanic or meteorite explosive action" }}, {"code" : { "term":"T.CUET", "title":"cuesta(s)", "description":"an asymmetric ridge formed on tilted strata" }}, {"code" : { "term":"T.DLTA", "title":"delta", "description":"a flat plain formed by alluvial deposits at the mouth of a stream" }}, {"code" : { "term":"T.DPR", "title":"depression(s)", "description":"a low area surrounded by higher land and usually characterized by interior drainage" }}, {"code" : { "term":"T.DSRT", "title":"desert", "description":"a large area with little or no vegetation due to extreme environmental conditions" }}, {"code" : { "term":"T.DUNE", "title":"dune(s)", "description":"a wave form, ridge or star shape feature composed of sand" }}, {"code" : { "term":"T.DVD", "title":"divide", "description":"a line separating adjacent drainage basins" }}, {"code" : { "term":"T.ERG", "title":"sandy desert", "description":"an extensive tract of shifting sand and sand dunes" }}, {"code" : { "term":"T.FAN", "title":"fan(s)", "description":"a fan-shaped wedge of coarse alluvium with apex merging with a mountain stream bed and the fan spreading out at a low angle slope onto an adjacent plain" }}, {"code" : { "term":"T.FORD", "title":"ford", "description":"a shallow part of a stream which can be crossed on foot or by land vehicle" }}, {"code" : { "term":"T.FSR", "title":"fissure", "description":"a crack associated with volcanism" }}, {"code" : { "term":"T.GAP", "title":"gap", "description":"a low place in a ridge, not used for transportation" }}, {"code" : { "term":"T.GRGE", "title":"gorge(s)", "description":"a short, narrow, steep-sided section of a stream valley" }}, {"code" : { "term":"T.HDLD", "title":"headland", "description":"a high projection of land extending into a large body of water beyond the line of the coast" }}, {"code" : { "term":"T.HLL", "title":"hill", "description":"a rounded elevation of limited extent rising above the surrounding land with local relief of less than 300m" }}, {"code" : { "term":"T.HLLS", "title":"hills", "description":"rounded elevations of limited extent rising above the surrounding land with local relief of less than 300m" }}, {"code" : { "term":"T.HMCK", "title":"hammock(s)", "description":"a patch of ground, distinct from and slightly above the surrounding plain or wetland. often occurs in groups" }}, {"code" : { "term":"T.HMDA", "title":"rock desert", "description":"a relatively sand-free, high bedrock plateau in a hot desert, with or without a gravel veneer" }}, {"code" : { "term":"T.INTF", "title":"interfluve", "description":"a relatively undissected upland between adjacent stream valleys" }}, {"code" : { "term":"T.ISL", "title":"island", "description":"a tract of land, smaller than a continent, surrounded by water at high water" }}, {"code" : { "term":"T.ISLET", "title":"islet", "description":"small island, bigger than rock, smaller than island." }}, {"code" : { "term":"T.ISLF", "title":"artificial island", "description":"an island created by landfill or diking and filling in a wetland, bay, or lagoon" }}, {"code" : { "term":"T.ISLM", "title":"mangrove island", "description":"a mangrove swamp surrounded by a waterbody" }}, {"code" : { "term":"T.ISLS", "title":"islands", "description":"tracts of land, smaller than a continent, surrounded by water at high water" }}, {"code" : { "term":"T.ISLT", "title":"land-tied island", "description":"a coastal island connected to the mainland by barrier beaches, levees or dikes" }}, {"code" : { "term":"T.ISLX", "title":"section of island" }}, {"code" : { "term":"T.ISTH", "title":"isthmus", "description":"a narrow strip of land connecting two larger land masses and bordered by water" }}, {"code" : { "term":"T.KRST", "title":"karst area", "description":"a distinctive landscape developed on soluble rock such as limestone characterized by sinkholes, caves, disappearing streams, and underground drainage" }}, {"code" : { "term":"T.LAVA", "title":"lava area", "description":"an area of solidified lava" }}, {"code" : { "term":"T.LEV", "title":"levee", "description":"a natural low embankment bordering a distributary or meandering stream; often built up artificially to control floods" }}, {"code" : { "term":"T.MESA", "title":"mesa(s)", "description":"a flat-topped, isolated elevation with steep slopes on all sides, less extensive than a plateau" }}, {"code" : { "term":"T.MND", "title":"mound(s)", "description":"a low, isolated, rounded hill" }}, {"code" : { "term":"T.MRN", "title":"moraine", "description":"a mound, ridge, or other accumulation of glacial till" }}, {"code" : { "term":"T.MT", "title":"mountain", "description":"an elevation standing high above the surrounding area with small summit area, steep slopes and local relief of 300m or more" }}, {"code" : { "term":"T.MTS", "title":"mountains", "description":"a mountain range or a group of mountains or high ridges" }}, {"code" : { "term":"T.NKM", "title":"meander neck", "description":"a narrow strip of land between the two limbs of a meander loop at its narrowest point" }}, {"code" : { "term":"T.NTK", "title":"nunatak", "description":"a rock or mountain peak protruding through glacial ice" }}, {"code" : { "term":"T.NTKS", "title":"nunataks", "description":"rocks or mountain peaks protruding through glacial ice" }}, {"code" : { "term":"T.PAN", "title":"pan", "description":"a near-level shallow, natural depression or basin, usually containing an intermittent lake, pond, or pool" }}, {"code" : { "term":"T.PANS", "title":"pans", "description":"a near-level shallow, natural depression or basin, usually containing an intermittent lake, pond, or pool" }}, {"code" : { "term":"T.PASS", "title":"pass", "description":"a break in a mountain range or other high obstruction, used for transportation from one side to the other [see also gap]" }}, {"code" : { "term":"T.PEN", "title":"peninsula", "description":"an elongate area of land projecting into a body of water and nearly surrounded by water" }}, {"code" : { "term":"T.PENX", "title":"section of peninsula" }}, {"code" : { "term":"T.PK", "title":"peak", "description":"a pointed elevation atop a mountain, ridge, or other hypsographic feature" }}, {"code" : { "term":"T.PKS", "title":"peaks", "description":"pointed elevations atop a mountain, ridge, or other hypsographic features" }}, {"code" : { "term":"T.PLAT", "title":"plateau", "description":"an elevated plain with steep slopes on one or more sides, and often with incised streams" }}, {"code" : { "term":"T.PLATX", "title":"section of plateau" }}, {"code" : { "term":"T.PLDR", "title":"polder", "description":"an area reclaimed from the sea by diking and draining" }}, {"code" : { "term":"T.PLN", "title":"plain(s)", "description":"an extensive area of comparatively level to gently undulating land, lacking surface irregularities, and usually adjacent to a higher area" }}, {"code" : { "term":"T.PLNX", "title":"section of plain" }}, {"code" : { "term":"T.PROM", "title":"promontory(-ies)", "description":"a bluff or prominent hill overlooking or projecting into a lowland" }}, {"code" : { "term":"T.PT", "title":"point", "description":"a tapering piece of land projecting into a body of water, less prominent than a cape" }}, {"code" : { "term":"T.PTS", "title":"points", "description":"tapering pieces of land projecting into a body of water, less prominent than a cape" }}, {"code" : { "term":"T.RDGB", "title":"beach ridge", "description":"a ridge of sand just inland and parallel to the beach, usually in series" }}, {"code" : { "term":"T.RDGE", "title":"ridge(s)", "description":"a long narrow elevation with steep sides, and a more or less continuous crest" }}, {"code" : { "term":"T.REG", "title":"stony desert", "description":"a desert plain characterized by a surface veneer of gravel and stones" }}, {"code" : { "term":"T.RK", "title":"rock", "description":"a conspicuous, isolated rocky mass" }}, {"code" : { "term":"T.RKFL", "title":"rockfall", "description":"an irregular mass of fallen rock at the base of a cliff or steep slope" }}, {"code" : { "term":"T.RKS", "title":"rocks", "description":"conspicuous, isolated rocky masses" }}, {"code" : { "term":"T.SAND", "title":"sand area", "description":"a tract of land covered with sand" }}, {"code" : { "term":"T.SBED", "title":"dry stream bed", "description":"a channel formerly containing the water of a stream" }}, {"code" : { "term":"T.SCRP", "title":"escarpment", "description":"a long line of cliffs or steep slopes separating level surfaces above and below" }}, {"code" : { "term":"T.SDL", "title":"saddle", "description":"a broad, open pass crossing a ridge or between hills or mountains" }}, {"code" : { "term":"T.SHOR", "title":"shore", "description":"a narrow zone bordering a waterbody which covers and uncovers at high and low water, respectively" }}, {"code" : { "term":"T.SINK", "title":"sinkhole", "description":"a small crater-shape depression in a karst area" }}, {"code" : { "term":"T.SLID", "title":"slide", "description":"a mound of earth material, at the base of a slope and the associated scoured area" }}, {"code" : { "term":"T.SLP", "title":"slope(s)", "description":"a surface with a relatively uniform slope angle" }}, {"code" : { "term":"T.SPIT", "title":"spit", "description":"a narrow, straight or curved continuation of a beach into a waterbody" }}, {"code" : { "term":"T.SPUR", "title":"spur(s)", "description":"a subordinate ridge projecting outward from a hill, mountain or other elevation" }}, {"code" : { "term":"T.TAL", "title":"talus slope", "description":"a steep concave slope formed by an accumulation of loose rock fragments at the base of a cliff or steep slope" }}, {"code" : { "term":"T.TRGD", "title":"interdune trough(s)", "description":"a long wind-swept trough between parallel longitudinal dunes" }}, {"code" : { "term":"T.TRR", "title":"terrace", "description":"a long, narrow alluvial platform bounded by steeper slopes above and below, usually overlooking a waterbody" }}, {"code" : { "term":"T.UPLD", "title":"upland", "description":"an extensive interior region of high land with low to moderate surface relief" }}, {"code" : { "term":"T.VAL", "title":"valley", "description":"an elongated depression usually traversed by a stream" }}, {"code" : { "term":"T.VALG", "title":"hanging valley", "description":"a valley the floor of which is notably higher than the valley or shore to which it leads; most common in areas that have been glaciated" }}, {"code" : { "term":"T.VALS", "title":"valleys", "description":"elongated depressions usually traversed by a stream" }}, {"code" : { "term":"T.VALX", "title":"section of valley" }}, {"code" : { "term":"T.VLC", "title":"volcano", "description":"a conical elevation composed of volcanic materials with a crater at the top" }}, {"code" : { "term":"U.APNU", "title":"apron", "description":"a gentle slope, with a generally smooth surface, particularly found around groups of islands and seamounts" }}, {"code" : { "term":"U.ARCU", "title":"arch", "description":"a low bulge around the southeastern end of the island of hawaii" }}, {"code" : { "term":"U.ARRU", "title":"arrugado", "description":"an area of subdued corrugations off baja california" }}, {"code" : { "term":"U.BDLU", "title":"borderland", "description":"a region adjacent to a continent, normally occupied by or bordering a shelf, that is highly irregular with depths well in excess of those typical of a shelf" }}, {"code" : { "term":"U.BKSU", "title":"banks", "description":"elevations, typically located on a shelf, over which the depth of water is relatively shallow but sufficient for safe surface navigation" }}, {"code" : { "term":"U.BNCU", "title":"bench", "description":"a small terrace" }}, {"code" : { "term":"U.BNKU", "title":"bank", "description":"an elevation, typically located on a shelf, over which the depth of water is relatively shallow but sufficient for safe surface navigation" }}, {"code" : { "term":"U.BSNU", "title":"basin", "description":"a depression more or less equidimensional in plan and of variable extent" }}, {"code" : { "term":"U.CDAU", "title":"cordillera", "description":"an entire mountain system including the subordinate ranges, interior plateaus, and basins" }}, {"code" : { "term":"U.CNSU", "title":"canyons", "description":"relatively narrow, deep depressions with steep sides, the bottom of which generally has a continuous slope" }}, {"code" : { "term":"U.CNYU", "title":"canyon", "description":"a relatively narrow, deep depression with steep sides, the bottom of which generally has a continuous slope" }}, {"code" : { "term":"U.CRSU", "title":"continental rise", "description":"a gentle slope rising from oceanic depths towards the foot of a continental slope" }}, {"code" : { "term":"U.DEPU", "title":"deep", "description":"a localized deep area within the confines of a larger feature, such as a trough, basin or trench" }}, {"code" : { "term":"U.EDGU", "title":"shelf edge", "description":"a line along which there is a marked increase of slope at the outer margin of a continental shelf or island shelf" }}, {"code" : { "term":"U.ESCU", "title":"escarpment (or scarp)", "description":"an elongated and comparatively steep slope separating flat or gently sloping areas" }}, {"code" : { "term":"U.FANU", "title":"fan", "description":"a relatively smooth feature normally sloping away from the lower termination of a canyon or canyon system" }}, {"code" : { "term":"U.FLTU", "title":"flat", "description":"a small level or nearly level area" }}, {"code" : { "term":"U.FRKU", "title":"fork", "description":"a branch of a canyon or valley" }}, {"code" : { "term":"U.FRSU", "title":"forks", "description":"a branch of a canyon or valley" }}, {"code" : { "term":"U.FRZU", "title":"fracture zone", "description":"an extensive linear zone of irregular topography of the sea floor, characterized by steep-sided or asymmetrical ridges, troughs, or escarpments" }}, {"code" : { "term":"U.FURU", "title":"furrow", "description":"a closed, linear, narrow, shallow depression" }}, {"code" : { "term":"U.GAPU", "title":"gap", "description":"a narrow break in a ridge or rise" }}, {"code" : { "term":"U.GLYU", "title":"gully", "description":"a small valley-like feature" }}, {"code" : { "term":"U.HLLU", "title":"hill", "description":"an elevation rising generally less than 500 meters" }}, {"code" : { "term":"U.HLSU", "title":"hills", "description":"elevations rising generally less than 500 meters" }}, {"code" : { "term":"U.HOLU", "title":"hole", "description":"a small depression of the sea floor" }}, {"code" : { "term":"U.KNLU", "title":"knoll", "description":"an elevation rising generally more than 500 meters and less than 1,000 meters and of limited extent across the summit" }}, {"code" : { "term":"U.KNSU", "title":"knolls", "description":"elevations rising generally more than 500 meters and less than 1,000 meters and of limited extent across the summits" }}, {"code" : { "term":"U.LDGU", "title":"ledge", "description":"a rocky projection or outcrop, commonly linear and near shore" }}, {"code" : { "term":"U.LEVU", "title":"levee", "description":"an embankment bordering a canyon, valley, or seachannel" }}, {"code" : { "term":"U.MDVU", "title":"median valley", "description":"the axial depression of the mid-oceanic ridge system" }}, {"code" : { "term":"U.MESU", "title":"mesa", "description":"an isolated, extensive, flat-topped elevation on the shelf, with relatively steep sides" }}, {"code" : { "term":"U.MNDU", "title":"mound", "description":"a low, isolated, rounded hill" }}, {"code" : { "term":"U.MOTU", "title":"moat", "description":"an annular depression that may not be continuous, located at the base of many seamounts, islands, and other isolated elevations" }}, {"code" : { "term":"U.MTSU", "title":"mountains", "description":"well-delineated subdivisions of a large and complex positive feature" }}, {"code" : { "term":"U.MTU", "title":"mountain", "description":"a well-delineated subdivision of a large and complex positive feature" }}, {"code" : { "term":"U.PKSU", "title":"peaks", "description":"prominent elevations, part of a larger feature, either pointed or of very limited extent across the summit" }}, {"code" : { "term":"U.PKU", "title":"peak", "description":"a prominent elevation, part of a larger feature, either pointed or of very limited extent across the summit" }}, {"code" : { "term":"U.PLFU", "title":"platform", "description":"a flat or gently sloping underwater surface extending seaward from the shore" }}, {"code" : { "term":"U.PLNU", "title":"plain", "description":"a flat, gently sloping or nearly level region" }}, {"code" : { "term":"U.PLTU", "title":"plateau", "description":"a comparatively flat-topped feature of considerable extent, dropping off abruptly on one or more sides" }}, {"code" : { "term":"U.PNLU", "title":"pinnacle", "description":"a high tower or spire-shaped pillar of rock or coral, alone or cresting a summit" }}, {"code" : { "term":"U.PRVU", "title":"province", "description":"a region identifiable by a group of similar physiographic features whose characteristics are markedly in contrast with surrounding areas" }}, {"code" : { "term":"U.RAVU", "title":"ravine", "description":"a small canyon" }}, {"code" : { "term":"U.RDGU", "title":"ridge", "description":"a long narrow elevation with steep sides" }}, {"code" : { "term":"U.RDSU", "title":"ridges", "description":"long narrow elevations with steep sides" }}, {"code" : { "term":"U.RFSU", "title":"reefs", "description":"surface-navigation hazards composed of consolidated material" }}, {"code" : { "term":"U.RFU", "title":"reef", "description":"a surface-navigation hazard composed of consolidated material" }}, {"code" : { "term":"U.RISU", "title":"rise", "description":"a broad elevation that rises gently, and generally smoothly, from the sea floor" }}, {"code" : { "term":"U.RMPU", "title":"ramp", "description":"a gentle slope connecting areas of different elevations" }}, {"code" : { "term":"U.RNGU", "title":"range", "description":"a series of associated ridges or seamounts" }}, {"code" : { "term":"U.SCNU", "title":"seachannel", "description":"a continuously sloping, elongated depression commonly found in fans or plains and customarily bordered by levees on one or two sides" }}, {"code" : { "term":"U.SCSU", "title":"seachannels", "description":"continuously sloping, elongated depressions commonly found in fans or plains and customarily bordered by levees on one or two sides" }}, {"code" : { "term":"U.SDLU", "title":"saddle", "description":"a low part, resembling in shape a saddle, in a ridge or between contiguous seamounts" }}, {"code" : { "term":"U.SHFU", "title":"shelf", "description":"a zone adjacent to a continent (or around an island) that extends from the low water line to a depth at which there is usually a marked increase of slope towards oceanic depths" }}, {"code" : { "term":"U.SHLU", "title":"shoal", "description":"a surface-navigation hazard composed of unconsolidated material" }}, {"code" : { "term":"U.SHSU", "title":"shoals", "description":"hazards to surface navigation composed of unconsolidated material" }}, {"code" : { "term":"U.SHVU", "title":"shelf valley", "description":"a valley on the shelf, generally the shoreward extension of a canyon" }}, {"code" : { "term":"U.SILU", "title":"sill", "description":"the low part of a gap or saddle separating basins" }}, {"code" : { "term":"U.SLPU", "title":"slope", "description":"the slope seaward from the shelf edge to the beginning of a continental rise or the point where there is a general reduction in slope" }}, {"code" : { "term":"U.SMSU", "title":"seamounts", "description":"elevations rising generally more than 1,000 meters and of limited extent across the summit" }}, {"code" : { "term":"U.SMU", "title":"seamount", "description":"an elevation rising generally more than 1,000 meters and of limited extent across the summit" }}, {"code" : { "term":"U.SPRU", "title":"spur", "description":"a subordinate elevation, ridge, or rise projecting outward from a larger feature" }}, {"code" : { "term":"U.TERU", "title":"terrace", "description":"a relatively flat horizontal or gently inclined surface, sometimes long and narrow, which is bounded by a steeper ascending slope on one side and by a steep descending slope on the opposite side" }}, {"code" : { "term":"U.TMSU", "title":"tablemounts (or guyots)", "description":"seamounts having a comparatively smooth, flat top" }}, {"code" : { "term":"U.TMTU", "title":"tablemount (or guyot)", "description":"a seamount having a comparatively smooth, flat top" }}, {"code" : { "term":"U.TNGU", "title":"tongue", "description":"an elongate (tongue-like) extension of a flat sea floor into an adjacent higher feature" }}, {"code" : { "term":"U.TRGU", "title":"trough", "description":"a long depression of the sea floor characteristically flat bottomed and steep sided, and normally shallower than a trench" }}, {"code" : { "term":"U.TRNU", "title":"trench", "description":"a long, narrow, characteristically very deep and asymmetrical depression of the sea floor, with relatively steep sides" }}, {"code" : { "term":"U.VALU", "title":"valley", "description":"a relatively shallow, wide depression, the bottom of which usually has a continuous gradient" }}, {"code" : { "term":"U.VLSU", "title":"valleys", "description":"a relatively shallow, wide depression, the bottom of which usually has a continuous gradient" }}, {"code" : { "term":"V.BUSH", "title":"bush(es)", "description":"a small clump of conspicuous bushes in an otherwise bare area" }}, {"code" : { "term":"V.CULT", "title":"cultivated area", "description":"an area under cultivation" }}, {"code" : { "term":"V.FRST", "title":"forest(s)", "description":"an area dominated by tree vegetation" }}, {"code" : { "term":"V.FRSTF", "title":"fossilized forest", "description":"a forest fossilized by geologic processes and now exposed at the earth's surface" }}, {"code" : { "term":"V.GRSLD", "title":"grassland", "description":"an area dominated by grass vegetation" }}, {"code" : { "term":"V.GRVC", "title":"coconut grove", "description":"a planting of coconut trees" }}, {"code" : { "term":"V.GRVO", "title":"olive grove", "description":"a planting of olive trees" }}, {"code" : { "term":"V.GRVP", "title":"palm grove", "description":"a planting of palm trees" }}, {"code" : { "term":"V.GRVPN", "title":"pine grove", "description":"a planting of pine trees" }}, {"code" : { "term":"V.HTH", "title":"heath", "description":"an upland moor or sandy area dominated by low shrubby vegetation including heather" }}, {"code" : { "term":"V.MDW", "title":"meadow", "description":"a small, poorly drained area dominated by grassy vegetation" }}, {"code" : { "term":"V.OCH", "title":"orchard(s)", "description":"a planting of fruit or nut trees" }}, {"code" : { "term":"V.SCRB", "title":"scrubland", "description":"an area of low trees, bushes, and shrubs stunted by some environmental limitation" }}, {"code" : { "term":"V.TREE", "title":"tree(s)", "description":"a conspicuous tree used as a landmark" }}, {"code" : { "term":"V.TUND", "title":"tundra", "description":"a marshy, treeless, high latitude plain, dominated by mosses, lichens, and low shrub vegetation under permafrost conditions" }}, {"code" : { "term":"V.VIN", "title":"vineyard", "description":"a planting of grapevines" }}, {"code" : { "term":"V.VINS", "title":"vineyards", "description":"plantings of grapevines" }}, {"code" : { "term":"A.ADM1H", "title":"historical first-order administrative division" }}, {"code" : { "term":"A.ADM2H", "title":"historical second-order administrative division" }}, {"code" : { "term":"A.ADM3H", "title":"historical third-order administrative division" }}, {"code" : { "term":"A.ADM4H", "title":"historical fourth-order administrative division" }}, {"code" : { "term":"A.ADMH", "title":"historical administrative division" }}, {"code" : { "term":"A.PCLH", "title":"historical political entity" }}, {"code" : { "term":"A.PPCLH", "title":"historical capital of a political entity" }}, {"code" : { "term":"A.PPLH", "title":"historical populated place" }}, {"code" : { "term":"L.RGNH", "title":"historical region" }}, {"code" : { "term":"S.HMSD", "title":"homestead" }} ];
    iso3166 = [{"name":"Afghanistan","alpha2":"AF","country-code":"004"},{"name":"Åland Islands","alpha2":"AX","country-code":"248"},{"name":"Albania","alpha2":"AL","country-code":"008"},{"name":"Algeria","alpha2":"DZ","country-code":"012"},{"name":"American Samoa","alpha2":"AS","country-code":"016"},{"name":"Andorra","alpha2":"AD","country-code":"020"},{"name":"Angola","alpha2":"AO","country-code":"024"},{"name":"Anguilla","alpha2":"AI","country-code":"660"},{"name":"Antarctica","alpha2":"AQ","country-code":"010"},{"name":"Antigua and Barbuda","alpha2":"AG","country-code":"028"},{"name":"Argentina","alpha2":"AR","country-code":"032"},{"name":"Armenia","alpha2":"AM","country-code":"051"},{"name":"Aruba","alpha2":"AW","country-code":"533"},{"name":"Australia","alpha2":"AU","country-code":"036"},{"name":"Austria","alpha2":"AT","country-code":"040"},{"name":"Azerbaijan","alpha2":"AZ","country-code":"031"},{"name":"Bahamas","alpha2":"BS","country-code":"044"},{"name":"Bahrain","alpha2":"BH","country-code":"048"},{"name":"Bangladesh","alpha2":"BD","country-code":"050"},{"name":"Barbados","alpha2":"BB","country-code":"052"},{"name":"Belarus","alpha2":"BY","country-code":"112"},{"name":"Belgium","alpha2":"BE","country-code":"056"},{"name":"Belize","alpha2":"BZ","country-code":"084"},{"name":"Benin","alpha2":"BJ","country-code":"204"},{"name":"Bermuda","alpha2":"BM","country-code":"060"},{"name":"Bhutan","alpha2":"BT","country-code":"064"},{"name":"Bolivia, Plurinational State of","alpha2":"BO","country-code":"068"},{"name":"Bonaire, Sint Eustatius and Saba","alpha2":"BQ","country-code":"535"},{"name":"Bosnia and Herzegovina","alpha2":"BA","country-code":"070"},{"name":"Botswana","alpha2":"BW","country-code":"072"},{"name":"Bouvet Island","alpha2":"BV","country-code":"074"},{"name":"Brazil","alpha2":"BR","country-code":"076"},{"name":"British Indian Ocean Territory","alpha2":"IO","country-code":"086"},{"name":"Brunei Darussalam","alpha2":"BN","country-code":"096"},{"name":"Bulgaria","alpha2":"BG","country-code":"100"},{"name":"Burkina Faso","alpha2":"BF","country-code":"854"},{"name":"Burundi","alpha2":"BI","country-code":"108"},{"name":"Cambodia","alpha2":"KH","country-code":"116"},{"name":"Cameroon","alpha2":"CM","country-code":"120"},{"name":"Canada","alpha2":"CA","country-code":"124"},{"name":"Cape Verde","alpha2":"CV","country-code":"132"},{"name":"Cayman Islands","alpha2":"KY","country-code":"136"},{"name":"Central African Republic","alpha2":"CF","country-code":"140"},{"name":"Chad","alpha2":"TD","country-code":"148"},{"name":"Chile","alpha2":"CL","country-code":"152"},{"name":"China","alpha2":"CN","country-code":"156"},{"name":"Christmas Island","alpha2":"CX","country-code":"162"},{"name":"Cocos (Keeling) Islands","alpha2":"CC","country-code":"166"},{"name":"Colombia","alpha2":"CO","country-code":"170"},{"name":"Comoros","alpha2":"KM","country-code":"174"},{"name":"Congo","alpha2":"CG","country-code":"178"},{"name":"Congo, the Democratic Republic of the","alpha2":"CD","country-code":"180"},{"name":"Cook Islands","alpha2":"CK","country-code":"184"},{"name":"Costa Rica","alpha2":"CR","country-code":"188"},{"name":"Côte d'Ivoire","alpha2":"CI","country-code":"384"},{"name":"Croatia","alpha2":"HR","country-code":"191"},{"name":"Cuba","alpha2":"CU","country-code":"192"},{"name":"Curaçao","alpha2":"CW","country-code":"531"},{"name":"Cyprus","alpha2":"CY","country-code":"196"},{"name":"Czech Republic","alpha2":"CZ","country-code":"203"},{"name":"Denmark","alpha2":"DK","country-code":"208"},{"name":"Djibouti","alpha2":"DJ","country-code":"262"},{"name":"Dominica","alpha2":"DM","country-code":"212"},{"name":"Dominican Republic","alpha2":"DO","country-code":"214"},{"name":"Ecuador","alpha2":"EC","country-code":"218"},{"name":"Egypt","alpha2":"EG","country-code":"818"},{"name":"El Salvador","alpha2":"SV","country-code":"222"},{"name":"Equatorial Guinea","alpha2":"GQ","country-code":"226"},{"name":"Eritrea","alpha2":"ER","country-code":"232"},{"name":"Estonia","alpha2":"EE","country-code":"233"},{"name":"Ethiopia","alpha2":"ET","country-code":"231"},{"name":"Falkland Islands (Malvinas)","alpha2":"FK","country-code":"238"},{"name":"Faroe Islands","alpha2":"FO","country-code":"234"},{"name":"Fiji","alpha2":"FJ","country-code":"242"},{"name":"Finland","alpha2":"FI","country-code":"246"},{"name":"France","alpha2":"FR","country-code":"250"},{"name":"French Guiana","alpha2":"GF","country-code":"254"},{"name":"French Polynesia","alpha2":"PF","country-code":"258"},{"name":"French Southern Territories","alpha2":"TF","country-code":"260"},{"name":"Gabon","alpha2":"GA","country-code":"266"},{"name":"Gambia","alpha2":"GM","country-code":"270"},{"name":"Georgia","alpha2":"GE","country-code":"268"},{"name":"Germany","alpha2":"DE","country-code":"276"},{"name":"Ghana","alpha2":"GH","country-code":"288"},{"name":"Gibraltar","alpha2":"GI","country-code":"292"},{"name":"Greece","alpha2":"GR","country-code":"300"},{"name":"Greenland","alpha2":"GL","country-code":"304"},{"name":"Grenada","alpha2":"GD","country-code":"308"},{"name":"Guadeloupe","alpha2":"GP","country-code":"312"},{"name":"Guam","alpha2":"GU","country-code":"316"},{"name":"Guatemala","alpha2":"GT","country-code":"320"},{"name":"Guernsey","alpha2":"GG","country-code":"831"},{"name":"Guinea","alpha2":"GN","country-code":"324"},{"name":"Guinea-Bissau","alpha2":"GW","country-code":"624"},{"name":"Guyana","alpha2":"GY","country-code":"328"},{"name":"Haiti","alpha2":"HT","country-code":"332"},{"name":"Heard Island and McDonald Islands","alpha2":"HM","country-code":"334"},{"name":"Holy See (Vatican City State)","alpha2":"VA","country-code":"336"},{"name":"Honduras","alpha2":"HN","country-code":"340"},{"name":"Hong Kong","alpha2":"HK","country-code":"344"},{"name":"Hungary","alpha2":"HU","country-code":"348"},{"name":"Iceland","alpha2":"IS","country-code":"352"},{"name":"India","alpha2":"IN","country-code":"356"},{"name":"Indonesia","alpha2":"ID","country-code":"360"},{"name":"Iran, Islamic Republic of","alpha2":"IR","country-code":"364"},{"name":"Iraq","alpha2":"IQ","country-code":"368"},{"name":"Ireland","alpha2":"IE","country-code":"372"},{"name":"Isle of Man","alpha2":"IM","country-code":"833"},{"name":"Israel","alpha2":"IL","country-code":"376"},{"name":"Italy","alpha2":"IT","country-code":"380"},{"name":"Jamaica","alpha2":"JM","country-code":"388"},{"name":"Japan","alpha2":"JP","country-code":"392"},{"name":"Jersey","alpha2":"JE","country-code":"832"},{"name":"Jordan","alpha2":"JO","country-code":"400"},{"name":"Kazakhstan","alpha2":"KZ","country-code":"398"},{"name":"Kenya","alpha2":"KE","country-code":"404"},{"name":"Kiribati","alpha2":"KI","country-code":"296"},{"name":"Korea, Democratic People's Republic of","alpha2":"KP","country-code":"408"},{"name":"Korea, Republic of","alpha2":"KR","country-code":"410"},{"name":"Kuwait","alpha2":"KW","country-code":"414"},{"name":"Kyrgyzstan","alpha2":"KG","country-code":"417"},{"name":"Lao People's Democratic Republic","alpha2":"LA","country-code":"418"},{"name":"Latvia","alpha2":"LV","country-code":"428"},{"name":"Lebanon","alpha2":"LB","country-code":"422"},{"name":"Lesotho","alpha2":"LS","country-code":"426"},{"name":"Liberia","alpha2":"LR","country-code":"430"},{"name":"Libya","alpha2":"LY","country-code":"434"},{"name":"Liechtenstein","alpha2":"LI","country-code":"438"},{"name":"Lithuania","alpha2":"LT","country-code":"440"},{"name":"Luxembourg","alpha2":"LU","country-code":"442"},{"name":"Macao","alpha2":"MO","country-code":"446"},{"name":"Macedonia, the former Yugoslav Republic of","alpha2":"MK","country-code":"807"},{"name":"Madagascar","alpha2":"MG","country-code":"450"},{"name":"Malawi","alpha2":"MW","country-code":"454"},{"name":"Malaysia","alpha2":"MY","country-code":"458"},{"name":"Maldives","alpha2":"MV","country-code":"462"},{"name":"Mali","alpha2":"ML","country-code":"466"},{"name":"Malta","alpha2":"MT","country-code":"470"},{"name":"Marshall Islands","alpha2":"MH","country-code":"584"},{"name":"Martinique","alpha2":"MQ","country-code":"474"},{"name":"Mauritania","alpha2":"MR","country-code":"478"},{"name":"Mauritius","alpha2":"MU","country-code":"480"},{"name":"Mayotte","alpha2":"YT","country-code":"175"},{"name":"Mexico","alpha2":"MX","country-code":"484"},{"name":"Micronesia, Federated States of","alpha2":"FM","country-code":"583"},{"name":"Moldova, Republic of","alpha2":"MD","country-code":"498"},{"name":"Monaco","alpha2":"MC","country-code":"492"},{"name":"Mongolia","alpha2":"MN","country-code":"496"},{"name":"Montenegro","alpha2":"ME","country-code":"499"},{"name":"Montserrat","alpha2":"MS","country-code":"500"},{"name":"Morocco","alpha2":"MA","country-code":"504"},{"name":"Mozambique","alpha2":"MZ","country-code":"508"},{"name":"Myanmar","alpha2":"MM","country-code":"104"},{"name":"Namibia","alpha2":"NA","country-code":"516"},{"name":"Nauru","alpha2":"NR","country-code":"520"},{"name":"Nepal","alpha2":"NP","country-code":"524"},{"name":"Netherlands","alpha2":"NL","country-code":"528"},{"name":"New Caledonia","alpha2":"NC","country-code":"540"},{"name":"New Zealand","alpha2":"NZ","country-code":"554"},{"name":"Nicaragua","alpha2":"NI","country-code":"558"},{"name":"Niger","alpha2":"NE","country-code":"562"},{"name":"Nigeria","alpha2":"NG","country-code":"566"},{"name":"Niue","alpha2":"NU","country-code":"570"},{"name":"Norfolk Island","alpha2":"NF","country-code":"574"},{"name":"Northern Mariana Islands","alpha2":"MP","country-code":"580"},{"name":"Norway","alpha2":"NO","country-code":"578"},{"name":"Oman","alpha2":"OM","country-code":"512"},{"name":"Pakistan","alpha2":"PK","country-code":"586"},{"name":"Palau","alpha2":"PW","country-code":"585"},{"name":"Palestinian Territory, Occupied","alpha2":"PS","country-code":"275"},{"name":"Panama","alpha2":"PA","country-code":"591"},{"name":"Papua New Guinea","alpha2":"PG","country-code":"598"},{"name":"Paraguay","alpha2":"PY","country-code":"600"},{"name":"Peru","alpha2":"PE","country-code":"604"},{"name":"Philippines","alpha2":"PH","country-code":"608"},{"name":"Pitcairn","alpha2":"PN","country-code":"612"},{"name":"Poland","alpha2":"PL","country-code":"616"},{"name":"Portugal","alpha2":"PT","country-code":"620"},{"name":"Puerto Rico","alpha2":"PR","country-code":"630"},{"name":"Qatar","alpha2":"QA","country-code":"634"},{"name":"Réunion","alpha2":"RE","country-code":"638"},{"name":"Romania","alpha2":"RO","country-code":"642"},{"name":"Russian Federation","alpha2":"RU","country-code":"643"},{"name":"Rwanda","alpha2":"RW","country-code":"646"},{"name":"Saint Barthélemy","alpha2":"BL","country-code":"652"},{"name":"Saint Helena, Ascension and Tristan da Cunha","alpha2":"SH","country-code":"654"},{"name":"Saint Kitts and Nevis","alpha2":"KN","country-code":"659"},{"name":"Saint Lucia","alpha2":"LC","country-code":"662"},{"name":"Saint Martin (French part)","alpha2":"MF","country-code":"663"},{"name":"Saint Pierre and Miquelon","alpha2":"PM","country-code":"666"},{"name":"Saint Vincent and the Grenadines","alpha2":"VC","country-code":"670"},{"name":"Samoa","alpha2":"WS","country-code":"882"},{"name":"San Marino","alpha2":"SM","country-code":"674"},{"name":"Sao Tome and Principe","alpha2":"ST","country-code":"678"},{"name":"Saudi Arabia","alpha2":"SA","country-code":"682"},{"name":"Senegal","alpha2":"SN","country-code":"686"},{"name":"Serbia","alpha2":"RS","country-code":"688"},{"name":"Seychelles","alpha2":"SC","country-code":"690"},{"name":"Sierra Leone","alpha2":"SL","country-code":"694"},{"name":"Singapore","alpha2":"SG","country-code":"702"},{"name":"Sint Maarten (Dutch part)","alpha2":"SX","country-code":"534"},{"name":"Slovakia","alpha2":"SK","country-code":"703"},{"name":"Slovenia","alpha2":"SI","country-code":"705"},{"name":"Solomon Islands","alpha2":"SB","country-code":"090"},{"name":"Somalia","alpha2":"SO","country-code":"706"},{"name":"South Africa","alpha2":"ZA","country-code":"710"},{"name":"South Georgia and the South Sandwich Islands","alpha2":"GS","country-code":"239"},{"name":"South Sudan","alpha2":"SS","country-code":"728"},{"name":"Spain","alpha2":"ES","country-code":"724"},{"name":"Sri Lanka","alpha2":"LK","country-code":"144"},{"name":"Sudan","alpha2":"SD","country-code":"729"},{"name":"Suriname","alpha2":"SR","country-code":"740"},{"name":"Svalbard and Jan Mayen","alpha2":"SJ","country-code":"744"},{"name":"Swaziland","alpha2":"SZ","country-code":"748"},{"name":"Sweden","alpha2":"SE","country-code":"752"},{"name":"Switzerland","alpha2":"CH","country-code":"756"},{"name":"Syrian Arab Republic","alpha2":"SY","country-code":"760"},{"name":"Taiwan, Province of China","alpha2":"TW","country-code":"158"},{"name":"Tajikistan","alpha2":"TJ","country-code":"762"},{"name":"Tanzania, United Republic of","alpha2":"TZ","country-code":"834"},{"name":"Thailand","alpha2":"TH","country-code":"764"},{"name":"Timor-Leste","alpha2":"TL","country-code":"626"},{"name":"Togo","alpha2":"TG","country-code":"768"},{"name":"Tokelau","alpha2":"TK","country-code":"772"},{"name":"Tonga","alpha2":"TO","country-code":"776"},{"name":"Trinidad and Tobago","alpha2":"TT","country-code":"780"},{"name":"Tunisia","alpha2":"TN","country-code":"788"},{"name":"Turkey","alpha2":"TR","country-code":"792"},{"name":"Turkmenistan","alpha2":"TM","country-code":"795"},{"name":"Turks and Caicos Islands","alpha2":"TC","country-code":"796"},{"name":"Tuvalu","alpha2":"TV","country-code":"798"},{"name":"Uganda","alpha2":"UG","country-code":"800"},{"name":"Ukraine","alpha2":"UA","country-code":"804"},{"name":"United Arab Emirates","alpha2":"AE","country-code":"784"},{"name":"United Kingdom","alpha2":"GB","country-code":"826"},{"name":"United States","alpha2":"US","country-code":"840"},{"name":"United States Minor Outlying Islands","alpha2":"UM","country-code":"581"},{"name":"Uruguay","alpha2":"UY","country-code":"858"},{"name":"Uzbekistan","alpha2":"UZ","country-code":"860"},{"name":"Vanuatu","alpha2":"VU","country-code":"548"},{"name":"Venezuela, Bolivarian Republic of","alpha2":"VE","country-code":"862"},{"name":"Viet Nam","alpha2":"VN","country-code":"704"},{"name":"Virgin Islands, British","alpha2":"VG","country-code":"092"},{"name":"Virgin Islands, U.S.","alpha2":"VI","country-code":"850"},{"name":"Wallis and Futuna","alpha2":"WF","country-code":"876"},{"name":"Western Sahara","alpha2":"EH","country-code":"732"},{"name":"Yemen","alpha2":"YE","country-code":"887"},{"name":"Zambia","alpha2":"ZM","country-code":"894"},{"name":"Zimbabwe","alpha2":"ZW","country-code":"716"}];
    return {
        name: 'GeoNames Features',
        type: 'place',
        dataType: 'xml',        
        toDataUri: function(uri) {
            var levels = uri.split('/');
            datauri = 'http://sws.geonames.org/' + levels[3] + '/about.rdf';
            return datauri;
        },
        corsEnabled: true,
        parseData: function(xml) {
            var name = $(xml).find('gn\\:name, name').text();
            name = typeof name === 'undefined'? 'unnamed' : name;

            var latlon = new Array();
            var y = $(xml).find('wgs84_pos\\:lat, lat').text();
            var x = $(xml).find('wgs84_pos\\:long, long').text();
            y = typeof y === 'undefined'? '0.0' : y;
            x = typeof x === 'undefined'? '0.0' : x;
            latlon[0] = y;
            latlon[1] = x;

            var codeuri = $(xml).find('gn\\:featureCode, featureCode').attr('rdf:resource');
            codeuri = typeof codeuri === 'undefined'? '' : codeuri;
            var term = ''
            if (codeuri != '') {
                var code = codeuri.substr(codeuri.indexOf('#')+1);
                term = gncodes.filter(function (x) {
                    return x.code.term === code;
                })[0].code.title;
            }

            var countrycode = $(xml).find('gn\\:countryCode, countryCode').text();
            countrycode = typeof countrycode === 'undefined'? '' : countrycode;
            var countryname = '';
            if (countrycode != '') {
                countryname = iso3166.filter(function (x) {
                    return x.alpha2 === countrycode;
                })[0].name;
            }

            var wikiuri = $(xml).find('gn\\:wikipediaArticle, wikipediaArticle').attr('rdf:resource');
            wikiuri = typeof wikiuri === 'undefined'? '' : wikiuri;

            var description = 'A place described in the GeoNames gazetteer: ' + term + ". "
            if (countryname != '') {
                description = description + "Located in the modern country of " + countryname + "."
            }
            if (wikiuri != '') {
                description = description + '<br /><br/><a href="' + wikiuri + '">See also Wikipedia</a>.';
            }

            return {
                name: name,
                description: description,
                latlon: latlon,
            };
        },
    };
});

// Module: Perseus: Smith's "Dictionary of Greek and Roman biography and mythology"

define('modules/loc/lccn',['jquery'], function($) {
    return {
        name: 'Library of Congress Online Catalog',
        type: 'citation',
        dataType: 'xml',
        toDataUri: function(uri) { 
            return uri + '/dc';
        },
        // get values from the returned XML
        parseData: function(xml) {
            var getText = awld.accessor(xml),
                title = getText('title'),
                author = getText('creator');
            return {
                name: '"' + title + '" by ' + author,
                description: getText('description')
            };
        }
    };
});
// Module: Nomisma.org API

define('modules/nomisma/nomisma',['jquery'], function($) {
    return {
        name: 'Nomisma.org Entities',
        dataType: 'xml',
        // data URI is the same
        corsEnabled: true,
        parseData: function(xml) {
            var getText = awld.accessor(xml);


            var name = getText('[property="skos:prefLabel"]');
            name = typeof name === 'undefined' ? getText('[about]','about') : name;

            var description = getText('[property="skos:definition"]');
            description = typeof description === 'undefined' ? '' : description;

            // try getting latlon as property
            var latlon = getText('[property="gml:pos"]');
            // test if that worked, if not try as @content of @property = "findspot"
            if ( typeof latlon === 'undefined' ) { latlon = getText('[property="findspot"]','content') };
            // if stil undefined '', otherwise split
            latlon = typeof latlon === 'undefined' ? '' : latlon.split(' ');


            var related = getText('[rel*="skos:related"]', 'href')
            related = typeof related === 'undefined'? '' : related;

            return {
                name: name,
                description: description,
                latlon: latlon,
                related: related,
            };
        },
        getType: function(xml) {
            var map = {
                    'roman_emperor': 'person',
                    'ruler': 'person',
                    'authority': 'person',
                    'nomisma_region': 'place',
                    'hoard': 'place',
                    'mint': 'place',
                    'material': 'object',
                    'type_series_item': 'object',
                },
                type = $('[typeof]', xml).first().attr('typeof');
            if (type) return map[type];
        }
    };
});

// Module: OpenContext HTML

define('modules/numismatics.org/numismatics.org',['jquery'], function($) {
    return {
        name: 'American Numismatic Society Object',
        dataType: 'xml',
        type: 'object',
        toDataUri: function(uri) {
            return uri + '.xml';
        },
        parseData: function(xml) {
            var getText = awld.accessor(xml);
            var imageURI = getText('[USE = "thumbnail"] *','xlink:href');
            var description = typeof imageURI === 'undefined' ? '<i>No image available.</i>' : '<img style="max-width:100px" src="'+imageURI[0]+'"/><img style="max-width:100px" src="'+imageURI[1]+'"/>';
            return {
                name: "ANS " + getText('title'),
                description: description,
        };
    },
 }
});

// Module: OpenContext HTML

define('modules/opencontext/opencontext',['jquery'], function($) {
    return {
        name: 'Open Context Resource',
        dataType: 'xml',
        type: 'object',
        toDataUri: function(uri) {
            return uri;
        },
        parseData: function(xml) {
            var getText = awld.accessor(xml);
            var imageURI = getText('[id = "all_media"] img', 'src');
            imageURI = typeof imageURI === 'string'? imageURI : imageURI[0];
            return {
                name: "OpenContext " + getText('[id = "item_name"]'),
                description: getText('[id = "item_class"]'),
                imageURI: imageURI,
            };
        },
    };
});

// Module: Papyri.info HTML

define('modules/papyri.info/text',['jquery'], function($) {
    return {
        name: 'Papyri.info Text',
        dataType: 'html',
        type: 'text',
        corsEnabled: true,
        toDataUri: function(uri) {
            return uri;
        },
        parseData: function(html) {
            var getText = awld.accessor(html);
            var h3Arr = getText('h3');
            var mdtitle = getText('.mdtitle');
            return {
                name: h3Arr[0] + "- " + mdtitle[0],
                description: getText('#edition')
            };
        },
    };
});

// Module: Pleiades places

define('modules/pelagios.dme.ait.ac.at/place',[],function() {
    return {
        name: 'Pelagios Places',
        type: 'place',
        toDataUri: function(uri) {
            var pleiadesID = uri.match(/[0-9]+$/);
            return 'http://pleiades.stoa.org/places/'+ pleiadesID + '/json';
        },
        corsEnabled: true,
        // add name to data
        parseData: function(data) {
            data.name = data.title;
            data.latlon = data.reprPoint && data.reprPoint.reverse();
            data.description = data.description;
            return data;
        }
    };
});

// Module: Perseus: Smith's "Dictionary of Greek and Roman biography and mythology"

define('modules/perseus/smith',['jquery'], function($) {
    return {
        name: 'Perseus: References in Smith\'s "Greek and Roman biography and mythology"',
        type: 'person',
        dataType: 'xml',
        // data format determined through content negotiation
        corsEnabled: true,
        // get values from the returned XML
        parseData: function(xml) {
            var getText = awld.accessor(xml),
                names = getText('head persName');
            var name = typeof names === 'string'? names : names.join(', or ');

            return {
                name: name ,
                description: getText('p')
            };
        }
    };
});

// Module: Perseus: Smith's "Dictionary of Greek and Roman biography and mythology"

define('modules/perseus/urn-cts',['jquery'], function($) {
    return {
        name: 'Perseus: Canonical Text Service',
        type: 'text',
        dataType: 'xml',
        // data format determined through content negotiation
        corsEnabled: true,
        // get values from the returned XML
        parseData: function(xml) {
            var getText = awld.accessor(xml);
            return {
                name: 'Text from Perseus',
                description: getText('body')
            };
        }
    };
});

// Module: Pleiades places

define('modules/pleiades/place',[],function() {
    return {
        name: 'Pleiades Places',
        type: 'place',
        toDataUri: function(uri) {
            return uri + '/json';
        },
        corsEnabled: true,
        // add name to data
        parseData: function(data) {
            data.name = data.title;
            data.latlon = data.reprPoint && data.reprPoint.reverse();
            data.description = 'A place described in the Pleiades gazetteer: ' + data.description + " <br/><a href='http://pelagios.dme.ait.ac.at/api/places/http%3A%2F%2Fpleiades.stoa.org%2Fplaces%2F"+data.id+"'>Further information at Pelagios</a>";
            return data;
        }
    };
});

// Module: Trismegistos HTML

define('modules/trismegistos/text',['jquery'], function($) {
    return {
        name: 'Trismegistos Text',
        dataType: 'html',
        type: 'text',
        toDataUri: function(uri) {
            return uri;
        },
        parseData: function(html) {
            var getText = awld.accessor(html);
            return {
                name: getText('h1'),
                description: 'Provenance: ' +getText('td:contains(Provenance:) + td ') +'<br/><br/>Date: ' + getText('td:contains(Date:) + td '),
            };
        },
    };
});

// Module: Wikipedia page

define('modules/wikipedia/page',[],function() {
    return {
        name: 'Wikipedia Pages',
        dataType: 'jsonp',
        // not entirely happy with this, but it looks hard to reference specific elements
        toDataUri: function(uri) {
            var pageId = uri.split('/').pop();
            return 'http://en.wikipedia.org/w/api.php?format=json&action=parse&page=' + pageId + '&callback=?';
        },
        parseData: function(data) {
            data = data && data.parse || {};
            var $content = $('<div>' + data.text['*'] + '</div>');

            var description = $('p', $content).first().html();
            description = description.replace(/href="\//g,'href="http://en.wikipedia.org/')

            var imageURI = $('.image img',$content);
            imageURI = typeof imageURI.first()[0] === 'object' ? imageURI = 'http:'+imageURI.first()[0].getAttribute('src') : ''; 

            return {
                name: data.title,
                description: description,
                imageURI: imageURI,
            };
        }
    };
});

// Module: Pleiades places

define('modules/worldcat/oclc',[],function() {
    return {
        name: 'Worldcat Records',
        type: 'citation',
        noFetch: true
    };
});
// Module: SMB HTML

define('modules/www.smb.museum/www.smb.museum',['jquery'], function($) {
    return {
        name: 'Münzkabinett Berlin',
        dataType: 'html',
        type: 'object',
        parseData: function(html) {
            var getText = awld.accessor(html);

            var name = getText('[id = "objektInfo"] h3');
            if (typeof name === 'undefined') { name = '' };

            var imageURI = getText('[id = "ansichtOben"] img', 'src');
            imageURI = typeof imageURI === 'string'? imageURI : imageURI[0];
            imageURI = 'http://www.smb.museum/ikmk/'+imageURI;

            return {
                name: "Münzkabinett Berlin: " + name,
                // description: getText('[id = "item_class"]'),
                imageURI: imageURI,
            };
        },
    };
});

// Module: SUDOC RDF 
// @author: adapted from code by Régis Robineau

define('modules/www.sudoc.fr/www.sudoc.fr',['jquery'], function($) {
    return {
        name: 'Notices Sudoc',
        dataType: 'xml',
        type: 'citation',
        corsEnabled: true,
        toDataUri: function(uri) {
            return uri + '.rdf';
        },
        // get values from the returned XML
        parseData: function(xml) {
            var $xml = $(xml);
            // jQuery 1.7's namespace support is broken, but this works here
            var name = $xml.find('title')[0].textContent;
            if (typeof name === 'undefined') { name = '' }; // be defensive

            var description = $xml.find('date')[0].textContent;
            description = typeof description === 'undefined' ? '' : 'Date: ' + description;
            
            return {
                name: name,
                description: description,
            };
            
        }
    };
});


define("awld", function(){});
}());
