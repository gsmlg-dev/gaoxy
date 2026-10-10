defmodule PhoenixNative.CounterLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:count, 0)
     |> assign(:uploaded, "")
     |> allow_upload(:document, accept: ~w(.txt), max_entries: 1)}
  end

  def handle_event("increment", _params, socket),
    do: {:noreply, update(socket, :count, &(&1 + 1))}

  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("save", _params, socket) do
    names =
      consume_uploaded_entries(socket, :document, fn %{path: path}, entry ->
        {:ok, "#{entry.client_name}:#{byte_size(File.read!(path))}"}
      end)

    {:noreply, assign(socket, :uploaded, Enum.join(names, ","))}
  end

  def render(assigns) do
    ~H"""
    <main>
      <h1>Live counter</h1>
      <button id="increment" phx-click="increment">Increment</button>
      <span id="count">{@count}</span>
      <form id="upload-form" phx-change="validate" phx-submit="save">
        <.live_file_input upload={@uploads.document} />
        <button type="submit">Upload</button>
      </form>
      <output id="uploaded">{@uploaded}</output>
    </main>
    """
  end
end
