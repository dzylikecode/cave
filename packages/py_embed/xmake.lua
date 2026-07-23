set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

add_requires("python 3.8.10", {configs = {shared = true}})

target("interface")
  set_kind("phony")
  add_packages("python")
  after_build(function(target)
    local outputdir = path.join(os.projectdir(), "dist")
    local pkg = target:pkg("python")
    if pkg then
      local installdir = pkg:installdir()
      local includedir = path.join(outputdir, "include")
      os.mkdir(includedir)
      -- os.cp(path.join(installdir, "include", "**"), includedir)
      os.cp(path.join(installdir, "include", "**.h"), includedir, {rootdir = path.join(installdir, "include")})
    end
  end)

target("minimal")
  set_kind("binary")
  add_files("example/minimal.cpp")
  add_packages("python")

---------------------------------------------------------
--- Examples
---------------------------------------------------------
for _, file in ipairs(os.files("example/*.cpp")) do
    local name = path.basename(file)
    target(name)
      set_kind("binary")
      add_files(file)
      add_packages("python")
end
