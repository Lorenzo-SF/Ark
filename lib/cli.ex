# defmodule Ark.CLI do
#   @moduledoc """
#   Command-line interface for Ark global development tools framework.

#   Provides access to system tools, Git, Docker, SSH, packages, weather, and HTTP operations.
#   """

#   @doc """
#   Main entry point for Ark CLI commands.
#   """
#   def main(argv) do
#     argv
#     |> parse_args()
#     |> process_args()
#   end

#   defp parse_args(argv) do
#     case OptionParser.parse(argv,
#            strict: [
#              layout: :string,
#              weather: :boolean,
#              network: :boolean,
#              no_weather: :boolean,
#              no_network: :boolean,
#              repos: :string,
#              workspace: :string,
#              packages: :string,
#              no_preupdate: :boolean,
#              url: :string,
#              data: :string
#            ],
#            aliases: [
#              l: :layout,
#              u: :url
#            ]
#          ) do
#       {opts, args, _errors} ->
#         {opts, args}
#     end
#   end

#   defp process_args({opts, args}) do
#     command = List.first(args)
#     subcommand = Enum.at(args, 1)

#     process_command({command, subcommand}, opts, args)
#   end

#   defp process_command({"system-info", _}, opts, _args) do
#     system_info_command(opts)
#   end

#   defp process_command({"git", subcommand}, opts, _args) do
#     handle_git_commands(subcommand, opts)
#   end

#   defp process_command({"docker", subcommand}, _opts, _args) do
#     handle_docker_commands(subcommand)
#   end

#   defp process_command({"ssh", subcommand}, _opts, _args) do
#     handle_ssh_commands(subcommand)
#   end

#   defp process_command({"packages", "install"}, opts, _args) do
#     packages_install_command(opts)
#   end

#   defp process_command({"weather", _}, opts, _args) do
#     weather_command(opts)
#   end

#   defp process_command({"http", subcommand}, opts, _args) do
#     handle_http_commands(subcommand, opts)
#   end

#   defp process_command({"exec", _}, _opts, args) do
#     exec_command(args)
#   end

#   defp process_command({"parallel", _}, _opts, args) do
#     parallel_command(args)
#   end

#   defp process_command({"success", _}, _opts, args) do
#     success_command(args)
#   end

#   defp process_command({"error", _}, _opts, args) do
#     error_command(args)
#   end

#   defp process_command({"warning", _}, _opts, args) do
#     warning_command(args)
#   end

#   defp process_command({"info", _}, _opts, args) do
#     info_command(args)
#   end

#   defp process_command({nil, _}, _opts, _args) do
#     show_help()
#   end

#   defp process_command(_, _opts, _args) do
#     show_help()
#   end

#   defp handle_git_commands("setup", _opts), do: git_setup_command()
#   defp handle_git_commands("user-info", _opts), do: git_user_info_command()
#   defp handle_git_commands("clone", opts), do: git_clone_command(opts)
#   defp handle_git_commands("sync", opts), do: git_sync_command(opts)
#   defp handle_git_commands(_, _opts), do: show_help()

#   defp handle_docker_commands("start"), do: docker_start_command()
#   defp handle_docker_commands("stop"), do: docker_stop_command()
#   defp handle_docker_commands("status"), do: docker_status_command()
#   defp handle_docker_commands(_), do: show_help()

#   defp handle_ssh_commands("setup"), do: ssh_setup_command()
#   defp handle_ssh_commands("list-keys"), do: ssh_list_keys_command()
#   defp handle_ssh_commands(_), do: show_help()

#   defp handle_http_commands("get", opts), do: http_get_command(opts)
#   defp handle_http_commands("post", opts), do: http_post_command(opts)
#   defp handle_http_commands("with-auth", opts), do: http_with_auth_command(opts)
#   defp handle_http_commands(_, _), do: show_help()

#   # System info command
#   defp system_info_command(opts) do
#     layout = (opts[:layout] && String.to_atom(opts[:layout])) || :full

#     include_weather = determine_weather_flag(opts)
#     include_network = determine_network_flag(opts)

#     Ark.system_info(layout: layout, weather: include_weather, network: include_network)
#   end

#   defp determine_weather_flag(opts) do
#     case {opts[:weather], opts[:no_weather]} do
#       {nil, true} -> false
#       {true, _} -> true
#       {nil, nil} -> true
#       _ -> opts[:weather]
#     end
#   end

#   defp determine_network_flag(opts) do
#     case {opts[:network], opts[:no_network]} do
#       {nil, true} -> false
#       {true, _} -> true
#       {nil, nil} -> true
#       _ -> opts[:network]
#     end
#   end

#   # Git setup command
#   defp git_setup_command do
#     Ark.setup_git()
#   end

#   # Git user info command
#   defp git_user_info_command do
#     user_info = Ark.git_user_info()
#     IO.puts("#{inspect(user_info)}")
#   end

#   # Git clone command
#   defp git_clone_command(opts) do
#     repos_str = opts[:repos]
#     workspace_path = opts[:workspace]

#     if repos_str && workspace_path do
#       repos =
#         repos_str
#         |> String.split(",")
#         |> Enum.map(fn repo_url ->
#           %{
#             repo: %{url: repo_url, path: Path.join(workspace_path, Path.basename(repo_url, ".git"))}
#           }
#         end)

#       Ark.clone_repos(repos, workspace_path)
#     else
#       IO.puts("Error: Missing repos or workspace for git clone command")
#       show_help()
#     end
#   end

#   # Git sync command
#   defp git_sync_command(opts) do
#     repos_str = opts[:repos]

#     if repos_str do
#       repos =
#         repos_str
#         |> String.split(",")
#         |> Enum.map(fn repo_path ->
#           # Default to main, could be configurable
#           %{path: repo_path, main_branch: "main"}
#         end)

#       Ark.sync_repos(repos)
#     else
#       IO.puts("Error: Missing repos for git sync command")
#       show_help()
#     end
#   end

#   # Docker start command
#   defp docker_start_command do
#     result = Ark.docker_start()
#     IO.puts(inspect(result))
#   end

#   # Docker stop command
#   defp docker_stop_command do
#     result = Ark.docker_stop()
#     IO.puts(inspect(result))
#   end

#   # Docker status command
#   defp docker_status_command do
#     result = Ark.docker_status()
#     IO.puts("#{inspect(result)}")
#   end

#   # SSH setup command
#   defp ssh_setup_command do
#     Ark.setup_ssh()
#   end

#   # SSH list keys command
#   defp ssh_list_keys_command do
#     keys = Ark.list_ssh_keys()
#     Enum.each(keys, &IO.puts/1)
#   end

#   # Packages install command
#   defp packages_install_command(opts) do
#     packages_str = opts[:packages]
#     preupdate = !opts[:no_preupdate]

#     if packages_str do
#       packages = String.split(packages_str, ",") |> Enum.map(&String.trim/1)
#       Ark.install_packages(packages, preupdate)
#     else
#       IO.puts("Error: Missing packages for install command")
#       show_help()
#     end
#   end

#   # Weather command
#   defp weather_command(opts) do
#     url = opts[:url]
#     result = Ark.weather_today(url)
#     IO.puts("#{inspect(result)}")
#   end

#   # HTTP GET command
#   defp http_get_command(opts) do
#     url = opts[:url]

#     if url do
#       result = Ark.http_call(url: url, method: :get)

#       case result do
#         {:ok, status_code, body} ->
#           IO.puts("Status: #{status_code}")
#           IO.puts("Response: #{inspect(body)}")

#         {:error, error} ->
#           IO.puts("Error: #{inspect(error)}")
#       end
#     else
#       IO.puts("Error: Missing URL for http get command")
#       show_help()
#     end
#   end

#   # HTTP POST command
#   defp http_post_command(opts) do
#     url = opts[:url]
#     data_str = opts[:data]

#     if url && data_str do
#       # Try to parse data as JSON if possible
#       data =
#         case Jason.decode(data_str) do
#           {:ok, parsed} -> parsed
#           {:error, _} -> data_str
#         end

#       result = Ark.http_call(url: url, method: :post, params: data)

#       case result do
#         {:ok, status_code, body} ->
#           IO.puts("Status: #{status_code}")
#           IO.puts("Response: #{inspect(body)}")

#         {:error, error} ->
#           IO.puts("Error: #{inspect(error)}")
#       end
#     else
#       IO.puts("Error: Missing URL or data for http post command")
#       show_help()
#     end
#   end

#   # HTTP with auth command
#   defp http_with_auth_command(opts) do
#     url = opts[:url]

#     if url do
#       result = Ark.http_call_with_auth(url: url, method: :get)

#       case result do
#         {:ok, status_code, body} ->
#           IO.puts("Status: #{status_code}")
#           IO.puts("Response: #{inspect(body)}")

#         {:error, error} ->
#           IO.puts("Error: #{inspect(error)}")
#       end
#     else
#       IO.puts("Error: Missing URL for http with-auth command")
#       show_help()
#     end
#   end

#   # Exec command (delegating to Argos)
#   defp exec_command(args) do
#     command = Enum.join(Enum.slice(args, 1..-1//1), " ")

#     if command != "" do
#       result = Ark.exec_command(command)

#       if result.success? do
#         IO.puts(result.output)
#         System.halt(0)
#       else
#         IO.puts(result.output)
#         IO.puts("Error: #{result.exit_code}")
#         System.halt(result.exit_code)
#       end
#     else
#       IO.puts("Error: Missing command for exec")
#       show_help()
#     end
#   end

#   # Parallel command (delegating to Argos)
#   defp parallel_command(args) do
#     # Parse task arguments from the command line
#     # For now, we'll implement a simple version
#     case args do
#       ["parallel" | task_args] ->
#         tasks =
#           task_args
#           |> Enum.map(fn task_arg ->
#             [name, cmd] = String.split(task_arg, ":", parts: 2)
#             {name, cmd}
#           end)

#         if length(tasks) > 0 do
#           result = Ark.run_parallel(tasks)
#           IO.puts("#{inspect(result)}")
#         else
#           IO.puts("Error: No tasks specified for parallel execution")
#           show_help()
#         end

#       _ ->
#         IO.puts("Error: Invalid parallel command format")
#         show_help()
#     end
#   end

#   # Success message (delegating to Aegis through Ark)
#   defp success_command(args) do
#     message = Enum.join(Enum.slice(args, 1..-1//1), " ")

#     if message != "" do
#       Ark.success(message)
#     else
#       IO.puts("Error: Missing message for success command")
#       show_help()
#     end
#   end

#   # Error message (delegating to Aegis through Ark)
#   defp error_command(args) do
#     message = Enum.join(Enum.slice(args, 1..-1//1), " ")

#     if message != "" do
#       Ark.error(message)
#     else
#       IO.puts("Error: Missing message for error command")
#       show_help()
#     end
#   end

#   # Warning message (delegating to Aegis through Ark)
#   defp warning_command(args) do
#     message = Enum.join(Enum.slice(args, 1..-1//1), " ")

#     if message != "" do
#       Ark.warning(message)
#     else
#       IO.puts("Error: Missing message for warning command")
#       show_help()
#     end
#   end

#   # Info message (delegating to Aegis through Ark)
#   defp info_command(args) do
#     message = Enum.join(Enum.slice(args, 1..-1//1), " ")

#     if message != "" do
#       Ark.info(message)
#     else
#       IO.puts("Error: Missing message for info command")
#       show_help()
#     end
#   end

#   defp show_help do
#     help_text = """
#     Ark CLI - Global development tools framework

#     Usage:
#       ark [COMMAND] [SUBCOMMAND] [OPTIONS] [ARGUMENTS]

#     Commands:
#       system-info          Show system information (MOTD)
#                           Usage: ark system-info --layout full --no-weather

#       git setup            Configure Git
#                           Usage: ark git setup

#       git user-info        Show Git user information
#                           Usage: ark git user-info

#       git clone            Clone repositories
#                           Usage: ark git clone --repos "url1,url2" --workspace "/path"

#       git sync             Synchronize repositories
#                           Usage: ark git sync --repos "/path1,/path2"

#       docker start         Start Docker containers
#                           Usage: ark docker start

#       docker stop          Stop Docker containers
#                           Usage: ark docker stop

#       docker status        Check Docker status
#                           Usage: ark docker status

#       ssh setup            Create SSH keys
#                           Usage: ark ssh setup

#       ssh list-keys        List SSH keys
#                           Usage: ark ssh list-keys

#       packages install     Install system packages
#                           Usage: ark packages install --packages "git,docker,curl" --no-preupdate

#       weather              Get weather information
#                           Usage: ark weather --url "weather_service_url"

#       http get             Make HTTP GET request
#                           Usage: ark http get --url "https://api.example.com/data"

#       http post            Make HTTP POST request
#                           Usage: ark http post --url "https://api.example.com/data" --data '{"key": "value"}'

#       http with-auth       Make HTTP request with authentication
#                           Usage: ark http with-auth --url "https://api.example.com/protected"

#       exec                 Execute system command
#                           Usage: ark exec "ls -la"

#       parallel             Run tasks in parallel
#                           Usage: ark parallel "task1:command1" "task2:command2"

#       success              Show success message
#                           Usage: ark success "Operation completed"

#       error                Show error message
#                           Usage: ark error "An error occurred"

#       warning              Show warning message
#                           Usage: ark warning "Warning message"

#       info                 Show info message
#                           Usage: ark info "Information message"

#     Options:
#       -l, --layout LAYOUT      Layout for system-info (full, compact) (default: full)
#           --weather            Include weather in system-info (default: true)
#           --no-weather         Exclude weather from system-info
#           --network            Include network info in system-info (default: true)
#           --no-network         Exclude network info from system-info
#           --repos REPOS        Comma-separated list of repositories
#           --workspace PATH     Workspace path for git operations
#           --packages PKGS      Comma-separated list of packages to install
#           --no-preupdate       Skip updating package cache before installation
#       -u, --url URL           URL for HTTP requests
#           --data DATA         JSON data for POST requests
#     """

#     IO.puts(help_text)
#   end
# end
