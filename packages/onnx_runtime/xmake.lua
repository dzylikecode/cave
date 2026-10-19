set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})
add_requires("onnxruntime 1.22.0", {system = false, configs = {shared = true, gpu = false}})

-- Export the same headers used by the runtime for binding generation.
target("api_export")
    set_kind("phony")
    add_packages("onnxruntime")
    after_build(function(target)
        local outputdir = path.join(os.projectdir(), "dist/include")
        os.mkdir(outputdir)
        os.cp(path.join(target:pkg("onnxruntime"):installdir(), "include/**"), outputdir)
    end)

-- XmakeLibrary installs this target and its shared package dependencies.
target("minimal")
    set_kind("binary")
    add_files("example/minimal.c")
    add_packages("onnxruntime")
