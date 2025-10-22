defmodule Ark.Git do
  @moduledoc """
  Utilidades Git para Ark - Configuración y gestión de repositorios.

  Proporciona funcionalidades para configurar Git, clonar repositorios,
  sincronizar cambios y gestionar múltiples proyectos.

  ## Características

  - ⚙️  Configuración automática de usuario Git
  - 📥 Clonado masivo de repositorios
  - 🔄 Sincronización automática (fetch + pull)
  - 📂 Gestión de workspaces
  - 🌿 Verificación de ramas remotas
  - 💾 Operaciones commit y staging
  - 🏠 Detección automática de información del sistema

  Construido sobre:
  - Aurora (1A): Sistema de colores y formateo
  - Argos (1B): Sistema de ejecución y orquestación
  - Aegis (2): Framework CLI/TUI completo
  """
  alias Aegis.Printer
  alias Argos.Command
  alias Ark.Pathy
  alias Aurora.Color
  alias Aurora.Structs.ChunkText

  @doc """
  Configura Git interactivamente solicitando nombre de usuario y email.

  Si ya existe configuración previa, la muestra como valor por defecto.
  También configura URLs para SSH con GitHub y GitLab.

  ## Examples

      Ark.Git.config_git()
      # Solicita: "Introduce el nombre de usuario (Si lo dejas vacío, se usará 'Juan Pérez')"
      # Solicita: "Introduce el email de usuario (Si lo dejas vacío, se usará 'juan@example.com')"

  """
  @spec config_git() :: :ok
  def config_git do
    previous_name = get_git_user_name()
    previous_email = get_git_user_email()

    name =
      Printer.question("GIT - Introduce el nombre de usuario (Si lo dejas vacío, se usará '#{previous_name}')")

    email =
      Printer.question("GIT - Introduce el email de usuario (Si lo dejas vacío, se usará '#{previous_email}')")

    name = if name == "", do: previous_name, else: name
    email = if email == "", do: previous_email, else: email

    Printer.animation([
      %ChunkText{
        text: "Configurando Git con nombre '#{name}' y email '#{email}'",
        color: Color.get_color_info(:ternary)
      }
    ])

    set_user_info(name, email)
  end

  @doc """
  Actualiza un repositorio existente haciendo fetch desde origin de forma segura.

  ## Examples

      Ark.Git.update_existing_repository("/path/to/repo")
      # => {:ok, output}
      # => {:error, :fetch_failed}
  """
  def update_existing_repository(repo_path) do
    Printer.animation([
      %ChunkText{
        text: "Actualizando repositorio #{Path.basename(repo_path)}",
        color: Color.get_color_info(:ternary)
      }
    ])

    case File.cd(repo_path) do
      {:ok, _} ->
        fetch_repository_updates()

      {:error, reason} ->
        {:error, {:cannot_access_path, reason}}
    end
  end

  defp fetch_repository_updates do
    # Verificar que es un repositorio git válido
    case Argos.Command.exec_silent("git rev-parse --git-dir") do
      %{success?: true} ->
        # Hacer fetch de forma segura sin refspec específico
        case Argos.Command.exec_silent("git fetch --all") do
          %{success?: true, output: output} ->
            {:ok, output}

          %{success?: false, output: _error} ->
            {:error, :fetch_failed}
        end

      %{success?: false} ->
        {:error, :not_a_git_repository}
    end
  end

  @doc """
  Verifica si una rama existe localmente o remotamente.

  ## Examples

      Ark.Git.branch_exists?("main")
      # => true

      Ark.Git.branch_exists?("feature/nueva-funcionalidad")
      # => false
  """
  def branch_exists?(branch) do
    result_local = Argos.Command.exec_silent("git show-ref --verify --quiet refs/heads/#{branch}")
    exists_local = result_local.success?

    result_remote = Argos.Command.exec_silent("git ls-remote --exit-code --heads origin #{branch}")
    exists_remote = result_remote.success?

    exists_local or exists_remote
  end

  @doc """
  Asegura que un repositorio esté clonado. Si ya existe, lo actualiza.

  ## Examples

      Ark.Git.ensure_clone(%{url: "https://github.com/user/repo.git", path: "/path"}, "/workspace")
      # => {:repo_exists, repo} | {:repo_cloned, repo} | {:repo_error, repo, error}
  """
  def ensure_clone(nil), do: {:error, :no_repo_defined}

  def ensure_clone(repos, workspace_path) when is_list(repos) do
    results =
      Enum.map(repos, fn %{repo: repo} ->
        ensure_clone(repo, workspace_path)
      end)

    repos
    |> Enum.map(& &1.repo)
    |> sync()
  end

  def ensure_clone(%{url: url, path: path} = repo, workspace_path)
      when is_binary(url) and is_binary(path) do
    _relative_path = Path.relative_to(path, workspace_path)
    _service = Path.basename(path)

    if File.dir?(path) do
      {:repo_exists, repo}
    else
      case clone(repo) do
        {:ok, repo} ->
          {:repo_cloned, repo}

        {:error, {code, error, _repo}} ->
          {:repo_error, repo, {code, error}}
      end
    end
  end

  @doc """
  Obtiene la lista de repositorios existentes como estructura de árbol.

  ## Examples

      Ark.Git.existing_repos([{:repo_exists, %{path: "/path/to/repo"}}])
      # => %{...}
  """
  def existing_repos(repos) do
    repos
    |> Enum.filter(fn {status, _} -> status == :repo_exists end)
    |> Enum.map(fn {_, %{path: path}} -> path end)
    |> Pathy.generate_tree()
  end

  @doc """
  Obtiene información completa del usuario para Git.

  Combina información del usuario Git, del sistema y hostname.

  ## Returns

      %{
        name: "Juan Pérez",
        email: "juan@example.com",
        hostname: "mi-macbook mac"
      }

  """
  @spec get_user_info() :: map()
  def get_user_info do
    %{
      name: get_git_user_name() || get_system_user_name(),
      email: get_git_user_email() || get_system_user_email(),
      hostname: get_hostname()
    }
  end

  @doc """
  Configura la información del usuario Git globalmente.

  ## Examples

      Ark.Git.set_user_info("Juan Pérez", "juan@example.com")
      # => :ok
  """
  def set_user_info(name, email) do
    config_global("user.name '#{name}'")
    config_global("user.email '#{email}'")
    config_global("url.git@github.com:.insteadOf https://github.com/")
    config_global("url.git@gitlab.com:.insteadOf https://gitlab.com/")
    config_global("pull.rebase false")

    :ok
  end

  @doc """
  Realiza stage y commit de todos los cambios en un repositorio.

  ## Examples

      Ark.Git.stage_and_commit(%{path: "/path/to/repo"}, "Mensaje del commit")
      # => {:ok, repo} | {:error, reason}
  """
  def stage_and_commit(%{path: path} = repo, message) when is_binary(message) do
    with :ok <- add(path, :all),
         {:ok, repo} <- commit(repo, message) do
      {:ok, repo}
    else
      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :unknown}
    end
  end

  @doc """
  Sincroniza múltiples repositorios (checkout + fetch + pull).

  ## Examples

      Ark.Git.sync([%{path: "/path1"}, %{path: "/path2"}])
      # => :ok
  """
  def sync(repos) when is_list(repos) do
    Enum.each(repos, fn repo ->
      sync(repo)
    end)
  end

  def sync(%{path: _path} = repo) do
    with {:ok, repo} <- checkout(repo),
         {:ok, repo} <- fetch(repo),
         {:ok, repo} <- pull(repo) do
      {:ok, repo}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Añade archiles al stage area de Git.

  ## Examples

      Ark.Git.add("/path/to/repo", :all)
      # => :ok

      Ark.Git.add("/path/to/repo", ["file1.ex", "file2.ex"])
      # => :ok
  """
  def add(%{path: path}, :all) do
    add(path, ["."])
    :ok
  end

  def add(repo_path, files) when is_list(files) do
    Enum.each(files, fn file ->
      case add(repo_path, file) do
        {:ok, _output} ->
          :ok

        {:error, _reason} ->
          :ok
      end
    end)

    :ok
  end

  def add(repo_path, file) when is_binary(file) do
    go_to_repo(repo_path)

    result = Argos.Command.exec_silent("git add #{file}")

    if result.success? do
      {:ok, result.output}
    else
      {:error, {result.exit_code, result.output}}
    end
  end

  @doc """
  Cambia a una rama específica en un repositorio.

  ## Examples

      Ark.Git.checkout(%{path: "/path/to/repo", main_branch: "main"})
      # => {:ok, repo} | {:error, reason}
  """
  def checkout(%{path: path, main_branch: target_branch} = repo)
      when not is_nil(path) and not is_nil(target_branch) do
    go_to_repo(path)

    Argos.Command.exec_silent("git rev-parse --abbrev-ref HEAD")

    Argos.Command.exec_silent("git stash push -u -m 'ark auto-stash before checkout'")

    # Hacemos checkout a la rama target
    result = Argos.Command.exec_silent("git checkout #{target_branch}")

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  @doc """
  Clona un repositorio desde una URL a un path específico.

  ## Examples

      Ark.Git.clone(%{url: "https://github.com/user/repo.git", path: "/target/path"})
      # => {:ok, repo} | {:error, reason}
  """
  def clone(%{url: url, path: path} = repo) do
    result =
      Argos.Command.exec_silent(
        "git clone --quiet #{url} #{path}",
        env: [{"GIT_TERMINAL_PROMPT", "0"}]
      )

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  @doc """
  Realiza un commit con un mensaje específico.

  ## Examples

      Ark.Git.commit(%{path: "/path/to/repo"}, "Mensaje del commit")
      # => {:ok, repo} | {:error, reason}
  """
  def commit(%{path: path} = repo, message) do
    go_to_repo(path)

    result = Argos.Command.exec_silent("git commit -m \"#{message}\"")

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  @doc """
  Obtiene configuración de Git.

  ## Examples

      Ark.Git.config("user.name")
      # => "Juan Pérez"
  """
  def config(attr) do
    result = Argos.Command.exec_silent("git config #{attr}")
    if result.success?, do: result.output, else: ""
  end

  def config_global(attr) do
    config("--global #{attr}")
  end

  def config_local(attr) do
    config("--local #{attr}")
  end

  @doc """
  Realiza fetch en un repositorio.

  ## Examples

      Ark.Git.fetch(%{path: "/path/to/repo"})
      # => {:ok, repo} | {:error, reason}
  """
  def fetch(%{path: path} = repo) do
    go_to_repo(path)

    result = Argos.Command.exec_silent("git fetch")

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  @doc """
  Obtiene el nombre de usuario configurado en Git.

  ## Examples

      Ark.Git.get_git_user_name()
      # => "Juan Pérez"
  """
  def get_git_user_name do
    result = Argos.Command.exec_silent("git config user.name")

    if result.success? do
      result.output
      |> String.trim()
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)
    else
      ""
    end
  end

  @doc """
  Obtiene el email de usuario configurado en Git.

  ## Examples

      Ark.Git.get_git_user_email()
      # => "juan@example.com"
  """
  def get_git_user_email do
    result = Argos.Command.exec_silent("git config user.email")

    if result.success? do
      String.trim(result.output)
    else
      ""
    end
  end

  @doc """
  Obtiene el nombre de usuario del sistema.

  ## Examples

      Ark.Git.get_system_user_name()
      # => "juanperez"
  """
  def get_system_user_name do
    case :os.type() do
      {:unix, _} ->
        (System.get_env("USER") || System.get_env("LOGNAME") || "")
        |> String.trim()
        |> String.split()
        |> Enum.map_join(" ", &String.capitalize/1)

      {:win32, _} ->
        (System.get_env("USERNAME") || "")
        |> String.trim()
        |> String.split()
        |> Enum.map_join(" ", &String.capitalize/1)

      _ ->
        nil
    end
  end

  @doc """
  Obtiene el email de usuario del sistema.

  ## Examples

      Ark.Git.get_system_user_email()
      # => "user@domain.com"
  """
  def get_system_user_email do
    case :os.type() do
      {:unix, _} -> System.get_env("USER_EMAIL") || "user@domain.com"
      {:win32, _} -> System.get_env("USER_EMAIL") || "user@domain.com"
      _ -> nil
    end
  end

  @doc """
  Obtiene el hostname del sistema.

  ## Examples

      Ark.Git.get_hostname()
      # => "mi-macbook mac"
  """
  def get_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name) <> " mac"
      _ -> "ark"
    end
  end

  @doc """
  Cambia al directorio del repositorio.

  ## Examples

      Ark.Git.go_to_repo("/path/to/repo")
      # => :ok
  """
  def go_to_repo(path) do
    path
    |> Path.expand()
    |> File.cd()
  end

  @doc """
  Realiza pull en un repositorio desde una rama específica.

  ## Examples

      Ark.Git.pull(%{path: "/path/to/repo", main_branch: "main"})
      # => {:ok, repo} | {:error, reason}
  """
  def pull(%{path: path, main_branch: branch} = repo) do
    go_to_repo(path)

    result = Argos.Command.exec_silent("git pull origin #{branch}")

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  @doc """
  Hace fetch desde origin en un path específico.

  ## Examples

      Ark.Git.fetch_origin("/path/to/repo")
      # => {:ok, output}
      # => {:error, {code, error}}
  """
  def fetch_origin(repo_path) do
    go_to_repo(repo_path)

    result = Argos.Command.exec_silent("git fetch origin")

    if result.success? do
      {:ok, result.output}
    else
      {:error, {result.exit_code, result.output}}
    end
  end

  @doc """
  Hace pull desde origin main en un path específico.

  ## Examples

      Ark.Git.pull_origin("/path/to/repo", "main")
      # => {:ok, output}
      # => {:error, {code, error}}
  """
  def pull_origin(repo_path, branch \\ "main") do
    go_to_repo(repo_path)

    result = Argos.Command.exec_silent("git pull origin #{branch}")

    if result.success? do
      {:ok, result.output}
    else
      {:error, {result.exit_code, result.output}}
    end
  end

  @doc """
  Clona un repositorio desde una URL a un path específico.

  ## Examples

      Ark.Git.clone_repository("https://github.com/user/repo.git", "/target/path")
      # => {:ok, output}
      # => {:error, {code, error}}
  """
  def clone_repository(url, target_path) do
    result = Argos.Command.exec_silent("git clone --quiet #{url} #{target_path}")

    if result.success? do
      {:ok, result.output}
    else
      {:error, {result.exit_code, result.output}}
    end
  end
end
