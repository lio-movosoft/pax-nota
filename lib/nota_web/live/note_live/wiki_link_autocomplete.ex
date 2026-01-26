defmodule NotaWeb.NoteLive.WikiLinkAutocomplete do
  @moduledoc """
  LiveComponent for wiki-link autocomplete.
  Triggered when user types [[ in a block editor.
  Shows a dropdown with filtered suggestions.
  """
  use NotaWeb, :live_component

  alias Nota.Notes

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="absolute z-50 bg-base-100 shadow-lg rounded-lg border border-base-300 w-64"
      style={"top: #{@position.top}px; left: #{@position.left}px;"}
      phx-click-away="close_autocomplete"
    >
      <div class="p-2">
        <input
          id="wiki-link-search"
          type="text"
          class="input input-sm input-bordered w-full"
          placeholder="Search..."
          phx-keyup="filter"
          phx-keydown="input_keydown"
          phx-target={@myself}
          value={@query}
          autofocus
          phx-hook="AutoFocus"
        />
      </div>
      <ul class="menu menu-sm p-0 max-h-48 overflow-y-auto">
        <li :for={{item, index} <- Enum.with_index(@filtered_items)}>
          <a
            class={["", @selected_index == index && "active"]}
            phx-click="select_item"
            phx-value-id={item.id}
            phx-value-title={item.title}
            phx-target={@myself}
          >
            {item.title}
          </a>
        </li>
        <li :if={@filtered_items == []}>
          <span class="text-base-content/50 italic">No matches</span>
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:query, "")
     |> assign(:filtered_items, [])
     |> assign(:selected_index, 0)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Fetch initial notes when component is mounted/updated
    filtered_items =
      if socket.assigns[:current_scope] do
        fetch_notes(socket.assigns.current_scope, socket.assigns[:query] || "")
      else
        []
      end

    {:ok,
     socket
     |> assign_new(:query, fn -> "" end)
     |> assign(:filtered_items, filtered_items)
     |> assign_new(:selected_index, fn -> 0 end)}
  end

  @impl true
  def handle_event("filter", %{"value" => query}, socket) do
    filtered = fetch_notes(socket.assigns.current_scope, query)

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filtered_items, filtered)
     |> assign(:selected_index, 0)}
  end

  defp fetch_notes(scope, query) do
    opts = [limit: 5]
    opts = if query != "", do: Keyword.put(opts, :query, query), else: opts

    scope
    |> Notes.list_notes(opts)
    |> Enum.reject(&is_nil(&1.title))
    |> Enum.map(&%{id: &1.id, title: &1.title})
  end

  def handle_event("input_keydown", %{"key" => "ArrowDown"}, socket) do
    max_index = length(socket.assigns.filtered_items) - 1
    new_index = min(socket.assigns.selected_index + 1, max_index)
    {:noreply, assign(socket, :selected_index, new_index)}
  end

  def handle_event("input_keydown", %{"key" => "ArrowUp"}, socket) do
    new_index = max(socket.assigns.selected_index - 1, 0)
    {:noreply, assign(socket, :selected_index, new_index)}
  end

  def handle_event("input_keydown", %{"key" => "Enter"}, socket) do
    selected_item = Enum.at(socket.assigns.filtered_items, socket.assigns.selected_index)

    if selected_item do
      send(self(), {:note_link_selected, selected_item.id, selected_item.title, socket.assigns.block_id})
    end

    {:noreply, socket}
  end

  def handle_event("input_keydown", %{"key" => "Escape"}, socket) do
    send(self(), :close_autocomplete)
    {:noreply, socket}
  end

  def handle_event("input_keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("select_item", %{"id" => id, "title" => title}, socket) do
    send(self(), {:note_link_selected, String.to_integer(id), title, socket.assigns.block_id})
    {:noreply, socket}
  end

  # Handle click-away by delegating to parent
  def handle_event("close_autocomplete", _params, socket) do
    send(self(), :close_autocomplete)
    {:noreply, socket}
  end
end
