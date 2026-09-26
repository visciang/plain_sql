defmodule PlainSQL.TestSupport.UnknownConnection do
  @moduledoc false
  # A DBConnection module with no row in the inference table.

  @behaviour DBConnection

  @impl true
  def connect(_opts), do: {:ok, %{}}

  @impl true
  def disconnect(_err, _state), do: :ok

  @impl true
  def checkout(state), do: {:ok, state}

  @impl true
  def ping(state), do: {:ok, state}

  @impl true
  def handle_begin(_opts, state), do: {:ok, :begin, state}

  @impl true
  def handle_commit(_opts, state), do: {:ok, :commit, state}

  @impl true
  def handle_rollback(_opts, state), do: {:ok, :rollback, state}

  @impl true
  def handle_status(_opts, state), do: {:idle, state}

  @impl true
  def handle_prepare(query, _opts, state), do: {:ok, query, state}

  @impl true
  def handle_execute(query, _params, _opts, state), do: {:ok, query, :result, state}

  @impl true
  def handle_close(_query, _opts, state), do: {:ok, :closed, state}

  @impl true
  def handle_declare(query, _params, _opts, state), do: {:ok, query, :cursor, state}

  @impl true
  def handle_fetch(_query, _cursor, _opts, state), do: {:halt, :result, state}

  @impl true
  def handle_deallocate(_query, _cursor, _opts, state), do: {:ok, :deallocated, state}
end
