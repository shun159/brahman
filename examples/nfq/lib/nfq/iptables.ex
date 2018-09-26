defmodule NFQ.IPTables do
  @moduledoc """
  Wrapper for iptables
  """

  @default_table :filter

  @typep chain :: :prerouting | :input | :forward | :output | :postrouting | atom()
  @typep table :: :filter | :nat | :mangle | :raw | :security

  @spec append(chain(), String.t()) :: :ok | {:error, term()}
  def append(chain, rule, table \\ @default_table)

  @spec append(chain(), String.t(), table()) :: :ok | {:error, term()}
  def append(chain, rule, table),
    do: exec_iptables("-t #{table} --append #{String.upcase(to_string(chain))} #{rule}")

  @spec check(chain(), String.t()) :: :ok | {:error, term()}
  def check(chain, rule, table \\ @default_table)

  @spec check(chain(), String.t(), table()) :: :ok | {:error, term()}
  def check(chain, rule, table),
    do: exec_iptables("-t #{table} --check #{String.upcase(to_string(chain))} #{rule}")

  @spec delete(chain(), String.t()) :: :ok | {:error, term()}
  def delete(chain, rule, table \\ @default_table)

  @spec delete(chain(), String.t(), table()) :: :ok | {:error, term()}
  def delete(chain, rule, table),
    do: exec_iptables("-t #{table} --delete #{String.upcase(to_string(chain))} #{rule}")

  @spec insert(chain(), String.t()) :: :ok | {:error, term()}
  def insert(chain, rule),
    do: insert(chain, rule, @default_table, 1)

  @spec insert(chain(), String.t(), table(), pos_integer()) :: :ok | {:error, term()}
  def insert(chain, rule, table, pos),
    do: exec_iptables("-t #{table} --insert #{String.upcase(to_string(chain))} #{pos} #{rule}")

  # private functions

  @spec exec_iptables(String.t()) :: :ok | {:error, term()}
  defp exec_iptables(cmd_args) do
    args = String.split(cmd_args)

    case System.cmd("iptables", args) do
      {_, 0} -> :ok
      {out, err} -> {:error, {out, err}}
    end
  end
end
