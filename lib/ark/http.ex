defmodule Ark.HTTP do
  @moduledoc """
  Cliente HTTP con autenticación automática.

  Proporciona un cliente HTTP simplificado con manejo de autenticación,
  tokens y configuración automática para APIs externas.

  ## Características

  - 🔐 Autenticación automática con tokens
  - 📞 Cliente HTTP con manejo de errores
  - ⚙️  Configuración flexible de parámetros
  - 🔄 Renovación automática de tokens
  - 📊 Logging integrado de requests
  - ✅ Validación de URLs y parámetros
  """
  require Logger

  alias Aegis.Printer
  alias Ark.Tools

  @token_url Application.compile_env(:ark, :config)[:token_url]
  @token_params Application.compile_env(:ark, :config)[:token_params]

  @doc """
  Llama a la API con opciones básicas.
  """
  def call(opts \\ []) do
    show_time = Keyword.get(opts, :show_time, false)
    start = start_time(show_time)

    response =
      opts
      |> Keyword.get(:url)
      |> valid_opts?(opts)
      |> prepare_params()
      |> Req.request()
      |> process_response()

    stop_time(show_time, start)

    response
  end

  @doc """
  Llama a la API usando token automático.

  - Si existe variable de entorno JSON (ej: GITHUB_TOKEN_JSON) se usa como headers.
  - Si no existe, se usa el token de @token_url (tu método original).
  """
  def call_with_login(opts \\ []) do
    token_headers =
      "ARK_TOKEN_PARAMS"
      |> Tools.decode_env(Application.get_env(:ark, :token_config)[:token_params])
      |> case do
        nil -> %{"Authorization" => "Bearer #{get_token()}"}
        %{} = map -> map
        _ -> %{}
      end

    call(Keyword.put(opts, :token, token_headers))
  end

  defp get_token do
    case call(url: @token_url, method: :post, params: @token_params) do
      {:ok, _status, %{"token" => token}} when is_binary(token) ->
        token

      other ->
        Logger.error("Error obteniendo token: #{inspect(other)}")
        {:error, {:token_fetch_failed, other}}
    end
  end

  defp valid_opts?(url, opts) do
    method = opts |> Keyword.get(:method, :get) |> normalize_method()
    params = Keyword.get(opts, :params, %{})
    show_time = Keyword.get(opts, :show_time, false)

    validations = [
      valid_url: valid_url?(url),
      valid_method: valid_method?(method),
      valid_params: valid_params?(params),
      valid_show_time: valid_show_time?(show_time)
    ]

    if Enum.all?(validations, fn {_k, v} -> v end) do
      {:ok, url, opts}
    else
      get_errors(validations)
    end
  end

  defp normalize_method(m) when is_atom(m), do: m

  defp normalize_method(m) when is_binary(m) do
    String.to_existing_atom(String.downcase(m))
  rescue
    _ -> :ark
  end

  defp normalize_method(_), do: :ark

  defp valid_url?(url) when is_binary(url) and byte_size(url) > 0 do
    # Limitar longitud de URL para prevenir ataques
    if byte_size(url) > 2048 do
      false
    else
      uri = URI.parse(url)
      valid_scheme = uri.scheme in ["http", "https"]
      valid_host = is_binary(uri.host) and String.length(uri.host) > 0
      # Prevenir URLs locales maliciosas
      not_localhost =
        not String.starts_with?(uri.host || "", ["127.", "localhost", "0.0.0.0", "[::"])

      valid_scheme and valid_host and not_localhost
    end
  end

  defp valid_url?(_), do: false

  defp valid_method?(method) when method in [:get, :post, :patch, :put, :delete], do: true
  defp valid_method?(_), do: false

  defp valid_params?(%{} = params),
    do:
      Enum.all?(params, fn
        {k, _v} when is_atom(k) -> true
        _ -> false
      end)

  defp valid_params?(_), do: false

  defp valid_show_time?(show_time) when is_boolean(show_time), do: true
  defp valid_show_time?(_), do: false

  defp get_errors(validations) do
    validations
    |> Enum.reject(fn {_k, v} -> v end)
    |> Enum.map(fn {k, _} -> k end)
    |> then(&{:error, &1})
  end

  defp prepare_params({:error, errors}) do
    error_message = "Error en la llamada: #{inspect(errors)}"
    Logger.error(error_message)
    raise error_message
  end

  defp prepare_params({:ok, url, opts}) do
    method = Keyword.get(opts, :method, :get)

    [url: url, method: method]
    |> prepare_headers(opts)
    |> prepare_payload(method)
  end

  defp prepare_headers(params, opts) do
    headers = Keyword.get(opts, :headers, %{})

    token_headers =
      Keyword.get(opts, :token, %{})
      |> case do
        %{} = map -> map
        _ -> %{}
      end

    token_headers
    |> Map.merge(headers)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into([])
    |> Enum.concat(params)
  end

  defp prepare_payload(params, method) when method in [:post, :put, :patch] do
    Keyword.put(params, :json, Keyword.get(params, :body, %{}))
  end

  defp prepare_payload(params, _), do: params

  defp process_response({:ok, %Req.Response{} = resp}) do
    %{status: status, body: body} = resp
    {:ok, status, body}
  end

  defp process_response({:error, reason}), do: {:error, reason}

  defp start_time(true), do: System.monotonic_time(:millisecond)
  defp start_time(false), do: System.monotonic_time(:millisecond)

  defp stop_time(true, start) do
    elapsed = System.monotonic_time(:millisecond) - start
    Printer.info("⏱️ Execution time: #{elapsed}ms")
  end

  defp stop_time(false, _start), do: nil
end
