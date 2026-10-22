#!/usr/bin/env elixir
# Prepare standalone package sources; never resolve dependencies or publish.
Mix.start()
Mix.env(:prod)

defmodule StageHexPackages do
  @repository "https://github.com/gsmlg-dev/gaoxy"
  @packages [
    {"gaoxy_websock_adapter", :websock_adapter, "vendor/websock_adapter"},
    {"gaoxy", :gaoxy, "apps/gaoxy"},
    {"gaoxy_http", :gaoxy_http, "apps/gaoxy_http"},
    {"gaoxy_http3", :gaoxy_http3, "apps/gaoxy_http3"},
    {"gaoxy_proxy", :gaoxy_proxy, "apps/gaoxy_proxy"},
    {"gaoxy_test", :gaoxy_test, "apps/gaoxy_test"}
  ]
  @descriptions %{
    gaoxy: "Elixir/OTP transport runtime for embedded and standalone services",
    gaoxy_http: "Native HTTP/1, HTTP/2, Plug and Phoenix adapters for Gaoxy",
    gaoxy_http3: "Native HTTP/3 service for Gaoxy",
    gaoxy_proxy: "HTTP and WebSocket proxy services for Gaoxy",
    gaoxy_test: "Real HTTP test fixtures with expectations and reliable ExUnit verification",
    websock_adapter: "Gaoxy distribution of WebSockAdapter with native HTTP/2 and HTTP/3 support"
  }
  @git_dependencies %{
    hell:
      {"https://github.com/gsmlg-dev/hell.git", "59eed42b019ca41413d1b8cd7a7dc3e344bb93ee",
       "0.1.2"}
  }

  def run(source, output) do
    source = Path.expand(source)
    output = Path.expand(output)
    root = Mix.Project.in_project(:gaoxy_package_source, source, fn _ -> Mix.Project.config() end)
    version = Keyword.fetch!(root, :version)
    {:ok, _} = Version.parse(version)
    licenses = get_in(root, [:package, :licenses])

    unless is_list(licenses) and licenses != [] and Enum.all?(licenses, &is_binary/1) do
      raise "root project must explicitly select package licenses"
    end

    license = File.read!(Path.join(source, "LICENSE"))

    # Read and validate all source projects before creating output.
    packages =
      for {name, app, relative} <- @packages do
        path = Path.join(source, relative)

        {config, application} =
          Mix.Project.in_project(app, path, fn project ->
            {Mix.Project.config(), project.application()}
          end)

        unless config[:app] == app and (app == :websock_adapter or config[:version] == version) do
          raise "source application/version mismatch: #{path}"
        end

        deps = Enum.map(config[:deps], &dependency(&1, version, app))
        readme_file = if app == :websock_adapter, do: "README.gaoxy.md", else: "README.md"
        readme = File.read!(Path.join(path, readme_file))
        {name, app, path, config, application, deps, readme}
      end

    if File.exists?(output) and File.ls!(output) != [] do
      raise "output directory must be empty: #{output}"
    end

    File.mkdir_p!(output)

    for {name, app, path, config, application, deps, readme} <- packages do
      destination = Path.join(output, name)
      File.mkdir!(destination)

      for directory <- ["lib", "priv"], File.dir?(Path.join(path, directory)) do
        File.cp_r!(Path.join(path, directory), Path.join(destination, directory))
      end

      package_licenses =
        if app == :websock_adapter do
          for file <- [
                "LICENSE",
                "CHANGELOG.md",
                "GAOXY.md",
                "SOURCE.json",
                "gaoxy.patch"
              ] do
            File.cp!(Path.join(path, file), Path.join(destination, file))
          end

          File.cp!(Path.join(path, "README.md"), Path.join(destination, "README.upstream.md"))
          File.write!(Path.join(destination, "LICENSE.gaoxy"), license)
          Enum.uniq(config[:package][:licenses] ++ licenses)
        else
          File.write!(Path.join(destination, "LICENSE"), license)
          licenses
        end

      File.write!(Path.join(destination, "README.md"), readme)
      files = Enum.sort(["mix.exs" | File.ls!(destination)])
      links = %{"GitHub" => @repository}

      links =
        if app == :websock_adapter,
          do: Map.put(links, "Upstream", config[:source_url]),
          else: links

      project =
        Keyword.take(config, [:app, :elixir, :start_permanent]) ++
          [
            version: version,
            description: Map.fetch!(@descriptions, app),
            source_url: @repository,
            package: [name: name, licenses: package_licenses, links: links, files: files],
            deps: deps
          ]

      module = "GaoxyHexPackages.#{Macro.camelize(name)}.MixProject"

      manifest = """
      defmodule #{module} do
        use Mix.Project
        def project, do: #{inspect(project, limit: :infinity)}
        def application, do: #{inspect(application, limit: :infinity)}
      end
      """

      File.write!(
        Path.join(destination, "mix.exs"),
        [Code.format_string!(manifest), "\n"]
      )

      IO.puts("Staged #{name} #{version}")
    end
  end

  defp dependency({app, requirement}, version, package_app) when is_binary(requirement),
    do: dependency({app, requirement, []}, version, package_app)

  defp dependency({app, options}, version, package_app) when is_list(options),
    do: dependency({app, nil, options}, version, package_app)

  defp dependency({app, requirement, options} = original, version, package_app) do
    cond do
      Map.has_key?(@git_dependencies, app) and options[:git] ->
        {url, ref, published} = Map.fetch!(@git_dependencies, app)

        if Map.new(options) != %{git: url, ref: ref}, do: unsupported!(original)
        {app, "== #{published}"}

      package_app == :gaoxy_test and app == :gaoxy_http3 and options == [in_umbrella: true] ->
        {app, "== #{version}", optional: true}

      app in [:gaoxy, :gaoxy_http, :gaoxy_http3, :gaoxy_proxy, :gaoxy_test] and
          options == [in_umbrella: true] ->
        {app, "== #{version}"}

      app == :websock_adapter and
          Map.new(options) == %{path: "../../vendor/websock_adapter", override: true} ->
        {app, "== #{version}", hex: :gaoxy_websock_adapter}

      Enum.any?([:git, :github, :path, :in_umbrella, :override], &Keyword.has_key?(options, &1)) ->
        unsupported!(original)

      is_binary(requirement) ->
        if options == [], do: {app, requirement}, else: {app, requirement, options}

      true ->
        unsupported!(original)
    end
  end

  defp unsupported!(dependency), do: raise("unsupported dependency: #{inspect(dependency)}")
end

case System.argv() do
  [source, output] -> StageHexPackages.run(source, output)
  _ -> raise "usage: elixir scripts/stage-hex-packages.exs SOURCE_ROOT OUTPUT_DIRECTORY"
end
