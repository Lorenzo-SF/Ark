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
  - Aegis (2): Framework CLI/TUI completo
  """

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
    Aegis.clear_screen()

    # Header with logo
    Aegis.Printer.logo_with_data()

    # System information sections
    show_system_section()
    show_memory_section()
    show_network_section()
    show_time_section()

    Aegis.separator(color: :primary)
  end

  defp show_compact_info do
    Aegis.semiheader("System Info - Ark", color: :primary)

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

    Aegis.message(chunks: info_chunks, align: :center)
  end

  defp show_system_section do
    Aegis.semiheader("Sistema", color: :info)

    system_info = [
      {"Hostname", get_hostname()},
      {"OS", get_os_info()},
      {"Uptime", get_uptime()},
      {"Load", get_load_average()}
    ]

    display_info_table(system_info)
  end

  defp show_memory_section do
    Aegis.semiheader("Memoria", color: :warning)

    memory_info = [
      {"Usage", get_memory_usage()},
      {"Disk", get_disk_usage()}
    ]

    display_info_table(memory_info)
  end

  defp show_network_section do
    Aegis.semiheader("Red", color: :success)

    network_info = [
      {"IP Local", get_local_ip()},
      {"IP Externa", get_external_ip()},
      {"Conectividad", get_connectivity_status()}
    ]

    display_info_table(network_info)
  end

  defp show_time_section do
    Aegis.semiheader("Tiempo", color: :ternary)

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
      Aegis.message(chunks: chunks, align: :left)
    end)

    Aegis.message(message: "", add_line: :none)  # Empty line
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
    result = Argos.exec_command("sw_vers -productVersion")
    if result.success?, do: String.trim(result.output), else: "Unknown"
  end

  defp get_linux_version do
    result = Argos.exec_command("lsb_release -d")
    if result.success? do
      result.output
      |> String.replace("Description:", "")
      |> String.trim()
    else
      "Unknown"
    end
  end

  defp get_uptime do
    result = Argos.exec_command("uptime")
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
    result = Argos.exec_command("uptime")
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
    result = Argos.exec_command("memory_pressure")
    if result.success? and String.contains?(result.output, "normal") do
      "Normal"
    else
      "Unknown"
    end
  end

  defp get_memory_usage_linux do
    result = Argos.exec_command("free -h")
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
    result = Argos.exec_command("df -h /")
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
    result = case :os.type() do
      {:unix, :darwin} ->
        Argos.exec_command("ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}'")
      {:unix, :linux} ->
        Argos.exec_command("hostname -I | awk '{print $1}'")
      _ ->
        %{success?: false}
    end

    if result.success?, do: String.trim(result.output), else: "Unknown"
  end

  defp get_external_ip do
    result = Argos.exec_command("curl -s ifconfig.me")
    if result.success?, do: String.trim(result.output), else: "Unknown"
  end

  defp get_connectivity_status do
    result = Argos.exec_command("ping -c 1 8.8.8.8")
    if result.success?, do: "✅ Online", else: "❌ Offline"
  end

  defp get_current_time do
    DateTime.now!("Etc/UTC")
    |> DateTime.shift_zone!(get_timezone())
    |> DateTime.to_string()
  end

  defp get_timezone do
    case :os.type() do
      {:unix, _} ->
        result = Argos.exec_command("date +%Z")
        if result.success?, do: String.trim(result.output), else: "UTC"
      _ ->
        "UTC"
    end
  end
end
