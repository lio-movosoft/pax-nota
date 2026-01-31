defmodule Nota.UploadsTest do
  use Nota.DataCase

  alias Nota.Notes.NoteImage
  alias Nota.Uploads

  import Nota.AccountsFixtures, only: [user_scope_fixture: 0]
  import Nota.NotesFixtures

  describe "parse_image_keys/1" do
    test "extracts image keys from markdown" do
      body = "Text ![alt](key1.jpg) more ![](key2.png)"

      assert Uploads.parse_image_keys(body) == ["key1.jpg", "key2.png"]
    end

    test "returns unique keys" do
      body = "![](key.jpg) text ![](key.jpg)"

      assert Uploads.parse_image_keys(body) == ["key.jpg"]
    end

    test "returns empty list for nil" do
      assert Uploads.parse_image_keys(nil) == []
    end

    test "returns empty list for empty string" do
      assert Uploads.parse_image_keys("") == []
    end

    test "handles complex image keys" do
      body = "![photo](user_1_note_2_abc123.jpg)"

      assert Uploads.parse_image_keys(body) == ["user_1_note_2_abc123.jpg"]
    end

    test "extracts only image syntax, not regular links" do
      body = "[link](url.html) ![image](image.jpg)"

      assert Uploads.parse_image_keys(body) == ["image.jpg"]
    end

    test "handles images with various alt text" do
      body = """
      ![](no-alt.jpg)
      ![with alt text](with-alt.jpg)
      ![special chars: 123!](special.jpg)
      """

      assert Uploads.parse_image_keys(body) == ["no-alt.jpg", "with-alt.jpg", "special.jpg"]
    end
  end

  describe "sync_images_for_note/2" do
    test "deletes orphaned images" do
      scope = user_scope_fixture()
      note = note_fixture(scope)

      # Create an image that's not referenced in the body
      {:ok, image} =
        Uploads.create_image(%{
          image_key: "orphan_key.jpg",
          note_id: note.id
        })

      # Sync with body that doesn't reference the image
      Uploads.sync_images_for_note(note.id, "No images here")

      # Image should be deleted
      refute Repo.get(NoteImage, image.id)
    end

    test "keeps referenced images" do
      scope = user_scope_fixture()
      note = note_fixture(scope)

      {:ok, image} =
        Uploads.create_image(%{
          image_key: "keep_me.jpg",
          note_id: note.id
        })

      Uploads.sync_images_for_note(note.id, "![](keep_me.jpg)")

      # Image should still exist
      assert Repo.get(NoteImage, image.id)
    end

    test "handles multiple images - keeps some, deletes others" do
      scope = user_scope_fixture()
      note = note_fixture(scope)

      {:ok, keep1} =
        Uploads.create_image(%{image_key: "keep1.jpg", note_id: note.id})

      {:ok, keep2} =
        Uploads.create_image(%{image_key: "keep2.jpg", note_id: note.id})

      {:ok, delete1} =
        Uploads.create_image(%{image_key: "delete1.jpg", note_id: note.id})

      body = "![](keep1.jpg) text ![](keep2.jpg)"
      Uploads.sync_images_for_note(note.id, body)

      assert Repo.get(NoteImage, keep1.id)
      assert Repo.get(NoteImage, keep2.id)
      refute Repo.get(NoteImage, delete1.id)
    end

    test "handles empty body - deletes all images" do
      scope = user_scope_fixture()
      note = note_fixture(scope)

      {:ok, image} =
        Uploads.create_image(%{image_key: "will_delete.jpg", note_id: note.id})

      Uploads.sync_images_for_note(note.id, "")

      refute Repo.get(NoteImage, image.id)
    end

    test "handles nil body - deletes all images" do
      scope = user_scope_fixture()
      note = note_fixture(scope)

      {:ok, image} =
        Uploads.create_image(%{image_key: "will_delete.jpg", note_id: note.id})

      Uploads.sync_images_for_note(note.id, nil)

      refute Repo.get(NoteImage, image.id)
    end
  end

  describe "delete_all_images_for_note/1" do
    test "deletes all images for a note" do
      scope = user_scope_fixture()
      note = note_fixture(scope)

      {:ok, img1} =
        Uploads.create_image(%{image_key: "img1.jpg", note_id: note.id})

      {:ok, img2} =
        Uploads.create_image(%{image_key: "img2.jpg", note_id: note.id})

      Uploads.delete_all_images_for_note(note.id)

      refute Repo.get(NoteImage, img1.id)
      refute Repo.get(NoteImage, img2.id)
    end

    test "does nothing for note with no images" do
      scope = user_scope_fixture()
      note = note_fixture(scope)

      # Should not raise
      assert Uploads.delete_all_images_for_note(note.id) == :ok
    end
  end
end
