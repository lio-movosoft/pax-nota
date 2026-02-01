defmodule NotaWeb.Users.Index do
  @moduledoc """
  LiveView for listing and managing users in the admin interface.
  """
  use NotaWeb, :live_view

  alias Nota.Accounts

  @limits [20, 50, 100]
  @filters ["any permission", "users", "recipes", "superusers"]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header icon="hero-users">
        Users
        <:subtitle>Manage all users in the system</:subtitle>
        <:actions>
          <.link navigate={~p"/users/invite"}>
            <.button variant="primary">Invite User</.button>
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
            placeholder="Search by email..."
            value={@search_form[:query].value}
          />
          <select name={@search_form[:filter].name} class="select join-item flex-none w-40">
            <option :for={f <- @filters} value={f} selected={@filter == f}>{f}</option>
          </select>

          <select name={@search_form[:limit].name} class="select join-item flex-none w-28">
            <option :for={l <- @limits} value={l} selected={@limit == l}>{l} items</option>
          </select>
        </div>
      </.form>

      <.table id="users" rows={@streams.users}>
        <:col
          :let={{_id, user}}
          label={sort_label("Email", @order_by, email_asc: " ▲", email_desc: " ▼")}
        >
          <span class="flex items-center gap-0">
            {user.email}
            <.god_icon :if={user.is_god} class="size-5" />
          </span>
        </:col>
        <:col :let={{_id, user}} label="Verified">
          <.icon :if={user.confirmed_at} name="hero-check" class="size-5 text-success" />
        </:col>
        <:col
          :let={{_id, user}}
          label={sort_label("Updated", @order_by, updated_at_desc: " ▼", updated_at_asc: " ▲")}
        >
          {Calendar.strftime(user.updated_at, "%Y-%m-%d %H:%M")}
        </:col>
        <:action :let={{_id, user}}>
          <.link navigate={~p"/users/#{user}/edit"}>
            Edit
          </.link>
        </:action>
        <:action :let={{id, user}}>
          <.link
            phx-click={JS.push("delete", value: %{id: user.id}) |> hide("##{id}")}
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
    if connected?(socket) do
      Accounts.subscribe_all_users()
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Users")
     |> assign(:query, "")
     |> assign(:order_by, :inserted_at_desc)
     |> assign(:filter, "any permission")
     |> assign(:limit, 20)
     |> assign(:limits, @limits)
     |> assign(:filters, @filters)
     |> assign(
       :search_form,
       to_form(%{"query" => "", "filter" => "any permission", "limit" => "20"}, as: :search)
     )
     |> stream(:users, list_users(limit: 20))}
  end

  @impl true
  def handle_event("search", %{"search" => search_params}, socket) do
    query = Map.get(search_params, "query", "")
    filter = Map.get(search_params, "filter", "any permission")
    limit = search_params |> Map.get("limit", "20") |> String.to_integer()

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filter, filter)
     |> assign(:limit, limit)
     |> assign(
       :search_form,
       to_form(%{"query" => query, "filter" => filter, "limit" => to_string(limit)}, as: :search)
     )
     |> stream(
       :users,
       list_users(query: query, filter: filter, order_by: socket.assigns.order_by, limit: limit),
       reset: true
     )}
  end

  def handle_event("sort", %{"order" => order}, socket) do
    order_by = String.to_existing_atom(order)

    {:noreply,
     socket
     |> assign(:order_by, order_by)
     |> stream(
       :users,
       list_users(
         query: socket.assigns.query,
         filter: socket.assigns.filter,
         order_by: order_by,
         limit: socket.assigns.limit
       ),
       reset: true
     )}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)
    {:noreply, stream_delete(socket, :users, user)}
  end

  @impl true
  def handle_info({type, %Accounts.User{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(
       socket,
       :users,
       list_users(
         query: socket.assigns.query,
         filter: socket.assigns.filter,
         order_by: socket.assigns.order_by,
         limit: socket.assigns.limit
       ),
       reset: true
     )}
  end

  defp list_users(opts) do
    Accounts.list_users(opts)
  end
end
