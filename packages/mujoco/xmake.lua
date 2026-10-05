set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

add_requires("mujoco 3.12.0", {system = false, configs = {shared = true}})

set_languages("c++20")
---------------------------------------------------------
--- Export: download mujoco and copy to dist/
---------------------------------------------------------
target("api_export")
  set_kind("phony")
  add_packages("mujoco")
  after_build(function(target)
    local outputdir = path.join(os.projectdir(), "dist/include")
    os.mkdir(outputdir)
    local pkg = target:pkg("mujoco")
    if pkg then
      local installdir = pkg:installdir()
      os.cp(path.join(installdir, "include/**"), outputdir)
    end
  end)

for _, file in ipairs(os.files("example/*.cpp")) do
    local name = path.basename(file)
    target(name)
      set_kind("binary")
      add_files(file)
      add_packages("mujoco")
end
