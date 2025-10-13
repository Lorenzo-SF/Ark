defmodule Ark.Pathy do
  @moduledoc """
  Utilidades de archivos y rutas para Ark.

  Proporciona funcionalidades para gestionar archivos, directorios y enlaces
  simbólicos de forma robusta y multiplataforma.

  ## Características

  - 📁 Gestión de directorios y archivos
  - 🔗 Creación de enlaces simbólicos
  - 🌳 Generación de árboles de directorios
  - 📋 Listado recursivo de archivos
  - ✅ Verificación de existencia y permisos
  - 🔧 Utilidades de paths y extensiones

  Construido sobre:
  - Aurora (1A): Sistema de colores y formateo
  - Argos (1B): Sistema de ejecución y orquestación
  - Aegis (2): Framework CLI/TUI completo
  """

  require Logger

  alias Aegis.Printer

  @doc """
  Crea un enlace simbólico con verificación de existencia.

  ## Parameters

    * `name` - Nombre del enlace a crear
    * `source_path` - Ruta fuente del archivo/directorio
    * `link_path` - Ruta donde crear el enlace

  ## Examples

      Ark.Pathy.create_symbolic_link("code", "/usr/local/bin/code", "/usr/local/bin")

  """
  def create_symbolic_link(name, source_path, link_path)
      when not is_nil(name) and not is_nil(source_path) and not is_nil(link_path) do
    target_link = Path.join(link_path, name)

    cond do
      File.exists?(target_link) ->
        Printer.info("#{name} symlink already exists at #{target_link}")
        {:ok, :already_exists}

      not File.exists?(source_path) ->
        Printer.warning("Source #{source_path} does not exist, skipping symlink creation")
        {:error, :source_not_found}

      true ->
        case File.ln_s(source_path, target_link) do
          :ok ->
            Printer.success("Created symlink: #{target_link} -> #{source_path}")
            {:ok, :created}

          {:error, reason} ->
            Printer.error("Failed to create symlink: #{reason}")
            {:error, reason}
        end
    end
  end

  def create_symbolic_link(_, _, _) do
    Printer.error("Invalid parameters for symlink creation")
    {:error, :invalid_params}
  end

  @doc """
  Genera una representación en árbol de una lista de rutas.

  ## Examples

      paths = ["/home/user/docs", "/home/user/projects"]
      Ark.Pathy.generate_tree(paths)

  """
  def generate_tree(paths) when is_list(paths) do
    paths
    |> Enum.sort()
    |> Enum.map(&format_tree_path/1)
    |> Enum.join("\n")
  end

  def generate_tree(_), do: ""

  defp format_tree_path(path) do
    depth = length(Path.split(path)) - 1
    indent = String.duplicate("  ", depth)
    basename = Path.basename(path)
    "#{indent}└── #{basename}"
  end

  @doc """
  Lista archivos recursivamente en un directorio con filtros opcionales.

  ## Parameters

    * `directory` - Directorio a explorar
    * `pattern` - Patrón glob opcional (ej: "*.ex")
    * `recursive` - Si debe buscar recursivamente (default: true)

  ## Examples

      Ark.Pathy.list_files("/home/user/project", "*.ex")

  """
  def list_files(directory, pattern \\ "*", recursive \\ true) do
    if File.dir?(directory) do
      glob_pattern =
        if recursive do
          Path.join([directory, "**", pattern])
        else
          Path.join(directory, pattern)
        end

      Path.wildcard(glob_pattern)
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()
    else
      []
    end
  end

  @doc """
  Verifica si un archivo existe y es legible.

  ## Examples

      Ark.Pathy.file_accessible?("/etc/hosts")
      # => true

  """
  def file_accessible?(path) do
    File.exists?(path) and File.regular?(path) and File.stat!(path).access == :read_write
  rescue
    _ -> false
  end

  @doc """
  Obtiene información detallada de un archivo.

  ## Examples

      Ark.Pathy.file_info("/etc/hosts")
      # => %{size: 1024, type: :regular, access: :read_write, ...}

  """
  def file_info(path) do
    case File.stat(path) do
      {:ok, stat} ->
        %{
          size: stat.size,
          type: stat.type,
          access: stat.access,
          atime: stat.atime,
          mtime: stat.mtime,
          ctime: stat.ctime,
          mode: stat.mode,
          uid: stat.uid,
          gid: stat.gid
        }

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Crea un directorio recursivamente si no existe.

  ## Examples

      Ark.Pathy.ensure_directory("/path/to/new/dir")

  """
  def ensure_directory(path) do
    case File.mkdir_p(path) do
      :ok ->
        Printer.info("Directory ensured: #{path}")
        {:ok, path}

      {:error, reason} ->
        Printer.error("Failed to create directory #{path}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Copia un archivo de fuente a destino.

  ## Examples

      Ark.Pathy.copy_file("/source/file.txt", "/dest/file.txt")

  """
  def copy_file(source, destination) do
    case File.cp(source, destination) do
      :ok ->
        Printer.success("File copied: #{source} -> #{destination}")
        {:ok, destination}

      {:error, reason} ->
        Printer.error("Failed to copy file: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Elimina un archivo o directorio de forma segura.

  ## Examples

      Ark.Pathy.remove_path("/path/to/remove")

  """
  def remove_path(path) do
    if File.exists?(path) do
      case File.rm_rf(path) do
        {:ok, removed_files} ->
          Printer.success("Removed #{length(removed_files)} files/directories")
          {:ok, removed_files}

        {:error, reason, _file} ->
          Printer.error("Failed to remove #{path}: #{reason}")
          {:error, reason}
      end
    else
      Printer.warning("Path #{path} does not exist")
      {:ok, []}
    end
  end

  @doc """
  Devuelve los últimos `n` niveles de un path.

  ## Examples

      iex> Ark.Pathy.get_relative_n_levels_path("/a/b/c/d/e/f", 3)
      "d/e/f"
  """
  def get_relative_n_levels_path(path, n \\ 4) do
    path
    |> Path.split()
    |> Enum.reverse()
    |> Enum.take(n)
    |> Enum.reverse()
    |> Path.join()
  end

  @doc """
  Construye un árbol (mapa anidado) a partir de una lista de rutas.

  ## Examples

      iex> Ark.Pathy.build_tree(["a/b/c", "a/b/d", "a/x"])
      %{"a" => %{"b" => %{"c" => %{}, "d" => %{}}, "x" => %{}}}
  """
  def build_tree(paths) do
    paths
    |> Enum.reject(&(&1 in [nil, "", []]))
    |> Enum.map(fn
      path when is_binary(path) -> String.split(path, "/")
      path when is_list(path) -> path
    end)
    |> Enum.reduce(%{}, &insert_path/2)
  end

  @doc """
  Inserta una ruta (lista de segmentos) dentro de un árbol ya existente.
  """
  def insert_path([], tree), do: tree

  def insert_path([head | tail], tree) do
    Map.update(tree, head, build_tree([tail]), fn sub ->
      insert_path(tail, sub)
    end)
  end

  @doc """
  Elimina el prefijo común de una ruta, devolviendo la parte relativa.

  ## Examples

      iex> Ark.Pathy.strip_prefix("/home/user/docs/file.txt", "/home/user")
      "docs/file.txt"
  """
  def strip_prefix(path, prefix) do
    path
    |> String.replace_prefix(prefix, "")
    |> String.trim_leading("/")
    |> case do
      "" -> nil
      clean -> clean
    end
  end

  @doc """
  Calcula el prefijo común más largo entre varias rutas.

  ## Examples

      iex> Ark.Pathy.common_prefix(["/home/user/docs", "/home/user/projects"])
      "/home/user"
  """
  def common_prefix(paths) do
    paths
    |> Enum.map(&String.split(&1, "/"))
    |> Enum.reduce(fn path, acc ->
      Enum.zip(acc, path)
      |> Enum.take_while(fn {a, b} -> a == b end)
      |> Enum.map(fn {a, _} -> a end)
    end)
    |> Enum.reject(&(&1 == ""))
    |> then(&("/" <> Enum.join(&1, "/")))
  end

  @doc """
  Añade una línea a un archivo solo si no existe ya.

  ## Examples

      iex> Ark.Pathy.append_unless_exists("export PATH=/usr/local/bin:$PATH", "~/.bashrc")
      {:ok, :appended}

  """
  def append_unless_exists(new_line, file) do
    case File.read(file) do
      {:ok, content} ->
        if String.contains?(content, new_line) do
          {:skipped, "Line already exists"}
        else
          case File.write(file, "\n" <> new_line, [:append]) do
            :ok -> {:ok, :appended}
            {:error, reason} -> {:error, reason}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
