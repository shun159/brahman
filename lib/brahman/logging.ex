defmodule Brahman.Logging do
  @moduledoc """
  Logging utility macros
  """

  defmacro __using__(_which) do
    quote location: :keep do
      require Logger

      @spec logging(Logger.level(), term()) :: :ok
      defp logging(level, key), do: Logger.log(level, log_descr(key))

      @spec log_descr(tuple() | atom()) :: function()
      defp log_descr({:observing_success, success, measurement}),
        do: fn -> "Observing connection success: #{success} with time of #{measurement} ms" end

      defp log_descr(:pending_connection_is_zero),
        do: fn -> "Call to decrement connections for backend when pending connections == 0" end

      defp log_descr({:decode_error, packet}),
        do: fn -> "Undecodable packet given: packet = #{inspect(packet)}" end

      defp log_descr(:no_upstreams_available),
        do: fn -> "No upstream available" end

      defp log_descr({:upstream_reply, {{ip, port}, _}, tdiff}),
        do: fn -> "Received reply from #{:inet.ntoa(ip)}:#{port} in #{tdiff / 1000} msec" end

      defp log_descr({:upstream_down, {{ip, port}, _}}),
        do: fn -> "Upstream #{:inet.ntoa(ip)}:#{port} DOWN" end

      defp log_descr({:upstream_timeout, {{ip, port}, _}}),
        do: fn -> "Upstream #{:inet.ntoa(ip)}:#{port} TIMEOUT" end

      defp log_descr({:query_timeout, name}),
        do: fn -> "Query Timeout name = #{name}" end
    end
  end
end
