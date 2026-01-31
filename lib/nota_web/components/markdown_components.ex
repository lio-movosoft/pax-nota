defmodule NotaWeb.MarkdownComponents do
  @moduledoc """
  Phoenix components for rendering markdown documents.
  Designed for efficient LiveView diffing with stable IDs.
  """
  use Phoenix.Component

  import NotaWeb.CoreComponents, only: [icon: 1]

  alias Nota.Notes.Markdown.Document
  alias Nota.Uploads

  alias Document.Block
  alias Document.{Code, CodeBlock, Emphasis, ImageBlock, Link, Strong, Tag, Text, WikiLink}

  @doc """
  Renders a markdown document with optional focus state.

  Groups consecutive ListItem blocks into `<ul>` elements at render time.

  ## Attributes
  - `document` - The Document struct to render
  - `focused_block_id` - ID of currently focused block (optional)

  ## Example

      <.markdown_document
        document={@document}
        focused_block_id={@focused_block_id}
      />
  """
  attr :document, :map, required: true
  attr :focused_block_id, :string, default: nil

  def markdown_document(assigns) do
    grouped = group_blocks(assigns.document.blocks)
    assigns = assign(assigns, :grouped_blocks, grouped)

    ~H"""
    <div
      id="markdown-editor"
      class="markdown-editor prose prose-sm max-w-none"
      phx-hook="MarkdownEditor"
      data-focused-block={@focused_block_id}
    >
      <%= for group <- @grouped_blocks do %>
        <%= case group do %>
          <% {:ul, items} -> %>
            <ul class="markdown-list">
              <.markdown_block
                :for={block <- items}
                block={block}
                focused={block.id == @focused_block_id}
              />
            </ul>
          <% {:oli, items} -> %>
            <ol
              class="markdown-list"
              data-ordered="true"
            >
              <.markdown_block
                :for={block <- items}
                block={block}
                focused={block.id == @focused_block_id}
              />
            </ol>
          <% {:block, block} -> %>
            <.markdown_block block={block} focused={block.id == @focused_block_id} />
        <% end %>
      <% end %>
      <div
        :if={@document.blocks == []}
        class="text-base-content/50 italic cursor-text"
        phx-click="create_first_block"
      >
        Click to start writing...
      </div>
    </div>
    """
  end

  # Group consecutive list items together for wrapping in <ul> or <ol>
  defp group_blocks(blocks) do
    blocks
    |> Enum.chunk_by(fn
      %Block{type: :li} -> :ul
      %Block{type: :oli} -> :oli
      _ -> :other
    end)
    |> Enum.flat_map(fn
      [%Block{type: :li} | _] = items -> [{:ul, items}]
      [%Block{type: :oli} | _] = items -> [{:oli, items}]
      other -> Enum.map(other, &{:block, &1})
    end)
  end

  @doc """
  Renders a single markdown block.
  Uses `phx-update="ignore"` on focused blocks to prevent LiveView
  from interfering with user input.
  """
  attr :block, :map, required: true
  attr :focused, :boolean, default: false

  def markdown_block(%{focused: true} = assigns) do
    ~H"""
    <div
      id={"block-#{@block.id}"}
      data-block-id={@block.id}
      data-focused="true"
      class="markdown-block markdown-block--focused"
      phx-update="ignore"
    >
      <textarea
        id={"input-#{@block.id}"}
        data-block-input="true"
        class="markdown-input"
        phx-blur="blur_block"
        phx-value-block_id={@block.id}
      ><%= @block.source %></textarea>
    </div>
    """
  end

  def markdown_block(%{block: %Block{type: :p}} = assigns) do
    ~H"""
    <p id={"block-#{@block.id}"} data-block-id={@block.id} class="markdown-block">
      <.inline_content :for={inline <- @block.inlines} inline={inline} />
    </p>
    """
  end

  def markdown_block(%{block: %Block{type: type}} = assigns) when type in [:h1, :h2, :h3] do
    tag =
      case type do
        :h1 -> "h1"
        :h2 -> "h2"
        :h3 -> "h3"
      end

    assigns = assign(assigns, :tag, tag)

    ~H"""
    <.dynamic_tag
      id={"block-#{@block.id}"}
      tag_name={@tag}
      data-block-id={@block.id}
      class="markdown-block"
    >
      <.inline_content :for={inline <- @block.inlines} inline={inline} />
    </.dynamic_tag>
    """
  end

  def markdown_block(%{block: %Block{type: type}} = assigns) when type in [:li, :oli] do
    ~H"""
    <li id={"block-#{@block.id}"} data-block-id={@block.id} class="markdown-block markdown-list-item">
      <.inline_content :for={inline <- @block.inlines} inline={inline} />
    </li>
    """
  end

  def markdown_block(%{block: %CodeBlock{}} = assigns) do
    ~H"""
    <pre
      id={"block-#{@block.id}"}
      data-block-id={@block.id}
      class="markdown-block bg-base-300 p-3 rounded"
    ><code>{@block.content}</code></pre>
    """
  end

  def markdown_block(%{block: %ImageBlock{}} = assigns) do
    ~H"""
    <figure
      id={"block-#{@block.id}"}
      data-block-id={@block.id}
      data-block-type="image"
      class="markdown-block markdown-image"
      tabindex="0"
    >
      <img
        src={Uploads.image_url(@block.image_key)}
        alt={@block.alt_text || ""}
        class="max-w-full rounded-lg"
      />
      <figcaption
        :if={@block.alt_text && @block.alt_text != ""}
        class="text-sm text-base-content/60 mt-2 text-center"
      >
        {@block.alt_text}
      </figcaption>
    </figure>
    """
  end

  # Inline content rendering

  attr :inline, :map, required: true

  defp inline_content(%{inline: %Text{}} = assigns) do
    ~H"""
    <span data-inline-id={@inline.id}>{@inline.text}</span>
    """
  end

  defp inline_content(%{inline: %Emphasis{}} = assigns) do
    ~H"""
    <em data-inline-id={@inline.id}>
      <.inline_content :for={child <- @inline.children} inline={child} />
    </em>
    """
  end

  defp inline_content(%{inline: %Strong{}} = assigns) do
    ~H"""
    <strong data-inline-id={@inline.id}>
      <.inline_content :for={child <- @inline.children} inline={child} />
    </strong>
    """
  end

  defp inline_content(%{inline: %Code{}} = assigns) do
    ~H"""
    <code data-inline-id={@inline.id} class="bg-base-200 px-1 rounded text-sm">{@inline.text}</code>
    """
  end

  defp inline_content(%{inline: %Link{url: "/notes/" <> _rest}} = assigns) do
    ~H"""
    <.link data-inline-id={@inline.id} navigate={@inline.url} class="link link-primary">
      <.inline_content :for={child <- @inline.children} inline={child} />
    </.link>
    """
  end

  defp inline_content(%{inline: %Link{}} = assigns) do
    ~H"""
    <a data-inline-id={@inline.id} href={@inline.url} class="link link-primary">
      <.icon
        name="hero-arrow-right-start-on-rectangle"
        class="inline-block size-4 mr-0.5 align-text-bottom"
      /><.inline_content
        :for={child <- @inline.children}
        inline={child}
      />
    </a>
    """
  end

  defp inline_content(%{inline: %WikiLink{}} = assigns) do
    ~H"""
    <span data-inline-id={@inline.id} class="underline decoration-dotted cursor-pointer">
      {@inline.text}
    </span>
    """
  end

  defp inline_content(%{inline: %Tag{}} = assigns) do
    ~H"""
    <span data-inline-id={@inline.id} class="badge badge-soft align-baseline">#{@inline.label}</span>
    """
  end
end
