defmodule Ark.Ssh do
  @moduledoc """
  Gestión de llaves SSH para Ark.

  Proporciona utilidades para generar, gestionar y configurar llaves SSH
  de forma automatizada con los permisos y configuraciones correctas.

  ## Características

  - 🔐 Generación automática de llaves RSA 4096-bit
  - 📁 Configuración automática de directorio ~/.ssh
  - 🔒 Establecimiento correcto de permisos (600/644)
  - 📋 Listado de llaves disponibles
  - ✅ Verificación de llaves existentes
  - 🖥️  Mostrado de llave pública para configuración

  Construido sobre:
  - Aurora (1A): Sistema de colores y formateo
  - Argos (1B): Sistema de ejecución y orquestación
  - Aegis (2): Framework CLI/TUI completo
  """

  require Logger

  @doc """
  Creates SSH keys if they don't exist.
  """
  def create do
    Logger.info("Setting up SSH keys...")

    ssh_dir = Application.get_env(:ark, :ssh)[:ssh_path] || Path.expand("~/.ssh")
    ssh_name = Application.get_env(:ark, :ssh)[:ssh_name] || "id_rsa"

    key_path = Path.join(ssh_dir, ssh_name)

    # Ensure SSH directory exists
    File.mkdir_p(ssh_dir)

    case File.exists?(key_path) do
      false ->
        Logger.info("Generating new SSH key...")
        result = Argos.exec_command("ssh-keygen -t rsa -b 4096 -f #{key_path} -N \"\"")

        if result.success? do
          Logger.info("SSH key generated successfully")

          # Set proper permissions
          Argos.exec_command("chmod 600 #{key_path}")
          Argos.exec_command("chmod 644 #{key_path}.pub")

          # Display public key
          case File.read("#{key_path}.pub") do
            {:ok, pub_key} ->
              Logger.info("Your public key:")
              Aegis.warning(pub_key)

            {:error, _} ->
              Logger.warning("Could not read public key")
          end
        else
          Logger.error("Failed to generate SSH key: #{result.output}")
        end

      true ->
        Logger.info("SSH key already exists")
    end
  end

  @doc """
  Ensures default SSH key exists.
  """
  def ensure_default_key do
    ssh_dir = Application.get_env(:ark, :ssh)[:ssh_path] || Path.expand("~/.ssh")
    ssh_name = Application.get_env(:ark, :ssh)[:ssh_name] || "id_rsa"
    key_path = Path.join(ssh_dir, ssh_name)

    unless File.exists?(key_path) do
      create()
    end
  end

  @doc """
  Lists available SSH keys.
  """
  def list_keys do
    ssh_dir = Path.expand("~/.ssh")

    case Path.wildcard(Path.join(ssh_dir, "*.pub")) do
      [] ->
        Logger.info("No SSH keys found")
        []

      keys ->
        Logger.info("Found SSH keys:")

        keys
        |> Enum.map(fn key_path ->
          key_name = Path.basename(key_path, ".pub")
          Logger.info("  - #{key_name}")
          key_name
        end)
    end
  end

  @doc """
  Shows the public key content for a specific key.
  """
  def show_public_key(key_name \\ "id_rsa") do
    ssh_dir = Path.expand("~/.ssh")
    pub_key_path = Path.join(ssh_dir, "#{key_name}.pub")

    case File.read(pub_key_path) do
      {:ok, content} ->
        Aegis.info("Public key for #{key_name}:")
        Aegis.message(message: String.trim(content), color: :success)
        {:ok, content}

      {:error, reason} ->
        Aegis.error("Could not read public key #{key_name}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Copies public key to clipboard (macOS).
  """
  def copy_public_key(key_name \\ "id_rsa") do
    ssh_dir = Path.expand("~/.ssh")
    pub_key_path = Path.join(ssh_dir, "#{key_name}.pub")

    if File.exists?(pub_key_path) do
      result = Argos.exec_command("pbcopy < #{pub_key_path}")
      if result.success? do
        Aegis.success("Public key #{key_name} copied to clipboard")
        :ok
      else
        Aegis.error("Failed to copy public key to clipboard")
        {:error, :copy_failed}
      end
    else
      Aegis.error("Public key #{key_name} not found")
      {:error, :not_found}
    end
  end
end
