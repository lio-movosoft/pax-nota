defmodule Nota.Notes.Markdown.Parser do
  @moduledoc """
  Thin markdown parser supporting a focused subset of CommonMark.

  Supported elements:
  - Block: Headings (h1-h3), Paragraphs, Code blocks (fenced), List items (ul only)
  - Inline: Emphasis (*), Strong (**), Code (`), Links [text](url)

  Design goals:
  - No external dependencies (no earmark)
  - Preserve source for block reconstruction
  - Generate stable IDs via Nota.Notes.Markdown.Id
  """

  alias Nota.Notes.Markdown.{Document, Id}
  alias Document.Block
  alias Document.{Text, Emphasis, Strong, Code, Link, WikiLink}

  defp dom_id(index), do: "mv-#{index}"

  @doc """
  Parse markdown string into Document struct.
  """
  @spec parse(String.t()) :: Document.t()
  def parse(markdown) when is_binary(markdown) do
    # dbg({:parsing, markdown})

    markdown
    |> normalize_line_endings()
    |> split_into_blocks()
    |> parse_blocks_with_index()
    |> then(&%Document{blocks: &1})
  end

  def parse(nil), do: %Document{blocks: []}

  # Parse blocks with sequential IDs
  defp parse_blocks_with_index(block_texts) do
    block_texts
    |> Enum.with_index()
    |> Enum.map(fn {block_text, index} ->
      parse_block(block_text, dom_id(index))
    end)
  end

  @doc """
  Convert Document back to markdown string.
  """
  @spec to_markdown(Document.t()) :: String.t()
  def to_markdown(%Document{blocks: blocks}) do
    blocks
    |> Enum.map(& &1.source)
    |> Enum.join("\n\n")
  end

  @doc """
  Parse a single block with a specific ID (used for updates).
  """
  @spec parse_block_with_id(String.t(), String.t()) :: Document.block()
  def parse_block_with_id(source, id) do
    block = parse_block(source, dom_id(0))
    %{block | id: id}
  end

  @doc """
  Convert a block back to markdown.
  """
  @spec block_to_markdown(Document.block()) :: String.t()
  def block_to_markdown(block), do: block.source

  # Private: Normalize line endings
  defp normalize_line_endings(text) do
    String.replace(text, ~r/\r\n?/, "\n")
  end

  # Private: Split text into block-level chunks
  defp split_into_blocks(text) do
    text
    |> String.trim()
    |> split_preserving_code_blocks()
  end

  # Split on blank lines, but keep code blocks intact
  defp split_preserving_code_blocks(text) do
    # First, protect code blocks by replacing their newlines temporarily
    {protected, code_blocks} = protect_code_blocks(text)

    # Split on double newlines
    parts =
      protected
      |> String.split(~r/\n\s*\n/, trim: true)
      |> Enum.map(&String.trim/1)

    # Restore code blocks
    restore_code_blocks(parts, code_blocks)
  end

  defp protect_code_blocks(text) do
    regex = ~r/```[\s\S]*?```/

    code_blocks =
      Regex.scan(regex, text)
      |> Enum.map(&hd/1)
      |> Enum.with_index()

    protected =
      Enum.reduce(code_blocks, text, fn {block, idx}, acc ->
        String.replace(acc, block, "<<<CODE_BLOCK_#{idx}>>>", global: false)
      end)

    {protected, code_blocks}
  end

  defp restore_code_blocks(parts, code_blocks) do
    Enum.map(parts, fn part ->
      Enum.reduce(code_blocks, part, fn {block, idx}, acc ->
        String.replace(acc, "<<<CODE_BLOCK_#{idx}>>>", block)
      end)
    end)
  end

  def empty?("# "), do: true
  def empty?("## "), do: true
  def empty?("### "), do: true
  def empty?("- "), do: true
  def empty?("1. "), do: true
  def empty?("2. "), do: true
  def empty?("3. "), do: true
  def empty?(""), do: true
  def empty?(_), do: false

  # Private: Parse a single block (may return list for list items)
  defp parse_block("# " <> content = text, id),
    do: %Block{id: id, type: :h1, inlines: parse_inlines(String.trim(content), id), source: text}

  defp parse_block("## " <> content = text, id),
    do: %Block{id: id, type: :h2, inlines: parse_inlines(String.trim(content), id), source: text}

  defp parse_block("### " <> content = text, id),
    do: %Block{id: id, type: :h3, inlines: parse_inlines(String.trim(content), id), source: text}

  defp parse_block("- " <> content = text, id),
    do: %Block{id: id, type: :li, inlines: parse_inlines(content, id), source: text}

  defp parse_block(text, id) do
    case Regex.run(~r/^(\d+)\.\s+(.*)$/s, text, capture: :all_but_first) do
      [_num, content] ->
        %Block{id: id, type: :oli, inlines: parse_inlines(content, id), source: text}

      nil ->
        %Block{id: id, type: :p, inlines: parse_inlines(text, id), source: text}
    end
  end

  # defp parse_block({block_text, index}) do
  #   # dbg({:parse_block, block_text, index})

  #   cond do
  #     heading?(block_text) -> parse_heading(block_text, index)
  #     code_block?(block_text) -> parse_code_block(block_text, index)
  #     list_item?(block_text) -> parse_list_items(block_text, index)
  #     true -> parse_paragraph(block_text, index)
  #   end
  # end

  # defp heading?(text), do: String.match?(text, ~r/^\#{1,3}\s/)
  # defp code_block?(text), do: String.match?(text, ~r/^```/)
  # defp list_item?(text), do: String.match?(text, ~r/^[-*+]\s/)

  # defp parse_heading(text, index) do
  #   case Regex.run(~r/^(\#{1,3})\s+(.*)$/s, text, capture: :all_but_first) do
  #     [hashes, content] ->
  #       level = String.length(hashes)
  #       id = Id.for_block(:"heading_#{level}", index, text)

  #       %Heading{
  #         id: id,
  #         level: level,
  #         inlines: parse_inlines(String.trim(content), id),
  #         source: text
  #       }

  #     nil ->
  #       parse_paragraph(text, index)
  #   end
  # end

  # defp parse_paragraph(text, index) do
  #   id = Id.for_block(:paragraph, index, text)

  #   %Paragraph{
  #     id: id,
  #     inlines: parse_inlines(text, id),
  #     source: text
  #   }
  # end

  # defp parse_code_block(text, index) do
  #   case Regex.run(~r/^```(\w*)\n?([\s\S]*?)\n?```$/s, text, capture: :all_but_first) do
  #     [lang, content] ->
  #       id = Id.for_block(:code_block, index, text)

  #       %CodeBlock{
  #         id: id,
  #         language: if(lang == "", do: nil, else: lang),
  #         text: content,
  #         source: text
  #       }

  #     nil ->
  #       # Malformed code block, treat as paragraph
  #       parse_paragraph(text, index)
  #   end
  # end

  # Parse list items - returns a LIST of blocks (one per item)
  # Falls back to paragraph if no valid list items found
  # defp parse_list_items(text, start_index) do
  #   items = split_list_items(text)

  #   case items do
  #     [] ->
  #       # Empty list marker like "- " - treat as paragraph
  #       parse_paragraph(text, start_index)

  #     _ ->
  #       Enum.with_index(items)
  #       |> Enum.map(fn {item_text, item_idx} ->
  #         id = Id.for_block(:list_item, start_index + item_idx, item_text)
  #         content = strip_list_marker(item_text)

  #         %ListItem{
  #           id: id,
  #           inlines: parse_inlines(content, id),
  #           source: item_text
  #         }
  #       end)
  #   end
  # end

  # defp split_list_items(text) do
  #   # Split by newline followed by list marker
  #   text
  #   |> String.split(~r/\n(?=[-*+]\s)/)
  #   |> Enum.map(&String.trim/1)
  #   |> Enum.reject(&(&1 == ""))
  #   |> Enum.reject(&is_empty_list_item?/1)
  # end

  # # A list item is "empty" if it's just the marker with no content
  # defp is_empty_list_item?(text) do
  #   String.match?(text, ~r/^[-*+]\s*$/)
  # end

  # defp strip_list_marker(text) do
  #   String.replace(text, ~r/^[-*+]\s+/, "")
  # end

  # Private: Inline parsing

  defp parse_inlines(text, block_id) do
    text
    |> tokenize_inlines()
    |> Enum.with_index()
    |> Enum.map(fn {token, idx} -> token_to_inline(token, block_id, idx) end)
  end

  # Tokenize inline markdown into spans
  # Returns list of {:type, content} tuples
  defp tokenize_inlines(text) do
    # Pattern matching for inline elements
    # Order matters: ** before *, ` is highest priority, [[ before [
    regex =
      ~r/(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(\[\[[^\]]+\]\])|(\[[^\]]+\]\([^)]+\))|([^`*\[]+)/

    Regex.scan(regex, text)
    |> Enum.flat_map(fn match ->
      # match is a list where index 0 is full match, rest are capture groups
      case match do
        [full | _groups] -> [classify_inline(full)]
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp classify_inline("`" <> rest) do
    # Inline code
    content = String.trim_trailing(rest, "`")
    {:code, content}
  end

  defp classify_inline("**" <> rest) do
    # Strong
    content = String.trim_trailing(rest, "**")
    {:strong, content}
  end

  defp classify_inline("*" <> rest) do
    # Emphasis
    content = String.trim_trailing(rest, "*")
    {:emphasis, content}
  end

  defp classify_inline("[[" <> rest) do
    # Wiki link: [[text]]
    content = String.trim_trailing(rest, "]]")
    {:wiki_link, content}
  end

  defp classify_inline("[" <> rest) do
    # Link: [text](url)
    case Regex.run(~r/^(.+)\]\(([^)]+)\)$/, rest, capture: :all_but_first) do
      [text, url] -> {:link, text, url}
      nil -> {:text, "[" <> rest}
    end
  end

  defp classify_inline(text) when is_binary(text) and text != "" do
    {:text, text}
  end

  defp classify_inline(_), do: nil

  defp token_to_inline({:text, content}, block_id, idx) do
    %Text{
      id: Id.for_inline(:text, block_id, idx, content),
      text: content
    }
  end

  defp token_to_inline({:code, content}, block_id, idx) do
    %Code{
      id: Id.for_inline(:code, block_id, idx, content),
      text: content
    }
  end

  defp token_to_inline({:emphasis, content}, block_id, idx) do
    id = Id.for_inline(:emphasis, block_id, idx, content)

    %Emphasis{
      id: id,
      # For simplicity, treat emphasis content as plain text
      # Could recursively parse for nested formatting
      children: [%Text{id: "#{id}:t0", text: content}]
    }
  end

  defp token_to_inline({:strong, content}, block_id, idx) do
    id = Id.for_inline(:strong, block_id, idx, content)

    %Strong{
      id: id,
      children: [%Text{id: "#{id}:t0", text: content}]
    }
  end

  defp token_to_inline({:link, text, url}, block_id, idx) do
    id = Id.for_inline(:link, block_id, idx, text <> url)

    %Link{
      id: id,
      url: url,
      children: [%Text{id: "#{id}:t0", text: text}]
    }
  end

  defp token_to_inline({:wiki_link, content}, block_id, idx) do
    %WikiLink{
      id: Id.for_inline(:wiki_link, block_id, idx, content),
      text: content
    }
  end
end
