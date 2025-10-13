defmodule Ark.Tools do
  @moduledoc """
  Herramientas y utilidades varias para Ark.

  Proporciona funciones de propósito general que no pertenecen a un
  módulo específico pero son útiles en todo el ecosistema Ark.

  ## Características

  - ⏱️  Temporizadores y cuentas regresivas visuales
  - 📅 Generación de timestamps únicos
  - 🔗 Configuración de enlaces simbólicos (VSCode)
  - 🌐 Decodificación de variables de entorno JSON
  - ⚙️  Utilidades de configuración del sistema

  Construido sobre:
  - Aurora (1A): Sistema de colores y formateo
  - Argos (1B): Sistema de ejecución y orquestación
  - Aegis (2): Framework CLI/TUI completo
  """

  require Logger

  import Argos.{AsyncTask, Command}

  alias Aurora.Color
  alias Aurora.Structs.ChunkText
  alias Ark.Pathy
  alias Aegis.Animation

  # Delegaciones a otros módulos
  defdelegate motd_raw(opts \\ []), to: Ark.Motd, as: :show

  def ensure_vscode_command_available do
    vscode_config = Application.get_env(:ark, :vscode, %{})
    vscode_name = vscode_config[:vscode_name]
    vscode_path = vscode_config[:vscode_path]
    vscode_link_path = vscode_config[:vscode_link_path]

    Pathy.create_symbolic_link(vscode_name, vscode_path, vscode_link_path)
  end

  def countdown(_, 0) do
    Animation.stop()
    :finished
  end

  def countdown(message, n) when n > 0 do
    Animation.start(
      [
        %ChunkText{text: "#{message} en => ", color: Color.get_color_info(:primary)},
        %ChunkText{text: "#{n}", color: Color.get_color_info(:ternary)}
      ],
      :center
    )

    Process.sleep(1_000)
    countdown(message, n - 1)
  end

  def max_length(string) when is_binary(string), do: String.length(string)

  def max_length(list) when is_list(list) do
    list
    |> Enum.map(fn
      s when is_binary(s) -> String.length(s)
      %Aegis.Structs.MenuOption{name: name} -> String.length(name)
      other -> String.length(to_string(other))
    end)
    |> Enum.max(fn -> 0 end)
  end

  @doc """
  Genera un timestamp único basado en la fecha/hora actual.

  ## Returns

  String con formato "YYYY-MM-DD_HH_MM_SS_microseconds" donde
  los espacios, dos puntos y puntos se reemplazan por guiones bajos.

  ## Examples

      Ark.Tools.timestamp()
      # => "2024-03-15_14_30_25_123456Z"

  """
  @spec timestamp() :: String.t()
  def timestamp do
    DateTime.utc_now()
    |> DateTime.to_string()
    |> String.replace(~r/[\s:.]/, "_")
  end

  @doc """
  Decodifica una variable de entorno como JSON con valor por defecto.

  ## Parameters

    * `system_var` - Nombre de la variable de entorno
    * `default_value` - Valor a retornar si no existe o no es JSON válido

  ## Examples

      # Variable existe y es JSON válido
      System.put_env("CONFIG", "{\"debug\": true}")
      Ark.Tools.decode_env("CONFIG", %{})
      # => %{"debug" => true}

      # Variable no existe
      Ark.Tools.decode_env("NO_EXISTS", "default")
      # => "default"

  """
  @spec decode_env(String.t(), any()) :: any()
  def decode_env(system_var, default_value) do
    case System.get_env(system_var) do
      nil ->
        default_value

      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, result} -> result
          {:error, _} -> default_value
        end

      _ ->
        default_value
    end
  end

  @doc """
  Construye un comando que usa las versiones de Elixir/Erlang específicas del proyecto
  usando asdf, leyendo el archivo .tool-versions del proyecto destino.
  """
  def asdf_command(command, project_path, log \\ fn _msg -> nil end) do
    tool_versions_path = Path.join(project_path, ".tool-versions")

    if File.exists?(tool_versions_path) do
      log.("asdf_command => Leyendo .tool-versions desde: #{tool_versions_path}")

      versions =
        tool_versions_path
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.reduce(%{}, fn line, acc ->
          case String.split(line, " ", trim: true) do
            [tool, version] -> Map.put(acc, tool, version)
            _ -> acc
          end
        end)

      log.("asdf_command => Versiones detectadas: #{inspect(versions)}")

      # Construir comando con versiones específicas
      elixir_version = Map.get(versions, "elixir", "1.18.2-otp-27")
      erlang_version = Map.get(versions, "erlang", "27.2")

      # asdf exec usará las versiones definidas en .tool-versions del directorio actual
      asdf_command = "cd #{project_path} && asdf exec #{command}"

      log.(
        "asdf_command => Comando generado: #{asdf_command} (usando elixir #{elixir_version}, erlang #{erlang_version})"
      )

      result =
        exec!(asdf_command,
          env: [
            {"PATH",
             "#{System.get_env("HOME")}/.asdf/shims:#{System.get_env("HOME")}/.asdf/bin:#{System.get_env("PATH")}"}
          ]
        )

      if result.success? do
        result.output
      else
        Logger.error("Error ejecutando comando asdf: #{result.error}")
        ""
      end
    else
      log.("asdf_command => No se encontró .tool-versions, usando comando directo")
      # Fallback: usar comando directo si no hay .tool-versions
      fallback_command = "cd #{project_path} && #{command}"

      result =
        exec!(fallback_command,
          env: [
            {"PATH",
             "#{System.get_env("HOME")}/.asdf/shims:#{System.get_env("HOME")}/.asdf/bin:#{System.get_env("PATH")}"}
          ]
        )

      if result.success? do
        result.output
      else
        Logger.error("Error ejecutando comando fallback: #{result.error}")
        ""
      end
    end
  end

  @doc """
  Instala paquetes del sistema usando el gestor de paquetes apropiado.
  """
  @spec install_packages([String.t()], boolean()) :: :ok | {:error, String.t()}
  def install_packages(packages, preupdate \\ true) do
    Logger.info("Installing packages: #{inspect(packages)}, preupdate: #{preupdate}")
    # Delegamos a Ark.Packages que tendrá la implementación real
    Ark.Packages.install_packages(packages, preupdate)
  end

  @doc """
  Configura SSH generando claves si es necesario.
  """
  @spec setup_ssh() :: :ok | {:error, String.t()}
  def setup_ssh do
    Logger.info("Setting up SSH configuration")
    # Delegamos a Ark.Ssh que tendrá la implementación real
    Ark.Ssh.setup()
  end

  @doc """
  Lista las claves SSH disponibles en el sistema.
  """
  @spec list_ssh_keys() :: [String.t()]
  def list_ssh_keys do
    Logger.info("Listing SSH keys")
    # Delegamos a Ark.Ssh que tendrá la implementación real
    Ark.Ssh.list_keys()
  end

  @doc """
  Ejecuta un comando del sistema usando Argos.
  """
  @spec exec_command(String.t()) :: %{success?: boolean(), output: String.t(), exit_code: integer()}
  def exec_command(command) do
    Logger.info("Executing command: #{command}")
    # Usamos el macro exec! de Argos.Command
    result = exec!(command)

    %{
      success?: result.success?,
      output: result.output,
      exit_code: result.exit_code
    }
  end

  @doc """
  Ejecuta tareas en paralelo usando Argos.
  """
  @spec run_parallel([{String.t(), String.t()}]) :: map()
  def run_parallel(tasks) do
    Logger.info("Running parallel tasks: #{inspect(tasks)}")
    # Delegamos a Argos que tendrá la implementación real
    AsyncTask.run_parallel(tasks)
  end

  @doc """
  Obtiene información del sistema usando MOTD.
  """
  @spec system_info(keyword()) :: :ok
  def system_info(opts \\ []) do
    Logger.info("Getting system information with options: #{inspect(opts)}")
    # Usamos la función motd_raw que ya está definida
    motd_raw(opts)
  end
end
