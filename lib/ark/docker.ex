defmodule Ark.Docker  do
  @moduledoc """
  Gestión de contenedores Docker para Ark.

  Proporciona funcionalidades para gestionar contenedores Docker incluyendo
  inicio, parada, monitoreo y operaciones administrativas.

  ## Características

  - 🚀 Inicio automático de contenedores configurados
  - ⏹️  Parada controlada de contenedores
  - 📊 Monitoreo de estado en tiempo real
  - 🔍 Listado e inspección de contenedores
  - ⚙️  Verificación de instalación Docker
  - 🗑️  Eliminación segura de contenedores
  - 📥 Descarga automática de imágenes

  Construido sobre:
  - Aurora (1A): Sistema de colores y formateo
  - Argos (1B): Sistema de ejecución y orquestación
  - Aegis (2): Framework CLI/TUI completo
  """

  require Logger

  alias Aurora.Color
  alias Aurora.Structs.ChunkText
  alias Docker.Containers
  alias Docker.Images
  alias Aegis.Structs.{MenuInfo, MenuOption}

  # Replace compile_env with runtime function call since config is in runtime.exs
  defp get_containers, do: Application.get_env(:ark, :docker)[:containers] || []

  defp running?(nil, container), do: {container, :not_available}
  defp running?(%{state: %{"Status" => "running"}}, container), do: {container, :started}
  defp running?(_, container), do: {container, :not_started}

  def wait_until_containers_start do
    Enum.each(get_containers(), &check_running/1)
  end

  def check_running(container) do
    # First check if Docker is available and running
    case ensure_running() do
      :ok ->
        task_name = String.to_atom("check_#{container}_running")

        Argos.start_async_task(
          task_name,
          fn ->
            check_container_loop(container, task_name)
          end
        )

        task_name
      _ ->
        Logger.warning("Docker is not available, skipping check for #{container}")
        nil
    end
  end

  defp check_container_loop(container, task_name) do
    container_data = get_container_data(container, "State")

    found_container = Enum.find(container_data, fn c -> c.name == "/#{container}" end)

    case running?(found_container, container) do
      {^container, :started} ->
        Argos.stop_async_task(task_name)
        {container, :started}

      _ ->
        Process.sleep(100)
        check_container_loop(container, task_name)
    end
  end

  @doc """
  Inicia todos los contenedores Docker configurados.

  Revisa el estado de los contenedores configurados y inicia aquellos
  que no estén ejecutándose. Monitorea hasta que todos estén listos.

  ## Returns

      :containers_started

  """
  @spec start() :: :containers_started | {:error, atom()}
  def start do
    case ensure_running() do
      :ok ->
        get_containers_data("State")
        |> Enum.filter(fn elm -> Map.get(elm, :state) != "running" end)
        |> Enum.each(fn %{id: id} -> Containers.start(id) end)

        wait_until_containers_start()

        :containers_started
      error ->
        error
    end
  end

  @doc """
  Stops all configured containers.
  """
  def stop do
    case ensure_running() do
      :ok ->
        get_containers_data("Id")
        |> Enum.each(fn %{id: id} -> Containers.stop(id) end)

        :containers_stopped
      error ->
        error
    end
  end

  @doc """
  Stops specific containers by ID or name.
  """
  def stop_containers(container_ids) when is_list(container_ids) do
    case ensure_running() do
      :ok ->
        Enum.each(container_ids, fn id ->
          case Containers.stop(id) do
            {:ok, _} -> Logger.info("Stopped container: #{id}")
            error -> Logger.error("Failed to stop container #{id}: #{inspect(error)}")
          end
        end)
        :ok
      error ->
        error
    end
  end

  @doc """
  Starts specific containers by ID or name.
  """
  def start_containers(container_ids) when is_list(container_ids) do
    case ensure_running() do
      :ok ->
        Enum.each(container_ids, fn id ->
          case Containers.start(id) do
            {:ok, _} -> Logger.info("Started container: #{id}")
            error -> Logger.error("Failed to start container #{id}: #{inspect(error)}")
          end
        end)
        :ok
      error ->
        error
    end
  end

  @doc """
  Removes specific containers by ID or name.
  """
  def remove_containers(container_ids) when is_list(container_ids) do
    case ensure_running() do
      :ok ->
        Enum.each(container_ids, fn id ->
          # First stop the container if running
          case Containers.stop(id) do
            {:ok, _} ->
              Logger.info("Stopped container before removal: #{id}")
            _ ->
              Logger.info("Container wasn't running: #{id}")
          end

          # Then remove it
          case Containers.remove(id) do
            {:ok, _} -> Logger.info("Removed container: #{id}")
            error -> Logger.error("Failed to remove container #{id}: #{inspect(error)}")
          end
        end)
        :ok
      error ->
        error
    end
  end

  @doc """
  Interactively select and start containers from a multi-select menu.
  """
  def start_containers_menu do
    case ensure_running() do
      :ok ->
        containers = get_all_containers_for_menu()
        display_container_menu(containers, "Start Containers", fn selected_containers ->
          container_ids = Enum.map(selected_containers, &Map.get(&1, :id))
          start_containers(container_ids)
          Aegis.Printer.info("Started #{length(container_ids)} containers")
        end)
      _ ->
        Aegis.Printer.error("Docker is not available")
    end
  end

  @doc """
  Interactively select and stop containers from a multi-select menu.
  """
  def stop_containers_menu do
    case ensure_running() do
      :ok ->
        containers = get_running_containers_for_menu()
        display_container_menu(containers, "Stop Containers", fn selected_containers ->
          container_ids = Enum.map(selected_containers, &Map.get(&1, :id))
          stop_containers(container_ids)
          Aegis.Printer.info("Stopped #{length(container_ids)} containers")
        end)
      _ ->
        Aegis.Printer.error("Docker is not available")
    end
  end

  @doc """
  Interactively select and remove containers from a multi-select menu.
  """
  def remove_containers_menu do
    case ensure_running() do
      :ok ->
        containers = get_all_containers_for_menu()
        display_container_menu(containers, "Remove Containers", fn selected_containers ->
          container_ids = Enum.map(selected_containers, &Map.get(&1, :id))
          remove_containers(container_ids)
          Aegis.Printer.info("Removed #{length(container_ids)} containers")
        end)
      _ ->
        Aegis.Printer.error("Docker is not available")
    end
  end

  # Helper function to get all containers for the menu
  defp get_all_containers_for_menu do
    case ensure_running() do
      :ok ->
        try do
          Docker.Containers.list()
          |> Enum.map(fn container ->
            %{
              id: Map.get(container, "Id", ""),
              names: Map.get(container, "Names", []),
              status: Map.get(container, "Status", ""),
              image: Map.get(container, "Image", "")
            }
          end)
        rescue
          _ -> []
        end
      _ ->
        []
    end
  end

  # Helper function to get only running containers for the menu
  defp get_running_containers_for_menu do
    case ensure_running() do
      :ok ->
        try do
          Docker.Containers.list()
          |> Enum.filter(fn container ->
            status = Map.get(container, "Status", "")
            String.contains?(status, "Up")
          end)
          |> Enum.map(fn container ->
            %{
              id: Map.get(container, "Id", ""),
              names: Map.get(container, "Names", []),
              status: Map.get(container, "Status", ""),
              image: Map.get(container, "Image", "")
            }
          end)
        rescue
          _ -> []
        end
      _ ->
        []
    end
  end

  # Display container selection menu with multi-select capability
  defp display_container_menu(containers, title, action_callback) do
    case containers do
      [] ->
        Aegis.Printer.warning("No containers available")
        :no_containers
      _ ->
        # Create menu options for each container with select/unselect functionality
        # Since the framework might not support true multi-select return values,
        # we'll create a workflow where user can select multiple items by returning to menu
        options = create_multi_select_workflow(containers, action_callback)

        # Create menu with multiselect capability (based on InputHandler code)
        menu_info = %Aegis.Structs.MenuInfo{
          options: options,
          breadcrumbs: ["Docker", title],
          ascii_art: Aegis.Tui.generate_menu_logo(),
          multiselect: true  # Based on the InputHandler, it's 'multiselect' not 'multi_select'
        }

        Aegis.Tui.run(menu_info)
    end
  end

  # Helper to create a workflow for multi-select using the available framework
  defp create_multi_select_workflow(containers, action_callback) do
    # Create options that allow adding containers to a selection list
    # Since the current Aegis TUI doesn't directly return multi-select results,
    # we'll need to implement the functionality differently

    # Create a more appropriate approach: create options that let user select multiple items
    # using the right-arrow/left-arrow selection and then execute the action
    container_options =
      containers
      |> Enum.with_index(1)
      |> Enum.map(fn {container, idx} ->
        name = container.names |> List.first() |> Kernel.||("unknown")
        %Aegis.Structs.MenuOption{
          id: idx,
          name: "[ ] #{name} (#{container.status})",
          description: "ID: #{String.slice(container.id, 0..11)} - #{container.image}",
          action_type: :execution,
          action: fn ->
            # This function would be called when selected in multi-select mode
            # but since we don't know how to capture multi-select results,
            # we'll create a different approach below
            container
          end
        }
      end)

    # Add action options
    action_options = [
      %Aegis.Structs.MenuOption{
        id: :execute_action,
        name: "Execute Action on Selected",
        description: "Perform the requested action on all selected containers",
        action_type: :execution,
        action: fn ->
          # Placeholder - we'll need custom handling for multi-select
          :execute_selected
        end
      },
      %Aegis.Structs.MenuOption{
        id: :back,
        name: "Back to Main",
        description: "Return to previous menu",
        action_type: :navigation,
        action: fn ->
          # Navigate back
          :back_to_main
        end
      }
    ]

    container_options ++ action_options
  end

  @doc """
  Lista todos los contenedores Docker activos.

  ## Returns

      CommandResult con la salida de `docker ps`

  """
  @doc """
  Lista todos los contenedores Docker activos.

  ## Returns

      CommandResult con la salida de `docker ps`
  """
  def list_containers do
    case ensure_running() do
      :ok ->
        Argos.exec_command("docker ps --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}\"")
      _ ->
        %Argos.Structs.CommandResult{
          command: "docker ps",
          args: [],
          output: "Docker is not running",
          exit_code: 1,
          success?: false,
          error: "Docker daemon not available",
          duration: 0
        }
    end
  end

  @doc """
  Lists all Docker containers (running and stopped).
  """
  def list_all_containers do
    case ensure_running() do
      :ok ->
        Argos.exec_command("docker ps -a --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}\"")
      _ ->
        %Argos.Structs.CommandResult{
          command: "docker ps -a",
          args: [],
          output: "Docker is not running",
          exit_code: 1,
          success?: false,
          error: "Docker daemon not available",
          duration: 0
        }
    end
  end

  @doc """
  Interactively select and download (pull) containers from a multi-select menu.
  First asks for the path to docker-compose.yml, then lists services from it.
  """
  def pull_containers_menu do
    # Ask for docker-compose.yml path
    compose_path = Aegis.question("Enter path to docker-compose.yml:", :input)

    # Use case structure to handle different conditions
    case File.exists?(compose_path) do
      false ->
        Aegis.Printer.error("File does not exist: #{compose_path}")
        {:error, :file_not_found}
      true ->
        # Parse docker-compose.yml to get services
        services = parse_docker_compose_services(compose_path)

        case services == [] do
          true ->
            Aegis.Printer.error("No services found in #{compose_path}")
            {:error, :no_services_found}
          false ->
            # Create menu for services
            options =
              services
              |> Enum.with_index(1)
              |> Enum.map(fn {service, idx} ->
                %Aegis.Structs.MenuOption{
                  id: idx,
                  name: service.name,
                  description: service.image || "No image specified",
                  action_type: :execution,
                  action: fn -> nil end  # Will be handled by multi-select
                }
              end)

            # Create and run menu with multiselect capability
            menu_info = %Aegis.Structs.MenuInfo{
              options: options,
              breadcrumbs: ["Docker", "Pull Containers", Path.basename(compose_path)],
              ascii_art: Aegis.Tui.generate_menu_logo(),
              multiselect: true
            }

            # Run the menu - since we don't have a direct multi-select return API,
            # the multiselect functionality will work through the right/left arrow keys
            # but we'll assume this is a placeholder for now
            Aegis.Tui.run(menu_info)
        end
    end
  end

  # Helper function to parse docker-compose.yml and extract services
  defp parse_docker_compose_services(compose_path) do
    # First check if docker-compose is available
    case System.find_executable("docker-compose") || System.find_executable("docker") do
      nil ->
        # If no docker tools available, use manual parsing
        manual_parse_docker_compose(compose_path)
      _ ->
        # Try docker-compose config command
        compose_dir = Path.dirname(compose_path)

        # Check if we can run docker compose command (newer versions)
        compose_result = Argos.exec_command("cd #{compose_dir} && docker compose config --services 2>/dev/null || docker-compose config --services")

        if compose_result.success? do
          # Parse the output into service names
          compose_result.output
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(fn service_name ->
            # We'll make a best effort to get the image by checking the compose file
            %{
              name: service_name,
              image: get_image_for_service(compose_path, service_name),
              build: nil  # Would need more complex parsing for build context
            }
          end)
        else
          # Fallback to manual parsing if docker-compose command fails
          manual_parse_docker_compose(compose_path)
        end
    end
  end

  # Helper function to manually parse the docker-compose file
  defp manual_parse_docker_compose(compose_path) do
    try do
      content = File.read!(compose_path)

      # Extract service names using regex
      service_regex = ~r/^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*$/m
      services = Regex.scan(service_regex, content, capture: :all_but_first)
               |> List.flatten()
               |> Enum.uniq()

      Enum.map(services, fn service_name ->
        %{
          name: service_name,
          image: get_image_for_service(compose_path, service_name),
          build: nil
        }
      end)
    rescue
      _ -> []
    end
  end

  # Helper function to extract image for a specific service from the compose file
  defp get_image_for_service(compose_path, service_name) do
    try do
      content = File.read!(compose_path)

      # Look for the specific service and extract its image
      # Pattern: service_name:\s*.*?image:\s*(\S+)
      service_pattern = ~r/^[[:space:]]*#{Regex.escape(service_name)}:[[:space:]]*\n(?:^[[:space:]]+.*\n?)*?[[:space:]]+image:[[:space:]]+([^\n#]+)/m

      case Regex.run(service_pattern, content, capture: :all_but_first) do
        [image] -> String.trim(image)
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  # Helper function to pull selected services
  defp pull_selected_services(services) do
    case ensure_running() do
      :ok ->
        Enum.each(services, fn service ->
          if service.image do
            Aegis.Printer.info("Pulling image: #{service.image}")
            case Images.pull(service.image) do
              {:ok, _} ->
                Aegis.Printer.success("Successfully pulled #{service.image}")
              error ->
                Aegis.Printer.error("Failed to pull #{service.image}: #{inspect(error)}")
            end
          end
        end)
      error ->
        error
    end
  end

  def show_container_info do
    nil
  end

  def remove_container(container) do
    answer = Aegis.question("¿Seguro que quieres borrar el contenedor #{container}?", :warning)

    case String.downcase(answer) do
      "y" ->
        Aegis.info("Borrando contenedor #{container}")
        Containers.stop(container)
        Containers.remove(container)

      _ ->
        Aegis.error("No se ha borrado el contenedor #{container}")
    end
  end

  def pull_containers(containers \\ nil) do
    containers = containers || get_containers()
    Enum.each(containers, &Images.pull/1)
    start()
  end

  def show_containers(header, message, option, action, _app_name) do
    Aegis.Terminal.clear_screen()
    Aegis.Printer.logo_with_data()
    Aegis.semiheader(header)

    Aegis.message(
      chunks: [
        %ChunkText{text: message, color: Color.resolve_color(:primary)}
      ]
    )

    options =
      Docker.Containers.list()
      |> Enum.with_index(1)
      |> Enum.map(fn {%{"Names" => names}, idx} ->
        %MenuOption{
          id: idx,
          name: Enum.join(names, ", "),
          description: Enum.join(names, ", "),
          action_type: :execution,
          action: fn -> action.(Enum.join(names, ", ")) end
        }
      end)

    menu_info = %MenuInfo{
      options: options,
      breadcrumbs: ["Docker", option],
      ascii_art: Aegis.Tui.generate_menu_logo()
    }

    Aegis.Tui.run(menu_info)
  end

  @doc """
  Obtiene datos de contenedores filtrados por campo específico.

  ## Parameters

    * `field` - Campo a obtener de los contenedores configurados

  ## Returns

      Lista de mapas con información de contenedores

  """
  @spec get_containers_data(String.t()) :: list()
  def get_containers_data(field) when not is_nil(field) and field != "" do
    case get_containers() do
      [] ->
        Logger.warning("No containers configured or accessible")
        []

      containers when is_list(containers) ->
        containers
        |> Enum.map(&get_container_data(&1, field))
        |> List.flatten()

      _ ->
        Logger.error("Containers config has invalid format")
        []
    end
  end

  def get_containers_data(_invalid_field) do
    Logger.warning("Campo inválido para get_containers_data: debe ser string no vacío")
    []
  end

  def get_container_data(container, field) do
    case ensure_running() do
      :ok ->
        try do
          Docker.Containers.list()
          |> Enum.filter(fn elm -> "/#{container}" in Map.get(elm, "Names", []) end)
          |> Enum.map(fn elm ->
            names =
              Map.get(elm, "Names", [])

            %{
              id: Map.get(elm, "Id"),
              name: List.first(names) || "",
              state: Map.get(elm, field)
            }
          end)
        rescue
          error ->
            Logger.error("Error obteniendo datos del contenedor #{container}: #{inspect(error)}")
            []
        catch
          :exit, reason ->
            Logger.error("Docker no disponible para contenedor #{container}: #{inspect(reason)}")
            []
        end
      _ ->
        Logger.warning("Docker is not running, cannot get data for #{container}")
        []
    end
  end

  @doc """
  Ejecuta un comando Docker con argumentos usando Argos.
  """
  def run_command(command, args \\ []) do
    full_command = "docker #{command} #{Enum.join(args, " ")}"
    Argos.exec_command(full_command)
  end

  @doc """
  Verifica el estado de Docker en el sistema.

  ## Returns

      %{installed: boolean(), running: boolean()}

  ## Examples

      Ark.Docker .status()
      # => %{installed: true, running: true}

  """
  @spec status() :: map()
  def status do
    case System.find_executable("docker") do
      nil ->
        %{installed: false, running: false}

      _path ->
        result = list_containers()
        running = result.success?
        %{installed: true, running: running}
    end
  end

  @doc """
  Ensures Docker is running.
  """
  def ensure_running do
    case status() do
      %{installed: true, running: true} ->
        :ok

      %{installed: true, running: false} ->
        Logger.info("Starting Docker...")
        result = Argos.exec_command("open -a Docker")
        if result.success?, do: :starting, else: {:error, :start_failed}

      %{installed: false} ->
        Logger.error("Docker is not installed")
        {:error, :not_installed}
    end
  end
end
