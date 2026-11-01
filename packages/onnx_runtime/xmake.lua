set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})
local kind = get_config("kind") or "static"
add_repositories("local-repo xmake_repo")
add_requires("onnxruntime 1.22.0", {system = false, configs = {shared = kind == "shared", merge_static = kind == "static", gpu = false}})

-- Export the same headers used by the runtime for binding generation.
target("api_export")
    set_kind("phony")
    add_packages("onnxruntime")
    after_build(function(target)
        local outputdir = path.join(os.projectdir(), "dist/include")
        os.mkdir(outputdir)
        os.cp(path.join(target:pkg("onnxruntime"):installdir(), "include/**"), outputdir)
    end)

-- Export the completed package library, independently of the C example.
target("onnxruntime_dart")
    set_kind("phony")
    add_packages("onnxruntime")
    on_install(function(target)
        local pkgdir = target:pkg("onnxruntime"):installdir()
        local windows = target:is_plat("windows", "mingw")
        local directory = kind == "shared" and windows and "bin" or "lib"
        local pattern
        if kind == "static" then
            pattern = target:is_plat("windows") and "lib/onnxruntime.lib" or "lib/libonnxruntime.a"
        elseif windows then
            pattern = "bin/*.dll"
        elseif target:is_plat("macosx", "iphoneos") then
            pattern = "lib/*.dylib"
        else
            pattern = "lib/*.so*"
        end
        local libraries = os.files(path.join(pkgdir, pattern))
        assert(#libraries > 0, "ONNX Runtime package contains no matching library: " .. pattern)
        local destination = path.join(target:installdir(), directory)
        os.mkdir(destination)
        for _, library in ipairs(libraries) do
            os.vcp(library, destination)
        end
    end)

target("minimal")
    set_kind("binary")
    add_files("example/minimal.c")
    add_packages("onnxruntime")
