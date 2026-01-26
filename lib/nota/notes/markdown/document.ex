defmodule Nota.Notes.Markdown.Document do
  @moduledoc """
  Structural representation of a markdown document with stable IDs.

  Each block and inline element has a unique ID that remains stable
  across re-parses when content hasn't changed. This is critical for
  efficient LiveView diffing and cursor tracking.

  ## Block Types
  - `Paragraph` - Plain text paragraphs
  - `Heading` - H1-H6 headings
  - `ListItem` - Unordered list items (grouped into <ul> at render time)

  ## Inline Types
  - `Text` - Plain text spans
  - `Emphasis` - *italic* text
  - `Strong` - **bold** text
  - `Code` - `inline code`
  - `Link` - [text](url)
  """

  # Inline types

  defmodule Text do
    @moduledoc "Plain text inline element"
    @enforce_keys [:id, :text]
    defstruct [:id, :text]
    @type t :: %__MODULE__{id: String.t(), text: String.t()}
  end

  defmodule Emphasis do
    @moduledoc "Italic/emphasis inline element (*text*)"
    @enforce_keys [:id, :children]
    defstruct [:id, :children]
    @type t :: %__MODULE__{id: String.t(), children: list()}
  end

  defmodule Strong do
    @moduledoc "Bold/strong inline element (**text**)"
    @enforce_keys [:id, :children]
    defstruct [:id, :children]
    @type t :: %__MODULE__{id: String.t(), children: list()}
  end

  defmodule Code do
    @moduledoc "Inline code element (`code`)"
    @enforce_keys [:id, :text]
    defstruct [:id, :text]
    @type t :: %__MODULE__{id: String.t(), text: String.t()}
  end

  defmodule Link do
    @moduledoc "Link inline element ([text](url))"
    @enforce_keys [:id, :url, :children]
    defstruct [:id, :url, :title, :children]

    @type t :: %__MODULE__{
            id: String.t(),
            url: String.t(),
            title: String.t() | nil,
            children: list()
          }
  end

  defmodule WikiLink do
    @moduledoc "Wiki link inline element ([[text]])"
    @enforce_keys [:id, :text]
    defstruct [:id, :text]
    @type t :: %__MODULE__{id: String.t(), text: String.t()}
  end

  @type inline :: Text.t() | Emphasis.t() | Strong.t() | Code.t() | Link.t() | WikiLink.t()

  # Unified block type

  defmodule Block do
    @moduledoc """
    Unified block type for all block-level elements.

    ## Types
    - `:h1`, `:h2`, `:h3` - Headings
    - `:li` - Unordered list item
    - `:oli` - Ordered list item
    - `:p` - Paragraph
    """
    @enforce_keys [:id, :type, :inlines, :source]
    defstruct [:id, :type, :inlines, :source]

    @type block_type :: :h1 | :h2 | :h3 | :li | :oli | :p
    @type t :: %__MODULE__{
            id: String.t(),
            type: block_type(),
            inlines: list(),
            source: String.t()
          }
  end

  @type block :: Block.t()

  # Document container

  @enforce_keys [:blocks]
  defstruct [:blocks]
  @type t :: %__MODULE__{blocks: [block()]}

  @doc """
  Returns the raw markdown source for a specific block by ID.
  """
  @spec get_block_source(t(), String.t()) :: String.t() | nil
  def get_block_source(%__MODULE__{blocks: blocks}, block_id) do
    case find_block(blocks, block_id) do
      nil -> nil
      block -> block.source
    end
  end

  @doc """
  Finds a block by ID.
  """
  @spec find_block([block()], String.t()) :: block() | nil
  def find_block(blocks, block_id) do
    Enum.find(blocks, &(&1.id == block_id))
  end

  @doc """
  Updates a block's content from raw markdown source.
  Preserves the block's ID while re-parsing its content.
  """
  @spec update_block(t(), String.t(), String.t()) :: t()
  def update_block(%__MODULE__{blocks: blocks} = doc, block_id, new_source) do
    alias Nota.Notes.Markdown.Parser

    blocks =
      Enum.map(blocks, fn block ->
        if block.id == block_id do
          # Re-parse the block with the new source, preserving the ID
          Parser.parse_block_with_id(new_source, block_id)
        else
          block
        end
      end)

    %{doc | blocks: blocks}
  end

  @doc """
  Inserts a new block
  if `after:` is specified place it after the given `id` after the specified block ID.

  ## Examples

      new_block(doc)
      {doc, new_block_id}

      new_block(doc, after: block_id)
      {doc, new_block_id}

  """
  def new_block(%__MODULE__{blocks: blocks} = doc, opts \\ []) do
    new_id = "mv-#{Enum.count(blocks) + 1}"

    new_block = %Block{
      id: new_id,
      type: :p,
      inlines: [%Text{id: "#{new_id}:0", text: ""}],
      source: ""
    }

    after_block_id = Keyword.get(opts, :after, nil)

    blocks = insert_new_block(blocks, new_block, after_block_id)

    doc = %{doc | blocks: blocks}
    {doc, new_id}
  end

  defp insert_new_block(blocks, new_block, nil), do: [new_block | blocks]

  defp insert_new_block(blocks, new_block, after_block_id) do
    Enum.flat_map(blocks, fn block ->
      if block.id == after_block_id, do: [block, new_block], else: [block]
    end)
  end

  @doc """
  Inserts a new block after the specified block ID.
  """
  @spec insert_block_after(t(), String.t(), block()) :: t()
  def insert_block_after(%__MODULE__{blocks: blocks} = doc, after_id, new_block) do
    blocks =
      Enum.flat_map(blocks, fn block ->
        if block.id == after_id do
          [block, new_block]
        else
          [block]
        end
      end)

    %{doc | blocks: blocks}
  end

  @doc """
  Removes a block by ID.
  """
  @spec remove_block(t(), String.t()) :: t()
  def remove_block(%__MODULE__{blocks: blocks} = doc, block_id) do
    %{doc | blocks: Enum.reject(blocks, &(&1.id == block_id))}
  end

  @doc """
  Merges a block with its previous block.
  Returns `{:ok, document, prev_block_id, cursor_offset}` on success,
  or `:error` if the block is the first one (no previous block).

  The cursor_offset is the position where the cursor should be placed
  (at the end of the previous block's content, before the merged content).
  """
  @spec merge_with_previous(t(), String.t(), String.t()) ::
          {:ok, t(), String.t(), non_neg_integer()} | :error
  def merge_with_previous(%__MODULE__{blocks: blocks} = doc, block_id, current_content) do
    block_ids = Enum.map(blocks, & &1.id)

    case Enum.find_index(block_ids, &(&1 == block_id)) do
      nil ->
        :error

      0 ->
        # First block, nothing to merge with
        :error

      idx ->
        prev_block = Enum.at(blocks, idx - 1)
        prev_source = prev_block.source

        # Cursor should be placed at the end of previous content
        cursor_offset = String.length(prev_source)

        # Merge: previous content + current content
        merged_source = prev_source <> current_content

        # Update previous block with merged content and remove current block
        alias Nota.Notes.Markdown.Parser

        blocks =
          blocks
          |> Enum.with_index()
          |> Enum.flat_map(fn {block, i} ->
            cond do
              i == idx - 1 ->
                # Update previous block with merged content
                [Parser.parse_block_with_id(merged_source, prev_block.id)]

              i == idx ->
                # Remove current block
                []

              true ->
                [block]
            end
          end)

        {:ok, %{doc | blocks: blocks}, prev_block.id, cursor_offset}
    end
  end

  @doc """
  Returns true if the document is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{blocks: []}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Returns the ID of the first block, or nil if empty.
  """
  @spec first_block_id(t()) :: String.t() | nil
  def first_block_id(%__MODULE__{blocks: []}), do: nil
  def first_block_id(%__MODULE__{blocks: [first | _]}), do: first.id

  @doc """
  Returns the ID of the last block, or nil if empty.
  """
  @spec last_block_id(t()) :: String.t() | nil
  def last_block_id(%__MODULE__{blocks: []}), do: nil
  def last_block_id(%__MODULE__{blocks: blocks}), do: List.last(blocks).id

  @doc """
  Returns the ID of the block before the given block ID, or nil if first.
  """
  @spec previous_block_id(t(), String.t()) :: String.t() | nil
  def previous_block_id(%__MODULE__{blocks: blocks}, block_id) do
    blocks
    |> Enum.map(& &1.id)
    |> find_adjacent(block_id, :previous)
  end

  @doc """
  Returns the ID of the block after the given block ID, or nil if last.
  """
  @spec next_block_id(t(), String.t()) :: String.t() | nil
  def next_block_id(%__MODULE__{blocks: blocks}, block_id) do
    blocks
    |> Enum.map(& &1.id)
    |> find_adjacent(block_id, :next)
  end

  defp find_adjacent(ids, target_id, direction) do
    idx = Enum.find_index(ids, &(&1 == target_id))
    get_adjacent_at(ids, idx, direction)
  end

  defp get_adjacent_at(_ids, nil, _direction), do: nil
  defp get_adjacent_at(ids, idx, :previous) when idx > 0, do: Enum.at(ids, idx - 1)
  defp get_adjacent_at(_ids, _idx, :previous), do: nil
  defp get_adjacent_at(ids, idx, :next), do: Enum.at(ids, idx + 1)

  @doc """
  Splits a block at the given cursor position.
  Returns `{:ok, document, new_block_id}` where:
  - The original block is updated to contain content before the cursor
  - A new block is created after it with content after the cursor

  ## Examples

      split_block(doc, "block-1", "hello world", 5)
      # Original block: "hello"
      # New block: " world"

  """
  @spec split_block(t(), String.t(), String.t(), non_neg_integer()) ::
          {:ok, t(), String.t()}
  def split_block(%__MODULE__{} = doc, block_id, content, cursor_position) do
    # Split content at cursor position
    before_cursor = String.slice(content, 0, cursor_position)
    after_cursor = String.slice(content, cursor_position, String.length(content) - cursor_position)

    # Update original block with content before cursor
    doc = update_block(doc, block_id, before_cursor)

    # Create new block after the current one
    {doc, new_id} = new_block(doc, after: block_id)

    # Update new block with content after cursor
    doc = update_block(doc, new_id, after_cursor)

    {:ok, doc, new_id}
  end
end
