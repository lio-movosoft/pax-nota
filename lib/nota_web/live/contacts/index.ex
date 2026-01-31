defmodule NotaWeb.Contacts.Index do
  @moduledoc """
  LiveView for listing and managing contacts.
  """
  use NotaWeb, :live_view

  alias Nota.Contacts

  @limits [20, 50, 100]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Contacts
        <:subtitle>Manage your contacts</:subtitle>
        <:actions>
          <.link navigate={~p"/contacts/new"}>
            <.button variant="primary">New Contact</.button>
          </.link>
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
            placeholder="Search by name..."
            value={@search_form[:query].value}
          />

          <select name={@search_form[:limit].name} class="select join-item flex-none w-28">
            <option :for={l <- @limits} value={l} selected={@limit == l}>{l} items</option>
          </select>
        </div>
      </.form>

      <.table id="contacts" rows={@streams.contacts}>
        <:col
          :let={{_id, contact}}
          label={sort_label("Updated", @order_by, updated_at_desc: " ▼", updated_at_asc: " ▲")}
        >
          {Calendar.strftime(contact.updated_at, "%Y-%m-%d")}
        </:col>
        <:col
          :let={{_id, contact}}
          label={sort_label("Name", @order_by, last_name_asc: " ▲", last_name_desc: " ▼")}
        >
          {contact.first_name} {contact.last_name}
        </:col>
        <:col :let={{_id, contact}} label="Contact">
          <div class="flex flex-col gap-1">
            <div :if={contact.email}>{contact.email}</div>
            <div :if={contact.phone} class="text-sm text-zinc-500">{contact.phone}</div>
            <.link
              :if={contact.linkedin_url}
              href={contact.linkedin_url}
              target="_blank"
              class="link text-sm"
            >
              LinkedIn
            </.link>
          </div>
        </:col>
        <:action :let={{_id, contact}}>
          <.link navigate={~p"/contacts/#{contact}/edit"}>
            Edit
          </.link>
        </:action>
        <:action :let={{id, contact}}>
          <.link
            phx-click={JS.push("delete", value: %{id: contact.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if connected?(socket) do
      Contacts.subscribe_contacts(scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Contacts")
     |> assign(:query, "")
     |> assign(:order_by, :updated_at_desc)
     |> assign(:limit, 20)
     |> assign(:limits, @limits)
     |> assign(
       :search_form,
       to_form(%{"query" => "", "limit" => "20"}, as: :search)
     )
     |> stream(:contacts, list_contacts(scope, limit: 20, order_by: :updated_at_desc))}
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
       :contacts,
       list_contacts(socket.assigns.current_scope,
         query: query,
         order_by: socket.assigns.order_by,
         limit: limit
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
       :contacts,
       list_contacts(socket.assigns.current_scope,
         query: socket.assigns.query,
         order_by: order_by,
         limit: socket.assigns.limit
       ),
       reset: true
     )}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    contact = Contacts.get_contact!(scope, id)
    {:ok, _} = Contacts.delete_contact(scope, contact)
    {:noreply, stream_delete(socket, :contacts, contact)}
  end

  @impl true
  def handle_info({type, %Contacts.Contact{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(
       socket,
       :contacts,
       list_contacts(socket.assigns.current_scope,
         query: socket.assigns.query,
         order_by: socket.assigns.order_by,
         limit: socket.assigns.limit
       ),
       reset: true
     )}
  end

  defp list_contacts(scope, opts) do
    Contacts.list_contacts(scope, opts)
  end
end
