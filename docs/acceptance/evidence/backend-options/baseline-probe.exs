Code.compiler_options(ignore_module_conflict: true)

for path <- [
      "apps/gaoxy/lib/gaoxy/config.ex",
      "apps/gaoxy/lib/gaoxy/service.ex",
      "apps/gaoxy/lib/gaoxy/activation.ex"
    ] do
  {source, 0} = System.cmd("git", ["show", "946e850472e9c6e95c3f8914a65b58531c852287:" <> path])
  Code.compile_string(source, path)
end

files =
  Path.wildcard("apps/gaoxy/test/*_test.exs") -- ["apps/gaoxy/test/backend_options_test.exs"]

Mix.Task.run("test", ["--no-compile", "--seed", "153674" | files])
