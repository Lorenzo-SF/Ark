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
  alias Aegis.{Animation, Printer}
  alias Aurora.Color
  alias Aurora.Structs.ChunkText

  def install_packages(packages, preupdate \\ true) do
    Printer.header(
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
        Printer.error("No compatible package manager found (brew or apt required)")
        Argos.Command.halt(1)
    end
  end

  defp update_system(pkg_manager) do
    Printer.semiheader("Actualizando el sistema")

    Animation.start([
      %ChunkText{
        text: "Actualizando",
        color: Color.get_color_info(:ternary)
      }
    ])

    case pkg_manager do
      :brew ->
        Argos.Command.exec("brew update")
        Argos.Command.exec("brew upgrade")

      :apt ->
        result1 = Argos.Command.exec_sudo("apt update")
        result2 = Argos.Command.exec_sudo("apt upgrade -y")

        if not result1.success? or not result2.success? do
          Printer.error("Error actualizando el sistema")
          Argos.Command.halt(1)
        end
    end

    Animation.stop(:default)
    Printer.success("Sistema actualizado con éxito")
  end

  defp install_package_list(packages, pkg_manager) do
    Printer.semiheader("Instalando paquetes")

    Enum.each(packages, fn package ->
      install_single_package(package, pkg_manager)
    end)
  end

  defp install_single_package(package, pkg_manager) do
    Animation.start([
      %ChunkText{
        text: "Instalando #{package}",
        color: Color.get_color_info(:ternary)
      }
    ])

    installed? = package_installed?(package, pkg_manager)

    if installed? do
      Animation.stop(:default)
      Printer.info("#{package} ya está instalado")
    else
      result =
        case pkg_manager do
          :brew ->
            Argos.Command.exec("brew install #{package}")

          :apt ->
            Argos.Command.exec_sudo("apt install -y #{String.replace(package, "--cask", "")}")
        end

      Animation.stop(:default)

      if result.success? do
        Printer.success("#{package} instalado con éxito")
      else
        Printer.error("Error instalando #{package}: #{result.output}")
      end
    end
  end

  def package_installed?(package, :apt) do
    result = Argos.Command.exec("dpkg -s #{package}", stderr_to_stdout: true)
    result.exit_code == 0 and String.contains?(result.output, "Status: install ok installed")
  rescue
    _ -> false
  end

  def package_installed?(package, :brew) do
    result = Argos.Command.exec("brew list #{package}")
    result.success?
  end

  def unless_installed?(cmd, question) do
    if System.find_executable(cmd) do
      Printer.yesno(question) == :yes
    else
      true
    end
  end
end
