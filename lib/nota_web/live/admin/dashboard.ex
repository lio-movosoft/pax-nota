defmodule NotaWeb.Admin.Dashboard do
  @moduledoc """
  LiveView for the admin dashboard showing system statistics.
  """
  use NotaWeb, :live_view

  alias Nota.Accounts
  alias Nota.Notes

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Admin Dashboard
        <:subtitle>Welcome to the admin area</:subtitle>
      </.header>

      <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
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
       note_count: Notes.count_notes()
     )}
  end
end
