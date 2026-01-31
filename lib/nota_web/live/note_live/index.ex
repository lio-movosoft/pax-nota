defmodule NotaWeb.NoteLive.Index do
  use NotaWeb, :live_view

  alias Nota.Notes

  @limits [20, 50, 100]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        My Notes
        <:actions>
          <.button variant="primary" phx-click="new_note">
            <.icon name="hero-plus" /> New Note
          </.button>
        </:actions>
      </.header>

      <.form
        for={@search_form}
        id="search-form"
        phx-change="search"
        phx-submit="search"
      >
        <div class="join flex">
          <input
            name={@search_form[:query].name}
            phx-debounce="300"
            type="search"
            class="input join-item grow"
            placeholder="Search notes..."
            value={@search_form[:query].value}
          />

          <select name={@search_form[:limit].name} class="select join-item flex-none w-28">
            <option :for={l <- @limits} value={l} selected={@limit == l}>{l} items</option>
          </select>
        </div>
      </.form>

      <.table id="notes" rows={@streams.notes}>
        <:col
          :let={{_id, note}}
          label={sort_label("Updated", @order_by, updated_at_desc: " ▼", updated_at_asc: " ▲")}
        >
          <span class="text-base-content/60 whitespace-nowrap">
            {Calendar.strftime(note.updated_at, "%Y-%m-%d")}
          </span>
        </:col>
        <:col :let={{_id, note}} label="Title">
          <.link navigate={~p"/notes/#{note}"} class="font-medium hover:underline">
            {note.title || "Untitled"}
          </.link>
        </:col>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Notes.subscribe_notes(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "My Notes")
     |> assign(:query, "")
     |> assign(:limit, 20)
     |> assign(:limits, @limits)
     |> assign(:order_by, :updated_at_desc)
     |> assign(
       :search_form,
       to_form(%{"query" => "", "limit" => "20"}, as: :search)
     )
     |> stream(:notes, list_notes(socket.assigns.current_scope, limit: 20))}
  end

  @impl true
  def handle_event("search", %{"search" => search_params}, socket) do
    query = Map.get(search_params, "query", "")
    limit = search_params |> Map.get("limit", "20") |> String.to_integer()

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:limit, limit)
     |> assign(
       :search_form,
       to_form(%{"query" => query, "limit" => to_string(limit)}, as: :search)
     )
     |> stream(
       :notes,
       list_notes(socket.assigns.current_scope,
         query: query,
         limit: limit,
         order_by: socket.assigns.order_by
       ),
       reset: true
     )}
  end

  def handle_event("sort", %{"order" => order}, socket) do
    order_by = String.to_existing_atom(order)

    {:noreply,
     socket
     |> assign(:order_by, order_by)
     |> stream(
       :notes,
       list_notes(socket.assigns.current_scope,
         query: socket.assigns.query,
         limit: socket.assigns.limit,
         order_by: order_by
       ),
       reset: true
     )}
  end

  def handle_event("new_note", _params, socket) do
    case Notes.create_note(socket.assigns.current_scope, %{title: "Hello Note", body: ""}) do
      {:ok, note} ->
        {:noreply, push_navigate(socket, to: ~p"/notes/#{note}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create note")}
    end
  end

  @impl true
  def handle_info({type, %Nota.Notes.Note{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(
       socket,
       :notes,
       list_notes(
         socket.assigns.current_scope,
         query: socket.assigns.query,
         limit: socket.assigns.limit,
         order_by: socket.assigns.order_by
       ),
       reset: true
     )}
  end

  defp list_notes(current_scope, opts) do
    # Only search if query is at least 3 characters
    opts =
      case Keyword.get(opts, :query, "") do
        q when byte_size(q) < 3 -> Keyword.delete(opts, :query)
        _ -> opts
      end

    Notes.list_notes(current_scope, opts)
  end
end
