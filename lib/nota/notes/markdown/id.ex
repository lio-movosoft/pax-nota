defmodule Nota.Notes.Markdown.Id do
  @moduledoc """
  Simple sequential ID generation for markdown elements.

  ## Format
  - Blocks: `{position}` e.g., `0`, `1`, `2`
  - Inlines: `{block_id}:{position}` e.g., `0:0`, `1:2`
  - List items: `{list_id}:{position}` e.g., `3:0`, `3:1`
  """

  @doc """
  Generate ID for a block at given position.
  """
  @spec for_block(atom(), non_neg_integer(), String.t()) :: String.t()
  def for_block(_type, position, _content) do
    "#{position}"
  end

  @doc """
  Generate ID for an inline at given position within a block.
  """
  @spec for_inline(atom(), String.t(), non_neg_integer(), String.t()) :: String.t()
  def for_inline(_type, block_id, position, _content) do
    "#{block_id}:#{position}"
  end

  @doc """
  Generate ID for a list item at given position.
  """
  @spec for_list_item(String.t(), non_neg_integer(), String.t()) :: String.t()
  def for_list_item(list_id, position, _content) do
    "#{list_id}:#{position}"
  end
end
