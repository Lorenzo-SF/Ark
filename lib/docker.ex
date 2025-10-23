defmodule Ark.Docker do
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

  alias Aurora.Structs.ChunkText
  alias Docker.{Containers, Images}
  alias Aegis.{Printer, Terminal, Tui}
  alias Aegis.Printer.Logos
  alias Argos.Structs.CommandResult

  defp get_containers, do: Application.get_env(:ark, :docker)[:containers] || []

  defp running?(nil, container), do: {container, :not_available}
  defp running?(%{state: %{"Status" => "running"}}, container), do: {container, :started}
  defp running?(_, container), do: {container, :not_started}

  def wait_until_containers_start do
    Enum.each(get_containers(), &check_running/1)
  end

  def check_running(container) do
    case ensure_running() do
      :ok ->
        task_name = String.to_atom("check_#{container}_running")

        # Fallback: run the check loop directly in a new process instead of using AsyncTask
        spawn(fn -> check_container_loop(container, task_name) end)

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
        :ok
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
        Enum.each(container_ids, &stop_container/1)
        :ok

      error ->
        error
    end
  end

  defp stop_container(id) do
    case Containers.stop(id) do
      {:ok, _} -> Logger.info("Stopped container: #{id}")
      error -> Logger.error("Failed to stop container #{id}: #{inspect(error)}")
    end
  end

  @doc """
  Starts specific containers by ID or name.
  """
  def start_containers(container_ids) when is_list(container_ids) do
    case ensure_running() do
      :ok ->
        Enum.each(container_ids, &start_container/1)
        :ok

      error ->
        error
    end
  end

  defp start_container(id) do
    case Containers.start(id) do
      {:ok, _} -> Logger.info("Started container: #{id}")
      error -> Logger.error("Failed to start container #{id}: #{inspect(error)}")
    end
  end

  @doc """
  Removes specific containers by ID or name.
  """
  def remove_containers(container_ids) when is_list(container_ids) do
    case ensure_running() do
      :ok ->
        Enum.each(container_ids, &stop_and_remove_container/1)
        :ok

      error ->
        error
    end
  end

  defp stop_and_remove_container(id) do
    case Containers.stop(id) do
      {:ok, _} ->
        Logger.info("Stopped container before removal: #{id}")

      _ ->
        Logger.info("Container wasn't running: #{id}")
    end

    case Containers.remove(id) do
      {:ok, _} -> Logger.info("Removed container: #{id}")
      error -> Logger.error("Failed to remove container #{id}: #{inspect(error)}")
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
          Printer.info("Started #{length(container_ids)} containers")
        end)

      _ ->
        Printer.error("Docker is not available")
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
          Printer.info("Stopped #{length(container_ids)} containers")
        end)

      _ ->
        Printer.error("Docker is not available")
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
          Printer.info("Removed #{length(container_ids)} containers")
        end)

      _ ->
        Printer.error("Docker is not available")
    end
  end

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

  defp display_container_menu(containers, title, action_callback) do
    case containers do
      [] ->
        Printer.warning("No containers available")
        :no_containers

      _ ->
        options = create_multi_select_workflow(containers, action_callback)

        menu_info = %Aegis.Structs.MenuInfo{
          options: options,
          breadcrumbs: ["Docker", title],
          ascii_art: Logos.start_logo() || "",
          multiselect: true
        }

        Tui.run(menu_info)
    end
  end

  defp create_multi_select_workflow(containers, _action_callback) do
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
            container
          end
        }
      end)

    action_options = [
      %Aegis.Structs.MenuOption{
        id: :execute_action,
        name: "Execute Action on Selected",
        description: "Perform the requested action on all selected containers",
        action_type: :execution,
        action: fn ->
          :execute_selected
        end
      },
      %Aegis.Structs.MenuOption{
        id: :back,
        name: "Back to Main",
        description: "Return to previous menu",
        action_type: :navigation,
        action: fn ->
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
  def list_containers do
    case ensure_running() do
      :ok ->
        Argos.Command.exec("docker ps --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}\"")

      _ ->
        %CommandResult{
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
        Argos.Command.exec("docker ps -a --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}\"")

      _ ->
        %CommandResult{
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
    compose_path = Aegis.question("Enter path to docker-compose.yml:")

    case File.exists?(compose_path) do
      false ->
        Printer.error("File does not exist: #{compose_path}")
        {:error, :file_not_found}

      true ->
        services = parse_docker_compose_services(compose_path)

        case services == [] do
          true ->
            Printer.error("No services found in #{compose_path}")
            {:error, :no_services_found}

          false ->
            options =
              services
              |> Enum.with_index(1)
              |> Enum.map(&create_menu_option/1)

            menu_info = %Aegis.Structs.MenuInfo{
              options: options,
              breadcrumbs: ["Docker", "Pull Containers", Path.basename(compose_path)],
              ascii_art: Logos.start_logo() || "",
              multiselect: true
            }

            Tui.run(menu_info)
        end
    end
  end

  defp create_menu_option({service, idx}) do
    %Aegis.Structs.MenuOption{
      id: idx,
      name: service.name,
      description: service.image || "No image specified",
      action_type: :execution,
      action: fn -> nil end
    }
  end

  defp parse_docker_compose_services(compose_path) do
    case System.find_executable("docker-compose") || System.find_executable("docker") do
      nil ->
        manual_parse_docker_compose(compose_path)

      _ ->
        compose_dir = Path.dirname(compose_path)

        compose_result =
          Argos.Command.exec(
            "cd #{compose_dir} && docker compose config --services 2>/dev/null || docker-compose config --services"
          )

        if compose_result.success? do
          compose_result.output
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&create_service_map(&1, compose_path))
        else
          manual_parse_docker_compose(compose_path)
        end
    end
  end

  defp create_service_map(service_name, compose_path) do
    %{
      name: service_name,
      image: get_image_for_service(compose_path, service_name),
      build: nil
    }
  end

  defp manual_parse_docker_compose(compose_path) do
    content = File.read!(compose_path)

    service_regex = ~r/^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*$/m

    services =
      Regex.scan(service_regex, content, capture: :all_but_first)
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

  defp get_image_for_service(compose_path, service_name) do
    content = File.read!(compose_path)

    service_pattern =
      ~r/^[[:space:]]*#{Regex.escape(service_name)}:[[:space:]]*\n(?:^[[:space:]]+.*\n?)*?[[:space:]]+image:[[:space:]]+([^\n#]+)/m

    case Regex.run(service_pattern, content, capture: :all_but_first) do
      [image] -> String.trim(image)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def show_container_info do
    nil
  end

  def remove_container(container) do
    answer = Printer.question("¿Seguro que quieres borrar el contenedor #{container}?", :warning)

    case String.downcase(answer) do
      "y" ->
        Printer.info("Borrando contenedor #{container}")
        Containers.stop(container)
        Containers.remove(container)

      _ ->
        Printer.error("No se ha borrado el contenedor #{container}")
    end
  end

  def pull_containers(containers \\ nil) do
    containers = containers || get_containers()
    Enum.each(containers, &Images.pull/1)
    start()
  end

  def show_containers(header, message, option, action, _app_name) do
    Terminal.clear_screen()
    Printer.logo_with_data()
    Printer.semiheader(header)

    Printer.message(
      chunks: [
        %ChunkText{text: message, color: Aurora.Color.get_color_info(:primary)}
      ]
    )

    options =
      Docker.Containers.list()
      |> Enum.with_index(1)
      |> Enum.map(fn {%{"Names" => names}, idx} ->
        %Aegis.Structs.MenuOption{
          id: idx,
          name: Enum.join(names, ", "),
          description: Enum.join(names, ", "),
          action_type: :execution,
          action: fn -> action.(Enum.join(names, ", ")) end
        }
      end)

    menu_info = %Aegis.Structs.MenuInfo{
      options: options,
      breadcrumbs: ["Docker", option],
      ascii_art: Logos.start_logo() || ""
    }

    Tui.run(menu_info)
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
    Argos.Command.exec(full_command)
  end

  @doc """
  Verifica el estado de Docker en el sistema.

  ## Returns

      %{installed: boolean(), running: boolean()}

  ## Examples

      Ark.Docker .status()


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
        result = Argos.Command.exec("open -a Docker")
        if result.success?, do: :starting, else: {:error, :start_failed}

      %{installed: false} ->
        Logger.error("Docker is not installed")
        {:error, :not_installed}
    end
  end
end
