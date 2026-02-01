defmodule NotaWeb.Admin.Dashboard do
  @moduledoc """
  LiveView for the admin dashboard showing system statistics.
  """
  use NotaWeb, :live_view

  alias Nota.Accounts
  alias Nota.Contacts
  alias Nota.Notes

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} card={false}>
      <div class="card bg-base-200 p-6 shadow-xl">
        <.header icon="hero-squares-2x2">
          Admin Dashboard
          <:subtitle>Welcome to the admin area</:subtitle>
        </.header>
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <.card navigate={~p"/users"} id="users-widget">
          <:title>Total Users</:title>
          <div class="mt-2 text-3xl font-semibold">{@user_count}</div>
          <:actions>
            Users &rarr;
          </:actions>
        </.card>
        <.card navigate={~p"/notes"} id="notes-widget">
          <:title>Total Notes</:title>
          <div class="mt-2 text-3xl font-semibold">{@note_count}</div>
          <:actions>
            Notes &rarr;
          </:actions>
        </.card>
        <.card navigate={~p"/contacts"} id="contacts-widget">
          <:title>Total Contacts</:title>
          <div class="mt-2 text-3xl font-semibold">{@contact_count}</div>
          <:actions>
            Contacts &rarr;
          </:actions>
        </.card>
        <.card id="info-widget">
          <:title>Phoenix</:title>
          <div class="flex-1">
            <a href="/" class="flex-1 flex w-fit items-center gap-2">
              <img src={~p"/images/logo.svg"} width="36" />
              <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
            </a>
          </div>
        </.card>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       user_count: Accounts.count_users(),
       note_count: Notes.count_notes(),
       contact_count: Contacts.count_contacts()
     )}
  end
end
