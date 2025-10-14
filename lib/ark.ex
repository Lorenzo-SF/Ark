defmodule Ark do
  @moduledoc """
  Ark - Microframework global de herramientas de desarrollo para Elixir.

  Nivel 3 de Proyecto Ypsilon. Ark proporciona una suite completa de
  herramientas para facilitar el desarrollo y la configuración del entorno de trabajo.

  Construido sobre:
  - Aurora (1A): Sistema de colores y formateo
  - Argos (1B): Sistema de ejecución y orquestación
  - Aegis (2): Framework CLI/TUI completo

  ## Herramientas disponibles

  - 🖥️  **Sistema**: MOTD, información del sistema
  - 🔧 **Git**: Configuración, clonado, sincronización de repositorios
  - 🐳 **Docker**: Gestión de contenedores
  - 🔑 **SSH**: Generación y gestión de llaves
  - 📦 **Paquetes**: Instalación automatizada
  - ⚙️  **Terminal**: Configuración de shell y herramientas
  - 🌤️  **Clima**: Información meteorológica
  - 🔗 **API**: Cliente HTTP con autenticación
  - 📁 **Paths**: Utilidades de archivos y rutas

  ## Uso rápido

      # Mostrar información del sistema
      Ark.system_info()

      # Configurar Git
      Ark.setup_git()

      # Gestionar Docker
      Ark.docker_start()
      Ark.docker_stop()

      # Crear llaves SSH
      Ark.setup_ssh()

      # Instalar paquetes
      Ark.install_packages(["git", "docker", "curl"])

  ## Módulos especializados

  Para funcionalidades avanzadas, usa directamente los módulos:

  - `Ark.Motd` - MOTD y sistema
  - `Ark.Git` - Operaciones Git
  - `Ark.Docker ` - Gestión Docker
  - `Ark.Ssh` - Llaves SSH
  - `Ark.Packages` - Instalación paquetes
  - `Ark.Weather` - Información clima
  - `Ark.HTTP` - Cliente HTTP
  - `Ark.Pathy` - Utilidades paths
  - `Ark.Tools` - Herramientas varias
  """

  alias Ark.Tools.{Docker, Git, Motd, Packages}
  alias Ark.Ssh, as: Ssh
  alias Ark.{HTTP, Weather}

  @doc """
  Muestra información completa del sistema (MOTD).

  ## Options

    * `:layout` - Layout del MOTD (`:full`, `:compact`)
    * `:weather` - Incluir información del clima (default: `true`)
    * `:network` - Incluir información de red (default: `true`)

  ## Examples

      Ark.system_info()
      Ark.system_info(layout: :compact, weather: false)

  """
  @spec system_info(keyword()) :: :ok
  def system_info(opts \\ []) do
    Motd.info(opts)
    :ok
  end

  @doc """
  Configura Git con nombre de usuario y email.

  Solicita interactivamente la configuración si no se especifica.
  """
  @spec setup_git() :: :ok
  def setup_git do
    Git.config_git()
    :ok
  end

  @doc """
  Obtiene información del usuario Git actual.

  ## Examples

      %{name: "Juan Pérez", email: "juan@example.com", hostname: "mi-mac"}

  """
  @spec git_user_info() :: map()
  def git_user_info do
    Git.get_user_info()
  end

  @doc """
  Inicia todos los contenedores Docker configurados.
  """
  @spec docker_start() :: :containers_started
  def docker_start do
    Docker.start()
  end

  @doc """
  Detiene todos los contenedores Docker.
  """
  @spec docker_stop() :: :containers_stopped
  def docker_stop do
    Docker.stop()
  end

  @doc """
  Verifica el estado de Docker.

  ## Examples

      %{installed: true, running: true}

  """
  @spec docker_status() :: map()
  def docker_status do
    Docker.status()
  end

  @doc """
  Crea llaves SSH si no existen.

  Genera una nueva llave RSA 4096-bit con permisos correctos.
  """
  @spec setup_ssh() :: :ok
  def setup_ssh do
    Ssh.create()
    :ok
  end

  @doc """
  Lista las llaves SSH disponibles.

  ## Examples

      ["id_rsa", "id_ed25519", "github"]

  """
  @spec list_ssh_keys() :: [String.t()]
  def list_ssh_keys do
    Ssh.list_keys()
  end

  @doc """
  Instala una lista de paquetes usando el gestor del sistema.

  ## Parameters

    * `packages` - Lista de nombres de paquetes a instalar
    * `preupdate` - Actualizar cache antes de instalar (default: `true`)

  ## Examples

      Ark.install_packages(["git", "curl", "vim"])
      Ark.install_packages(["docker"], false)

  """
  @spec install_packages([String.t()], boolean()) :: :ok
  def install_packages(packages, preupdate \\ true) do
    Packages.install_packages(packages, preupdate)
    :ok
  end

  @doc """
  Clona repositorios en un workspace.

  ## Parameters

    * `repos` - Lista de mapas con `:repo` y configuración
    * `workspace_path` - Ruta del workspace donde clonar

  ## Examples

      repos = [%{repo: %{url: "git@github.com:user/repo.git", path: "/workspace/repo"}}]
      Ark.clone_repos(repos, "/workspace")

  """
  @spec clone_repos([map()], String.t()) :: [tuple()]
  def clone_repos(repos, workspace_path) do
    Git.ensure_clone(repos, workspace_path)
  end

  @doc """
  Sincroniza repositorios Git (fetch + pull).

  ## Parameters

    * `repos` - Repositorio o lista de repositorios a sincronizar

  ## Examples

      # Sincronizar un repo
      Ark.sync_repos(%{path: "/path/to/repo", main_branch: "main"})

      # Sincronizar múltiples repos
      Ark.sync_repos([repo1, repo2, repo3])

  """
  @spec sync_repos(map() | [map()]) :: :ok
  def sync_repos(repos) do
    Git.sync(repos)
    :ok
  end

  @doc """
  Muestra un mensaje de éxito usando Aegis.

  ## Examples

      Ark.success("Operación completada exitosamente")

  """
  @spec success(String.t()) :: :ok
  def success(message) do
    Aegis.success(message)
  end

  @doc """
  Muestra un mensaje de error usando Aegis.

  ## Examples

      Ark.error("Error en la operación")

  """
  @spec error(String.t()) :: :ok
  def error(message) do
    Aegis.error(message)
  end

  @doc """
  Muestra un mensaje de advertencia usando Aegis.

  ## Examples

      Ark.warning("Ten cuidado con esta operación")

  """
  @spec warning(String.t()) :: :ok
  def warning(message) do
    Aegis.warning(message)
  end

  @doc """
  Muestra un mensaje informativo usando Aegis.

  ## Examples

      Ark.info("Procesando datos...")

  """
  @spec info(String.t()) :: :ok
  def info(message) do
    Aegis.info(message)
  end

  @doc """
  Ejecuta un comando del sistema usando Argos.

  ## Examples

      result = Ark.exec_command("ls -la")
      if result.success?, do: IO.puts(result.output)

  """
  @spec exec_command(String.t()) :: Argos.Structs.CommandResult.t()
  def exec_command(command) do
    Argos.exec_command(command)
  end

  @doc """
  Ejecuta múltiples tareas en paralelo usando Argos.

  ## Examples

      tasks = [
        {"compile", "mix compile"},
        {"test", "mix test"}
      ]
      result = Ark.run_parallel(tasks)

  """
  @spec run_parallel([{String.t(), String.t()}], keyword()) :: map()
  def run_parallel(tasks, opts \\ []) do
    Argos.run_parallel(tasks, opts)
  end

  @doc """
  Obtiene información meteorológica del día actual.

  ## Parameters

    * `url` - URL del servicio meteorológico XML

  ## Examples

      Ark.weather_today("https://servicio-clima.es/prediccion.xml")

  """
  @spec weather_today(String.t() | nil) :: [list()]
  def weather_today(url) do
    Weather.get_today(url)
  end

  @doc """
  Realiza una llamada HTTP con opciones básicas.

  ## Parameters

    * `opts` - Keyword list con opciones de la petición
      - `:url` - URL del endpoint
      - `:method` - Método HTTP (`:get`, `:post`, etc.)
      - `:params` - Parámetros de la petición

  ## Examples

      Ark.http_call(url: "https://api.example.com/data", method: :get)

  """
  @spec http_call(keyword()) :: {:ok, integer(), map()} | {:error, term()}
  def http_call(opts \\ []) do
    HTTP.call(opts)
  end

  @doc """
  Realiza una llamada HTTP con autenticación automática.

  ## Parameters

    * `opts` - Keyword list con opciones de la petición

  ## Examples

      Ark.http_call_with_auth(url: "https://api.example.com/protected", method: :get)

  """
  @spec http_call_with_auth(keyword()) :: {:ok, integer(), map()} | {:error, term()}
  def http_call_with_auth(opts \\ []) do
    HTTP.call_with_login(opts)
  end
end
