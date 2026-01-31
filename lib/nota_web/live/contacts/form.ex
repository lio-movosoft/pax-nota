defmodule NotaWeb.Contacts.Form do
  @moduledoc """
  LiveView for creating and editing contacts.
  """
  use NotaWeb, :live_view

  alias Nota.Contacts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle :if={@live_action == :edit}>{@contact.first_name} {@contact.last_name}</:subtitle>
      </.header>

      <div class="mt-8 max-w-xl">
        <.form for={@form} id="contact-form" phx-change="validate" phx-submit="save">
          <div class="grid md:grid-cols-2 md:gap-4">
            <.input field={@form[:first_name]} type="text" label="First Name" />
            <.input field={@form[:last_name]} type="text" label="Last Name" />
          </div>
          <div class="grid md:grid-cols-2 md:gap-4">
            <.input field={@form[:email]} type="email" label="Email" />
            <.input field={@form[:phone]} type="tel" label="Phone" />
          </div>
          <.input field={@form[:linkedin_url]} type="url" label="LinkedIn URL" />

          <div class="mt-6 flex gap-4">
            <.button variant="primary" phx-disable-with="Saving...">Save Contact</.button>
            <.button navigate={~p"/contacts"}>Cancel</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    socket
    |> assign(:page_title, "New Contact")
    |> assign(:contact, %Contacts.Contact{user_id: scope.user.id})
    |> assign(:form, to_form(Contacts.change_new_contact(scope)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    contact = Contacts.get_contact!(scope, id)

    socket
    |> assign(:page_title, "Edit Contact")
    |> assign(:contact, contact)
    |> assign(:form, to_form(Contacts.change_contact(scope, contact)))
  end

  @impl true
  def handle_event("validate", %{"contact" => contact_params}, socket) do
    scope = socket.assigns.current_scope

    changeset =
      case socket.assigns.live_action do
        :new -> Contacts.change_new_contact(scope, contact_params)
        :edit -> Contacts.change_contact(scope, socket.assigns.contact, contact_params)
      end

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"contact" => contact_params}, socket) do
    save_contact(socket, socket.assigns.live_action, contact_params)
  end

  defp save_contact(socket, :new, contact_params) do
    scope = socket.assigns.current_scope

    case Contacts.create_contact(scope, contact_params) do
      {:ok, _contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contact created successfully")
         |> push_navigate(to: ~p"/contacts")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_contact(socket, :edit, contact_params) do
    scope = socket.assigns.current_scope

    case Contacts.update_contact(scope, socket.assigns.contact, contact_params) do
      {:ok, _contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contact updated successfully")
         |> push_navigate(to: ~p"/contacts")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
