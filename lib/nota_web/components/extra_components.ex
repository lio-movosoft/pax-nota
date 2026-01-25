defmodule NotaWeb.ExtraComponents do
  @moduledoc """
  Additional UI components for the application.

  This module provides components that extend the core UI functionality,
  such as modals for short forms and dialogs.

  ## Usage

  Import this module in your LiveView or component:

      import NotaWeb.ExtraComponents

  Or add it to the `html_helpers` in `NotaWeb` to make it available everywhere.
  """
  use Phoenix.Component
  use Gettext, backend: NotaWeb.Gettext

  import NotaWeb.CoreComponents

  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal dialog.

  ## Examples

      <.modal id="confirm-modal" show on_cancel={JS.navigate(~p"/posts")}>
        Are you sure?
        <:actions>
          <.button>OK</.button>
        </:actions>
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <dialog
      id={@id}
      class="modal"
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
    >
      <div class="modal-box max-w-3xl">
        <form method="dialog">
          <button
            type="button"
            class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
            aria-label="close"
            phx-click={@on_cancel |> hide_modal(@id)}
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </form>
        {render_slot(@inner_block)}
      </div>
      <form method="dialog" class="modal-backdrop">
        <button type="button" phx-click={@on_cancel |> hide_modal(@id)}>close</button>
      </form>
    </dialog>
    """
  end

  defp show_modal(id) do
    JS.show(to: "##{id}")
    |> JS.dispatch("showModal", to: "##{id}")
  end

  defp hide_modal(js \\ %JS{}, id) do
    js
    |> JS.dispatch("close", to: "##{id}")
    |> JS.hide(to: "##{id}")
  end

  @doc """
  basic card (UI eye candy)
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  slot :inner_block, required: true
  slot :title
  slot :actions
  attr :figure_url, :string, default: nil
  attr :figure_alt, :string, default: nil
  attr :id, :string, default: nil

  def card(assigns) do
    ~H"""
    <div id={@id}>
      <.link {@rest} class="focus:outline-none">
        <div class="card bg-base-100 shadow-sm cursor-pointer
        transition duration-150 ease-out transform hover:scale-[1.02] hover:shadow-md">
          <figure
            :if={not is_nil(@figure_url)}
            class="aspect-[3/2] bg-base-200 rounded-t-box overflow-hidden"
          >
            <img
              src={@figure_url}
              alt={@figure_alt}
              class="w-full h-full object-cover"
            />
          </figure>
          <div class="card-body">
            <h2 class="card-title">{render_slot(@title)}</h2>
            {render_slot(@inner_block)}
            <div class="card-actions w-full flex items-center justify-between font-semibold">
              {render_slot(@actions)}
            </div>
          </div>
        </div>
      </.link>
    </div>
    """
  end

  @doc """
  a little crown icon
  """
  attr :rest, :global, include: ~w(class)

  def god_icon(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="#000000"
      aria-hidden="true"
      stroke="#000000"
      stroke-width="1"
      stroke-linecap="round"
      stroke-linejoin="round"
      {@rest}
    >
      <path d="M5 18h14M5 14h14l1-9-4 3-4-5-4 5-4-3 1 9Z" />
    </svg>
    """
  end

  @doc """
  Renders a sortable column label that cycles through sort orders.

  ## Arguments
  - `text` - The label text to display
  - `current_order_by` - The current sort order atom
  - `cycle` - Keyword list of `{order_atom, indicator_string}` pairs

  ## Examples

      <:col label={sort_label("Updated", @order_by, updated_at_desc: " ▼", updated_at_asc: " ▲")}>
        ...
      </:col>

      <:col label={sort_label("Email", @order_by, email_asc: " ▲", email_desc: " ▼")}>
        ...
      </:col>
  """
  def sort_label(text, current_order_by, cycle) do
    keys = Keyword.keys(cycle)
    next_order = next_in_cycle(current_order_by, keys)
    indicator = Keyword.get(cycle, current_order_by, "")

    assigns = %{text: text, next_order: next_order, indicator: indicator}

    ~H"""
    <.link
      phx-click="sort"
      phx-value-order={@next_order}
      class="flex items-center gap-1 cursor-pointer hover:text-zinc-700"
    >
      {@text}<span class="text-xs">{@indicator}</span>
    </.link>
    """
  end

  defp next_in_cycle(current, keys) do
    case Enum.find_index(keys, &(&1 == current)) do
      nil -> hd(keys)
      idx -> Enum.at(keys, rem(idx + 1, length(keys)))
    end
  end

  @doc """
  Renders a back navigation link.

  **Examples**

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :label, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-8 mb-4 flex gap-2">
      <.icon name="hero-arrow-left-solid" class="size-6" />
      <.link navigate={@navigate}>{@label}</.link>
    </div>
    """
  end
end
