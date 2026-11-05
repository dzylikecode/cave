set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

local kind = get_config("kind") or "static"
add_repositories("local-repo xmake_repo")
add_requires("bgfx 9392", {
  system = false,
  configs = {
    shared = kind == "shared",
    dart_static_sections = kind == "static",
    export_c_api = kind == "static",
    merge_static = kind == "static"
  }
})

set_languages("c++20")
---------------------------------------------------------
--- Export: download bgfx and copy to dist/
---------------------------------------------------------
target("api_export")
  set_kind("phony")
  add_packages("bgfx")
  after_build(function(target)
    local outputdir = path.join(os.projectdir(), "dist/include")
    os.mkdir(outputdir)
    local pkg = target:pkg("bgfx")
    if pkg then
      local installdir = pkg:installdir()
      os.cp(path.join(installdir, "include/**"), outputdir)
    end
  end)

-- The local package recipe builds the library; this target only exports it.
target("bgfx_dart")
  set_kind("phony")
  add_packages("bgfx")
  on_install(function(target)
    local pkgdir = target:pkg("bgfx"):installdir()
    local windows = target:is_plat("windows", "mingw")
    local directory = "lib"
    local suffix = is_mode("debug") and "Debug" or "Release"
    local pattern
    if kind == "static" then
      pattern = target:is_plat("windows") and ("lib/bgfx" .. suffix .. ".lib") or ("lib/libbgfx" .. suffix .. ".a")
    elseif windows then
      pattern = "lib/*.dll"
    elseif target:is_plat("macosx", "iphoneos") then
      pattern = "lib/*.dylib"
    else
      pattern = "lib/*.so*"
    end
    local libraries = os.files(path.join(pkgdir, pattern))
    assert(#libraries > 0, "bgfx package contains no matching library: " .. pattern)
    local destination = path.join(target:installdir(), directory)
    os.mkdir(destination)
    for _, library in ipairs(libraries) do
      local name
      if kind == "static" then
        name = target:is_plat("windows") and "bgfx.lib" or "libbgfx.a"
      elseif windows then
        name = "bgfx.dll"
      elseif target:is_plat("macosx", "iphoneos") then
        name = "libbgfx.dylib"
      else
        name = "libbgfx.so"
      end
      os.vcp(library, path.join(destination, name))
    end
  end)

