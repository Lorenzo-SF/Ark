defmodule Ark.Weather do
  @moduledoc """
  Información meteorológica integrada.

  Proporciona funcionalidades para obtener y mostrar información del clima
  desde servicios meteorológicos externos con formato visual atractivo.

  ## Características

  - 🌤️  Información actual del clima por ubicación
  - 🌡️  Temperatura y condiciones atmosféricas
  - 💧 Probabilidad de precipitación por horarios
  - 💨 Velocidad y dirección del viento
  - 🎨 Iconos emoji para condiciones climáticas
  - ⏰ Predicciones por franjas horarias
  - 📍 Soporte para múltiples ubicaciones
  """

  import SweetXml

  alias Ark.Http
  alias Aurora.Color
  alias Aurora.Structs.ChunkText

  @doc """
  Obtiene la información meteorológica del día actual.

  ## Parameters

    * `url` - URL del servicio meteorológico XML

  ## Returns

  Lista de chunks de texto formateados para mostrar el clima,
  o mensaje de "Sin datos disponibles" si hay error.

  ## Examples

      Weather.get_today("https://servicio-clima.es/prediccion.xml")
      # => [[%ChunkText{text: "Madrid (Madrid)", color: ...}], ...]

  """
  @spec get_today(String.t() | nil) :: [list()]
  def get_today(url) do
    url
    |> load_today()
    |> process_today()
  end

  defp load_today(url) when is_nil(url) or (is_binary(url) and byte_size(url) == 0), do: ""

  defp load_today(url) do
    response =
      [url: url, method: :get]
      |> Http.call()
      |> elem(2)

    localidad = xpath(response, ~x"//nombre/text()"s)
    provincia = xpath(response, ~x"//provincia/text()"s)

    datos =
      xpath(
        response,
        ~x"//dia"l,
        fecha: ~x"./@fecha"s,
        estados: [
          ~x"./estado_cielo"l,
          periodo: ~x"./@periodo"s,
          descripcion: ~x"./@descripcion"s,
          valor: ~x"./text()"s
        ],
        precipitaciones: [
          ~x"./prob_precipitacion"l,
          periodo: ~x"./@periodo"s,
          valor: ~x"./text()"s
        ],
        vientos: [
          ~x"./viento"l,
          periodo: ~x"./@periodo"s,
          velocidad: ~x"./velocidad/text()"s
        ]
      )

    {localidad, provincia, datos}
  end

  defp process_today(""),
    do: [[%ChunkText{text: "Sin datos disponibles", color: Color.get_color_info(:secondary)}]]

  defp process_today({_localidad, _provincia, []}),
    do: [[%ChunkText{text: "Sin datos disponibles", color: Color.get_color_info(:secondary)}]]

  defp process_today({localidad, provincia, datos}) do
    hoy = Date.utc_today() |> Date.to_string()
    hora_actual = Time.utc_now().hour

    case Enum.find(datos, fn %{fecha: fecha} -> fecha == hoy end) do
      %{estados: estados, precipitaciones: precipitaciones, vientos: vientos} ->
        sky = sky(estados, hora_actual)
        precipitacion = rain(precipitaciones, hora_actual)
        viento = wind(vientos, hora_actual)

        sky_icon = sky_icon(sky)
        rain_icon = rain_icon(precipitacion)
        wind_icon = wind_icon(viento)

        [
          [
            %ChunkText{text: "#{localidad} (#{provincia})", color: Color.get_color_info(:ternary)}
          ],
          [%ChunkText{text: sky <> " " <> sky_icon, color: Color.get_color_info(:no_color)}],
          [
            %ChunkText{
              text: "Prob. precipitacion: #{precipitacion}% " <> rain_icon,
              color: Color.get_color_info(:primary)
            }
          ],
          [
            %ChunkText{
              text: "Viento: #{viento} km/h " <> wind_icon,
              color: Color.get_color_info(:no_color_alternative)
            }
          ]
        ]

      _ ->
        [[%ChunkText{text: "Sin datos disponibles", color: Color.get_color_info(:secondary)}]]
    end
  end

  defp sky(estados, hora_actual) do
    estados
    |> Enum.reject(fn %{periodo: periodo} ->
      periodo in ["00-24", "00-12", "12-24"]
    end)
    |> Enum.find(fn %{periodo: periodo} ->
      case String.split(periodo, "-") do
        [inicio, fin] ->
          inicio = String.to_integer(inicio)
          fin = String.to_integer(fin)
          hora_actual >= inicio and hora_actual < fin

        _ ->
          false
      end
    end)
    |> Map.get(:descripcion, "Sin información disponible")
  end

  defp rain(precipitaciones, hora_actual) do
    precipitaciones
    |> Enum.reject(fn %{periodo: periodo} ->
      periodo in ["00-24", "00-12", "12-24"]
    end)
    |> Enum.find(fn %{periodo: periodo} ->
      case String.split(periodo, "-") do
        [inicio, fin] ->
          inicio = String.to_integer(inicio)
          fin = String.to_integer(fin)
          hora_actual >= inicio and hora_actual < fin

        _ ->
          false
      end
    end)
    |> case do
      nil -> 0
      %{valor: ""} -> 0
      %{valor: valor} -> String.to_integer(valor)
    end
  end

  defp wind(vientos, hora_actual) do
    vientos
    |> Enum.reject(fn %{periodo: periodo} ->
      periodo in ["00-24", "00-12", "12-24"]
    end)
    |> Enum.find(fn %{periodo: periodo} ->
      case String.split(periodo, "-") do
        [inicio, fin] ->
          inicio = String.to_integer(inicio)
          fin = String.to_integer(fin)
          hora_actual >= inicio and hora_actual < fin

        _ ->
          false
      end
    end)
    |> case do
      nil -> 0
      %{velocidad: ""} -> 0
      %{velocidad: velocidad} -> String.to_integer(velocidad)
    end
  end

  defp sky_icon("Despejado"), do: "☀️ "
  defp sky_icon("Poco nuboso"), do: "🌤️ "
  defp sky_icon("Intervalos nubosos"), do: "⛅ "
  defp sky_icon("Nuboso"), do: "🌥️ "
  defp sky_icon("Muy nuboso"), do: "☁️ "
  defp sky_icon("Cubierto"), do: "☁️ "
  defp sky_icon("Nubes altas"), do: "🌤️ "
  defp sky_icon("Nuboso con lluvia escasa"), do: "🌦️ "
  defp sky_icon("Intervalos nubosos con lluvia"), do: "🌦️ "
  defp sky_icon("Muy nuboso con lluvia"), do: "🌦️ "
  defp sky_icon("Chubascos"), do: "🌧️ "
  defp sky_icon("Lluvia"), do: "🌧️ "
  defp sky_icon("Nieve"), do: "❄️ "
  defp sky_icon("Tormenta"), do: "⛈️ "
  defp sky_icon("Bruma"), do: "🌫️ "
  defp sky_icon("Niebla"), do: "🌫️ "
  defp sky_icon(_), do: "❓"

  defp rain_icon(0), do: "🌵 "
  defp rain_icon(valor) when valor <= 30, do: "🌦️ "
  defp rain_icon(valor) when valor <= 70, do: "🌧️ "
  defp rain_icon(_), do: "⛈️ "

  defp wind_icon(velocidad) when velocidad < 10, do: "🍃 "
  defp wind_icon(velocidad) when velocidad < 30, do: "🌬️ "
  defp wind_icon(velocidad) when velocidad < 60, do: "💨 "
  defp wind_icon(_velocidad), do: "🌪️ "
end
