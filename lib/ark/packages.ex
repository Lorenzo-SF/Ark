defmodule Ark.Packages do
  @moduledoc """
  Instalación automática de paquetes del sistema para Ark.

  Proporciona funcionalidades para detectar el gestor de paquetes del sistema
  e instalar software de forma automática y multiplataforma.

  ## Características

  - 📦 Detección automática del gestor (apt, yum, brew, etc.)
  - 🔄 Actualización de cache antes de instalar
  - ✅ Verificación de paquetes ya instalados
  - 🤔 Confirmación interactiva para instalaciones
  - 🖥️  Soporte multiplataforma (Linux, macOS)
  - 📋 Instalación por lotes de múltiples paquetes

  Construido sobre:
  - Aurora (1A): Sistema de colores y formateo
  - Argos (1B): Sistema de ejecución y orquestación
  - Aegis (2): Framework CLI/TUI completo
  """

  alias Aurora.Color
  alias Aurora.Structs.ChunkText

  def install_packages(packages, preupdate \\ true) do
    Aegis.header(
      ["Ark", "Instalación de paquetes y preparación de entorno"],
      color: :primary,
      align: :center
    )

    pkg_manager = detect_package_manager()

    if preupdate do
      update_system(pkg_manager)
    end

    install_package_list(packages, pkg_manager)
  end

  defp detect_package_manager do
    cond do
      System.find_executable("brew") ->
        :brew

      System.find_executable("apt") ->
        :apt

      true ->
        Aegis.error("No compatible package manager found (brew or apt required)")
        Argos.halt(1)
    end
  end

  defp update_system(pkg_manager) do
    Aegis.semiheader("Actualizando el sistema")

    Aegis.start_animation([
      %ChunkText{
        text: "Actualizando",
        color: Color.get_color_info(:ternary)
      }
    ])

    case pkg_manager do
      :brew ->
        Argos.exec_command("brew update")
        Argos.exec_command("brew upgrade")

      :apt ->
        result1 = Argos.exec_sudo("apt update")
        result2 = Argos.exec_sudo("apt upgrade -y")

        if not result1.success? or not result2.success? do
          Aegis.error("Error actualizando el sistema")
          Argos.halt(1)
        end
    end

    Aegis.stop_animation()
    Aegis.success("Sistema actualizado con éxito")
  end

  defp install_package_list(packages, pkg_manager) do
    Aegis.semiheader("Instalando paquetes")

    Enum.each(packages, fn package ->
      install_single_package(package, pkg_manager)
    end)
  end

  defp install_single_package(package, pkg_manager) do
    Aegis.start_animation([
      %ChunkText{
        text: "Instalando #{package}",
        color: Color.get_color_info(:ternary)
      }
    ])

    installed? = package_installed?(package, pkg_manager)

    if installed? do
      Aegis.stop_animation()
      Aegis.info("#{package} ya está instalado")
    else
      result = case pkg_manager do
        :brew ->
          Argos.exec_command("brew install #{package}")
        :apt ->
          Argos.exec_sudo("apt install -y #{String.replace(package, "--cask", "")}")
      end

      Aegis.stop_animation()

      if result.success? do
        Aegis.success("#{package} instalado con éxito")
      else
        Aegis.error("Error instalando #{package}: #{result.output}")
      end
    end
  end

  def package_installed?(package, :apt) do
    {output, exit_code} = System.cmd("dpkg", ["-s", package], stderr_to_stdout: true)
    exit_code == 0 and String.contains?(output, "Status: install ok installed")
  rescue
    _ -> false
  end

  def package_installed?(package, :brew) do
    result = Argos.exec_command("brew list #{package}")
    result.success?
  end

  def unless_installed?(cmd, question) do
    if System.find_executable(cmd) do
      Aegis.yesno(question) == :yes
    else
      true
    end
  end
end
