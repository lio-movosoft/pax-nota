defmodule Nota.Notes.MarkdownTest do
  use ExUnit.Case, async: true

  alias Nota.Notes.Markdown.Document
  alias Nota.Notes.Markdown.Parser

  alias Document.{Block, ImageBlock}

  describe "ImageBlock struct" do
    test "creates ImageBlock with required fields" do
      block = %ImageBlock{
        id: "mv-1",
        image_key: "user_1_note_2_abc.jpg",
        source: "![](user_1_note_2_abc.jpg)"
      }

      assert block.id == "mv-1"
      assert block.image_key == "user_1_note_2_abc.jpg"
      assert block.alt_text == nil
    end

    test "creates ImageBlock with alt_text" do
      block = %ImageBlock{
        id: "mv-1",
        image_key: "photo.jpg",
        alt_text: "My photo",
        source: "![My photo](photo.jpg)"
      }

      assert block.alt_text == "My photo"
    end
  end

  describe "Document.new_image_block/3" do
    test "creates ImageBlock with correct source" do
      doc = %Document{blocks: []}
      {doc, id} = Document.new_image_block(doc, "user_1_note_1_abc.jpg")

      block = Document.find_block(doc.blocks, id)
      assert %ImageBlock{} = block
      assert block.image_key == "user_1_note_1_abc.jpg"
      assert block.source == "![](user_1_note_1_abc.jpg)"
      assert block.alt_text == ""
    end

    test "creates ImageBlock with alt text" do
      doc = %Document{blocks: []}
      {doc, id} = Document.new_image_block(doc, "key.jpg", alt_text: "My image")

      block = Document.find_block(doc.blocks, id)
      assert block.alt_text == "My image"
      assert block.source == "![My image](key.jpg)"
    end

    test "inserts at beginning when no after option" do
      doc = %Document{
        blocks: [
          %Block{id: "1", type: :p, inlines: [], source: "first"}
        ]
      }

      {doc, new_id} = Document.new_image_block(doc, "key.jpg")

      # New block should be first
      assert hd(doc.blocks).id == new_id
      assert length(doc.blocks) == 2
    end

    test "inserts after specified block" do
      doc = %Document{
        blocks: [
          %Block{id: "1", type: :p, inlines: [], source: "first"},
          %Block{id: "2", type: :p, inlines: [], source: "second"}
        ]
      }

      {doc, new_id} = Document.new_image_block(doc, "key.jpg", after: "1")

      # Block order: 1, new, 2
      ids = Enum.map(doc.blocks, & &1.id)
      assert ids == ["1", new_id, "2"]
      assert %ImageBlock{} = Enum.at(doc.blocks, 1)
    end
  end

  describe "Parser - ImageBlock parsing" do
    test "parses standalone image" do
      doc = Parser.parse("![alt text](image_key.jpg)")

      assert [%ImageBlock{image_key: "image_key.jpg", alt_text: "alt text"}] = doc.blocks
    end

    test "parses image without alt text" do
      doc = Parser.parse("![](key.png)")

      assert [%ImageBlock{image_key: "key.png", alt_text: nil}] = doc.blocks
    end

    test "parses mixed content with images" do
      markdown = """
      # Heading

      ![photo](abc.jpg)

      Some text
      """

      doc = Parser.parse(markdown)

      assert [%Block{type: :h1}, %ImageBlock{}, %Block{type: :p}] = doc.blocks
    end

    test "preserves image block source for round-trip" do
      doc = Parser.parse("![photo](key.jpg)")

      assert Parser.to_markdown(doc) == "![photo](key.jpg)"
    end

    test "round-trips mixed content" do
      markdown = """
      # Title

      ![](image.jpg)

      Text after
      """

      doc = Parser.parse(markdown)
      result = Parser.to_markdown(doc)

      # Normalize whitespace for comparison
      assert String.trim(result) == String.trim(markdown)
    end

    test "handles image with complex key" do
      markdown = "![](user_123_note_456_abc123xyz.jpg)"
      doc = Parser.parse(markdown)

      assert [%ImageBlock{image_key: "user_123_note_456_abc123xyz.jpg"}] = doc.blocks
    end

    test "treats malformed image syntax as paragraph" do
      # Missing closing paren
      doc = Parser.parse("![alt](key.jpg")

      assert [%Block{type: :p}] = doc.blocks
    end
  end

  describe "Parser - combined block types" do
    test "parses document with all block types" do
      markdown = """
      # Heading 1

      ## Heading 2

      Regular paragraph

      ![](image.jpg)

      ```
      code block
      ```

      - list item

      1. ordered item
      """

      doc = Parser.parse(markdown)

      types =
        Enum.map(doc.blocks, fn
          %Block{type: type} -> type
          %ImageBlock{} -> :image
          %Document.CodeBlock{} -> :code
        end)

      assert types == [:h1, :h2, :p, :image, :code, :li, :oli]
    end
  end
end
