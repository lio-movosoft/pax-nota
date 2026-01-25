defmodule NotaWeb.Users.Form do
  use NotaWeb, :live_view

  alias Nota.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>{@user.email}</:subtitle>
      </.header>

      <div class="mt-8 max-w-xl">
        <.form for={@form} id="user-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:email]} type="email" label="Email" />
          <.input field={@form[:is_god]} type="checkbox" label="God" />

          <fieldset class="mt-4">
            <legend class="text-sm font-semibold leading-6 text-zinc-800">Permissions</legend>
            <div class="mt-2 grid grid-cols-3">
              <.permission_cb form={@form} permission="users" />
              <.permission_cb form={@form} permission="recipes" />
            </div>
          </fieldset>
          <div class="mt-6 flex gap-4">
            <.button variant="primary" phx-disable-with="Saving...">Save</.button>
            <.button navigate={return_path(@current_scope, @return_to, @user)}>Cancel</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    user = Accounts.get_user!(id)

    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, user)
    |> assign(:form, to_form(Accounts.change_user(user)))
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user(socket.assigns.user, user_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.live_action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    user_params = ensure_permissions(user_params)

    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, user)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  # ensure "no permissions selected clear the current permissions"
  defp ensure_permissions(%{"permissions" => _} = user_params), do: user_params
  defp ensure_permissions(user_params), do: Map.put(user_params, "permissions", [])

  defp return_path(_scope, _return_to, _user), do: ~p"/users"

  # === HEEX HELPERS
  attr :permission, :string, required: true
  attr :form, :any, required: true

  defp permission_cb(assigns) do
    assigns =
      assign(assigns, :checked, assigns.permission in assigns.form.data.permissions)

    ~H"""
    <label class="flex items-center gap-2">
      <input
        id={"cb-permission-#{@permission}"}
        phx-update="ignore"
        type="checkbox"
        name="user[permissions][]"
        value={@permission}
        checked={@checked}
        class="checkbox checkbox-sm"
      />
      <span class="text-sm text-zinc-700">{@permission}</span>
    </label>
    """

    # class="rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900"
  end
end
