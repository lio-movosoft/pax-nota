defmodule NotaWeb.Contacts.Show do
  @moduledoc """
  LiveView for viewing a contact and its associated notes.
  """
  use NotaWeb, :live_view

  alias Nota.Contacts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@contact.first_name} {@contact.last_name}
        <:subtitle>
          <div class="flex flex-col gap-1">
            <div :if={@contact.email}>{@contact.email}</div>
            <div :if={@contact.phone}>{@contact.phone}</div>
            <.link
              :if={@contact.linkedin_url}
              href={@contact.linkedin_url}
              target="_blank"
              class="link"
            >
              LinkedIn Profile
            </.link>
          </div>
        </:subtitle>
        <:actions>
          <.button navigate={~p"/contacts"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.link navigate={~p"/contacts/#{@contact}/edit"}>
            <.button>Edit</.button>
          </.link>
        </:actions>
      </.header>

      <div class="mt-8">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold">Notes</h2>
          <.link navigate={~p"/notes/new?contact_id=#{@contact.id}"}>
            <.button variant="primary">New Note</.button>
          </.link>
        </div>

        <div :if={@notes == []} class="text-zinc-500 italic">
          No notes attached to this contact.
        </div>

        <ul :if={@notes != []} class="space-y-2">
          <li :for={note <- @notes} class="flex gap-4 items-baseline">
            <span class="text-sm text-zinc-500 tabular-nums">
              {Calendar.strftime(note.inserted_at, "%Y-%m-%d")}
            </span>
            <.link navigate={~p"/notes/#{note.id}"} class="link">
              {note.title}
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    contact = Contacts.get_contact!(scope, id)
    notes = Contacts.list_notes_for_contact(scope, contact)

    {:ok,
     socket
     |> assign(:page_title, "#{contact.first_name} #{contact.last_name}")
     |> assign(:contact, contact)
     |> assign(:notes, notes)}
  end
end
