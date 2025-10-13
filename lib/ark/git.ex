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
  import Argos.Command

  alias Aurora.Color
  alias Aurora.Structs.ChunkText
  alias Ark.Pathy

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
      Aegis.question(
        "GIT - Introduce el nombre de usuario (Si lo dejas vacío, se usará '#{previous_name}')"
      )

    email =
      Aegis.question(
        "GIT - Introduce el email de usuario (Si lo dejas vacío, se usará '#{previous_email}')"
      )

    name = if name == "", do: previous_name, else: name
    email = if email == "", do: previous_email, else: email

    Aegis.start_animation([
      %ChunkText{
        text: "Configurando Git con nombre '#{name}' y email '#{email}'",
        color: Color.get_color_info(:ternary)
      }
    ])

    set_user_info(name, email)
  end

  def branch_exists?(branch) do
    result_local = exec_silent!("git show-ref --verify --quiet refs/heads/#{branch}")
    exists_local = result_local.success?

    result_remote = exec_silent!("git ls-remote --exit-code --heads origin #{branch}")
    exists_remote = result_remote.success?

    exists_local or exists_remote
  end

  def ensure_clone(nil), do: {:error, :no_repo_defined}

  def ensure_clone(repos, workspace_path) when is_list(repos) do
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

  def set_user_info(name, email) do
    config_global("user.name '#{name}'")
    config_global("user.email '#{email}'")
    config_global("url.git@github.com:.insteadOf https://github.com/")
    config_global("url.git@gitlab.com:.insteadOf https://gitlab.com/")
    config_global("pull.rebase false")

    :ok
  end

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

    result = exec_silent!("git add #{file}")

    if result.success? do
      {:ok, result.output}
    else
      {:error, {result.exit_code, result.output}}
    end
  end

  def checkout(%{path: path, main_branch: target_branch} = repo)
      when not is_nil(path) and not is_nil(target_branch) do
    go_to_repo(path)

    exec_silent!("git rev-parse --abbrev-ref HEAD")

    exec_silent!("git stash push -u -m 'ark auto-stash before checkout'")

    # Hacemos checkout a la rama target
    result = exec_silent!("git checkout #{target_branch}")

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  def clone(%{url: url, path: path} = repo) do
    result =
      exec_silent!(
        "git clone --quiet #{url} #{path}",
        env: [{"GIT_TERMINAL_PROMPT", "0"}]
      )

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  def commit(%{path: path} = repo, message) do
    go_to_repo(path)

    result = exec_silent!("git commit -m \"#{message}\"")

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  def config(attr) do
    result = exec_silent!("git config #{attr}")
    if result.success?, do: result.output, else: ""
  end

  def config_global(attr) do
    config("--global #{attr}")
  end

  def config_local(attr) do
    config("--local #{attr}")
  end

  def fetch(%{path: path} = repo) do
    go_to_repo(path)

    result = exec_silent!("git fetch")

    if result.success? do
      {:ok, repo}
    else
      {:error, {result.exit_code, result.output, repo}}
    end
  end

  def get_git_user_name do
    result = exec_silent!("git config user.name")

    if result.success? do
      result.output
      |> String.trim()
      |> String.split()
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")
    else
      ""
    end
  end

  def get_git_user_email do
    result = exec_silent!("git config user.email")

    if result.success? do
      String.trim(result.output)
    else
      ""
    end
  end

  def get_system_user_name do
    case :os.type() do
      {:unix, _} ->
        (System.get_env("USER") || System.get_env("LOGNAME") || "")
        |> String.trim()
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      {:win32, _} ->
        (System.get_env("USERNAME") || "")
        |> String.trim()
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      _ ->
        nil
    end
  end

  def get_system_user_email do
    case :os.type() do
      {:unix, _} -> System.get_env("USER_EMAIL") || "user@domain.com"
      {:win32, _} -> System.get_env("USER_EMAIL") || "user@domain.com"
      _ -> nil
    end
  end

  def get_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name) <> " mac"
      _ -> "ark"
    end
  end

  def go_to_repo(path) do
    path
    |> Path.expand()
    |> File.cd()
  end

  def pull(%{path: path, main_branch: branch} = repo) do
    go_to_repo(path)

    result = exec_silent!("git pull origin #{branch}")

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

    result = exec_silent!("git fetch origin")

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

    result = exec_silent!("git pull origin #{branch}")

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
    result = exec_silent!("git clone --quiet #{url} #{target_path}")

    if result.success? do
      {:ok, result.output}
    else
      {:error, {result.exit_code, result.output}}
    end
  end
end
