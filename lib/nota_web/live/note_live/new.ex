defmodule NotaWeb.NoteLive.New do
  @moduledoc """
  LiveView for creating a new note, optionally associated with a contact.
  Immediately creates the note and redirects to the editor.
  """
  use NotaWeb, :live_view

  alias Nota.Notes

  @impl true
  def mount(params, _session, socket) do
    contact_id = params["contact_id"]

    attrs = %{
      title: "New Note",
      body: "",
      contact_id: contact_id
    }

    case Notes.create_note(socket.assigns.current_scope, attrs) do
      {:ok, note} ->
        {:ok, push_navigate(socket, to: ~p"/notes/#{note}")}

      {:error, _changeset} ->
        {:ok,
         socket
         |> put_flash(:error, "Failed to create note")
         |> push_navigate(to: ~p"/notes")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-center p-8">
        <span class="loading loading-spinner loading-lg"></span>
      </div>
    </Layouts.app>
    """
  end
end
