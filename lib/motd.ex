defmodule Ark.Motd do
  @moduledoc """
  Generación de MOTD (Message of the Day) y información del sistema para Ark.

  Proporciona funcionalidades para mostrar información completa del sistema,
  incluyendo hardware, software, red y estado general.

  ## Características

  - 🖥️  Información de hardware y sistema operativo
  - 💾 Estado de memoria y almacenamiento
  - 🌐 Información de red y conectividad
  - 🔋 Estado de batería (en portátiles)
  - 🌤️  Información meteorológica opcional
  - 🎨 Formateo hermoso con colores y layouts

  Construido sobre:
  - Aurora (1A): Sistema de colores y formateo
  - Argos (1B): Sistema de ejecución y orquestación
  - Printer (2): Framework CLI/TUI completo
  """
  alias Argos.Command

  alias Aegis.{Printer, Terminal}
  alias Aurora.Color
  alias Aurora.Structs.ChunkText

  @doc """
  Muestra información completa del sistema.

  ## Options

    * `:layout` - Layout del MOTD (`:full`, `:compact`) - default: `:full`
    * `:weather` - Incluir información del clima - default: `true`
    * `:network` - Incluir información de red - default: `true`

  ## Examples

      Ark.Motd.info()
      Ark.Motd.info(layout: :compact, weather: false)

  """
  def info(opts \\ []) do
    layout = Keyword.get(opts, :layout, :full)
    _weather = Keyword.get(opts, :weather, true)
    _network = Keyword.get(opts, :network, true)

    case layout do
      :compact -> show_compact_info()
      _ -> show_full_info()
    end
  end

  @doc """
  Alias para info/1 para compatibilidad.
  """
  def show(opts \\ []), do: info(opts)

  defp show_full_info do
    Terminal.clear_screen()

    # Header with logo
    Printer.logo_with_data()

    # System information sections
    show_system_section()
    show_memory_section()
    show_network_section()
    show_time_section()

    Printer.separator([])
  end

  defp show_compact_info do
    Printer.header("System Info - Ark")

    info_chunks = [
      %ChunkText{text: "🖥️  ", color: Color.get_color_info(:primary)},
      %ChunkText{text: get_hostname(), color: Color.get_color_info(:secondary)},
      %ChunkText{text: " | ", color: Color.get_color_info(:no_color)},
      %ChunkText{text: "💾 ", color: Color.get_color_info(:primary)},
      %ChunkText{text: get_memory_usage(), color: Color.get_color_info(:ternary)},
      %ChunkText{text: " | ", color: Color.get_color_info(:no_color)},
      %ChunkText{text: "⏰ ", color: Color.get_color_info(:primary)},
      %ChunkText{text: get_current_time(), color: Color.get_color_info(:info)}
    ]

    Printer.message(chunks: info_chunks)
  end

  defp show_system_section do
    Printer.header("Sistema")

    system_info = [
      {"Hostname", get_hostname()},
      {"OS", get_os_info()},
      {"Uptime", get_uptime()},
      {"Load", get_load_average()}
    ]

    display_info_table(system_info)
  end

  defp show_memory_section do
    Printer.header("Memoria")

    memory_info = [
      {"Usage", get_memory_usage()},
      {"Disk", get_disk_usage()}
    ]

    display_info_table(memory_info)
  end

  defp show_network_section do
    Printer.header("Red")

    network_info = [
      {"IP Local", get_local_ip()},
      {"IP Externa", get_external_ip()},
      {"Conectividad", get_connectivity_status()}
    ]

    display_info_table(network_info)
  end

  defp show_time_section do
    Printer.header("Tiempo")

    time_info = [
      {"Fecha/Hora", get_current_time()},
      {"Zona horaria", get_timezone()}
    ]

    display_info_table(time_info)
  end

  defp display_info_table(info_list) do
    Enum.each(info_list, fn {label, value} ->
      chunks = [
        %ChunkText{text: "  #{label}: ", color: Color.get_color_info(:primary)},
        %ChunkText{text: value, color: Color.get_color_info(:secondary)}
      ]

      Printer.message(chunks: chunks)
    end)

    # Empty line
    Printer.info("")
  end

  # System information getters

  defp get_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "unknown"
    end
  end

  defp get_os_info do
    case :os.type() do
      {:unix, :darwin} -> "macOS #{get_macos_version()}"
      {:unix, :linux} -> "Linux #{get_linux_version()}"
      {:win32, _} -> "Windows"
      _ -> "Unknown OS"
    end
  end

  defp get_macos_version do
    result = Argos.Command.exec("sw_vers -productVersion")
    if result.success?, do: String.trim(result.output), else: "Unknown"
  end

  defp get_linux_version do
    result = Argos.Command.exec("lsb_release -d")

    if result.success? do
      result.output
      |> String.replace("Description:", "")
      |> String.trim()
    else
      "Unknown"
    end
  end

  defp get_uptime do
    result = Argos.Command.exec("uptime")

    if result.success? do
      result.output
      |> String.split(",")
      |> List.first()
      |> String.replace("up ", "")
      |> String.trim()
    else
      "Unknown"
    end
  end

  defp get_load_average do
    result = Argos.Command.exec("uptime")

    if result.success? do
      result.output
      |> String.split("load average:")
      |> List.last()
      |> String.trim()
    else
      "Unknown"
    end
  end

  defp get_memory_usage do
    case :os.type() do
      {:unix, :darwin} -> get_memory_usage_macos()
      {:unix, :linux} -> get_memory_usage_linux()
      _ -> "Unknown"
    end
  end

  defp get_memory_usage_macos do
    result = Argos.Command.exec("memory_pressure")

    if result.success? and String.contains?(result.output, "normal") do
      "Normal"
    else
      "Unknown"
    end
  end

  defp get_memory_usage_linux do
    result = Argos.Command.exec("free -h")

    if result.success? do
      result.output
      |> String.split("\n")
      |> Enum.at(1, "")
      |> String.split()
      |> Enum.at(2, "Unknown")
    else
      "Unknown"
    end
  end

  defp get_disk_usage do
    result = Argos.Command.exec("df -h /")

    if result.success? do
      result.output
      |> String.split("\n")
      |> Enum.at(1, "")
      |> String.split()
      |> Enum.at(4, "Unknown")
    else
      "Unknown"
    end
  end

  defp get_local_ip do
    result =
      case :os.type() do
        {:unix, :darwin} ->
          Argos.Command.exec("ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}'")

        {:unix, :linux} ->
          Argos.Command.exec("hostname -I | awk '{print $1}'")

        _ ->
          %{success?: false}
      end

    if result.success?, do: String.trim(result.output), else: "Unknown"
  end

  defp get_external_ip do
    result = Argos.Command.exec("curl -s ifconfig.me")
    if result.success?, do: String.trim(result.output), else: "Unknown"
  end

  defp get_connectivity_status do
    result = Argos.Command.exec("ping -c 1 8.8.8.8")
    if result.success?, do: "✅ Online", else: "❌ Offline"
  end

  defp get_current_time do
    DateTime.now!("Etc/UTC")
    |> DateTime.shift_zone!(get_timezone())
    |> DateTime.to_string()
  rescue
    _error ->
      # Fallback to UTC if timezone shifting fails
      DateTime.now!("Etc/UTC")
      |> DateTime.to_string()
  end

  defp get_timezone do
    case :os.type() do
      {:unix, _} ->
        result = Argos.Command.exec("date +%Z")
        if result.success?, do: String.trim(result.output), else: "UTC"

      _ ->
        "UTC"
    end
  end
end
