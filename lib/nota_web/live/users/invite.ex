defmodule NotaWeb.Users.Invite do
  use NotaWeb, :live_view

  alias Nota.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Invite User
        <:subtitle>Send an invitation email to a new user</:subtitle>
      </.header>

      <.form for={@invite_form} id="invite-form" phx-submit="invite" class="mt-4">
        <.input field={@invite_form[:email]} type="email" label="Email address" required />
        <div class="mt-6 flex justify-end gap-4">
          <.link navigate={~p"/users"}>
            <.button type="button">Cancel</.button>
          </.link>
          <.button variant="primary" phx-disable-with="Sending...">Send Invitation</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Invite User")
     |> assign(:invite_form, to_form(%{"email" => ""}, as: :invite))}
  end

  @impl true
  def handle_event("invite", %{"invite" => %{"email" => email}}, socket) do
    case Accounts.invite_user(email, &url(~p"/users/log-in/#{&1}")) do
      {:ok, _email} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}")
         |> push_navigate(to: ~p"/users")}

      {:error, changeset} ->
        error_message =
          case changeset.errors[:email] do
            {msg, _} -> "Failed to invite: #{msg}"
            _ -> "Failed to send invitation"
          end

        {:noreply, put_flash(socket, :error, error_message)}
    end
  end
end
