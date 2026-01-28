defmodule Nota.NotesTagsTest do
  use Nota.DataCase

  alias Nota.Notes
  alias Nota.Notes.Tag

  import Nota.AccountsFixtures, only: [user_scope_fixture: 0]
  import Nota.NotesFixtures

  describe "parse_tags/1" do
    test "extracts tags from body text" do
      assert Notes.parse_tags("Hello #world and #elixir") == ["world", "elixir"]
    end

    test "lowercases tags" do
      assert Notes.parse_tags("#Elixir #PHOENIX") == ["elixir", "phoenix"]
    end

    test "returns unique tags" do
      assert Notes.parse_tags("#foo #bar #foo") == ["foo", "bar"]
    end

    test "ignores markdown headers" do
      assert Notes.parse_tags("## Header\n### Another") == []
    end

    test "allows hyphens in tags" do
      assert Notes.parse_tags("#my-tag #another-one") == ["my-tag", "another-one"]
    end

    test "allows underscores in tags" do
      assert Notes.parse_tags("#my_tag #another_one") == ["my_tag", "another_one"]
    end

    test "stops at punctuation" do
      assert Notes.parse_tags("#tag. #tag, #tag!") == ["tag"]
    end

    test "returns empty list for nil" do
      assert Notes.parse_tags(nil) == []
    end

    test "returns empty list for empty string" do
      assert Notes.parse_tags("") == []
    end

    test "handles tags at start of line" do
      assert Notes.parse_tags("#first tag\n#second tag") == ["first", "second"]
    end
  end

  describe "sync_tags/2" do
    test "creates new tags when saving note with tags" do
      scope = user_scope_fixture()
      note = note_fixture(scope, %{body: "Hello #world #elixir"})

      tags = Notes.list_tags_for_note(note)
      labels = Enum.map(tags, & &1.label) |> Enum.sort()

      assert labels == ["elixir", "world"]
    end

    test "tags are scoped to user" do
      scope = user_scope_fixture()
      note = note_fixture(scope, %{body: "Hello #shared"})

      other_scope = user_scope_fixture()
      other_note = note_fixture(other_scope, %{body: "Hello #shared"})

      tags = Notes.list_tags_for_note(note)
      other_tags = Notes.list_tags_for_note(other_note)

      # Each user has their own tag
      assert length(tags) == 1
      assert length(other_tags) == 1
      assert hd(tags).id != hd(other_tags).id
      assert hd(tags).user_id == scope.user.id
      assert hd(other_tags).user_id == other_scope.user.id
    end

    test "reuses existing tags" do
      scope = user_scope_fixture()
      note1 = note_fixture(scope, %{body: "Hello #elixir"})
      note2 = note_fixture(scope, %{body: "World #elixir"})

      tags1 = Notes.list_tags_for_note(note1)
      tags2 = Notes.list_tags_for_note(note2)

      # Same tag is reused
      assert hd(tags1).id == hd(tags2).id
    end

    test "removes tag associations when tag is removed from body" do
      scope = user_scope_fixture()
      note = note_fixture(scope, %{body: "Hello #world #elixir"})

      # Remove #world from body
      {:ok, updated_note} = Notes.update_note(scope, note, %{body: "Hello #elixir"})

      tags = Notes.list_tags_for_note(updated_note)
      labels = Enum.map(tags, & &1.label)

      assert labels == ["elixir"]
    end

    test "deletes orphaned tags" do
      scope = user_scope_fixture()
      note = note_fixture(scope, %{body: "Hello #orphan"})

      # Verify tag exists
      assert Repo.get_by(Tag, label: "orphan", user_id: scope.user.id)

      # Remove the tag
      {:ok, _} = Notes.update_note(scope, note, %{body: "Hello world"})

      # Tag should be deleted since no notes use it
      refute Repo.get_by(Tag, label: "orphan", user_id: scope.user.id)
    end

    test "does not delete tags used by other notes" do
      scope = user_scope_fixture()
      note1 = note_fixture(scope, %{body: "Hello #shared"})
      note2 = note_fixture(scope, %{body: "World #shared"})

      # Remove tag from note1
      {:ok, _} = Notes.update_note(scope, note1, %{body: "Hello world"})

      # Tag should still exist because note2 uses it
      assert Repo.get_by(Tag, label: "shared", user_id: scope.user.id)

      # note2 should still have the tag
      tags = Notes.list_tags_for_note(note2)
      assert hd(tags).label == "shared"
    end

    test "handles note with no tags" do
      scope = user_scope_fixture()
      note = note_fixture(scope, %{body: "Hello world"})

      tags = Notes.list_tags_for_note(note)
      assert tags == []
    end

    test "handles adding new tags to existing note" do
      scope = user_scope_fixture()
      note = note_fixture(scope, %{body: "Hello #old"})

      {:ok, updated} = Notes.update_note(scope, note, %{body: "Hello #old #new"})

      tags = Notes.list_tags_for_note(updated)
      labels = Enum.map(tags, & &1.label) |> Enum.sort()

      assert labels == ["new", "old"]
    end
  end

  describe "cascade deletes" do
    test "deleting note removes note-tag associations" do
      scope = user_scope_fixture()
      note = note_fixture(scope, %{body: "Hello #world"})

      {:ok, _} = Notes.delete_note(scope, note)

      # Tag should be deleted since note was deleted
      refute Repo.get_by(Tag, label: "world", user_id: scope.user.id)
    end

    test "deleting note does not delete tags used by other notes" do
      scope = user_scope_fixture()
      note1 = note_fixture(scope, %{body: "Hello #shared"})
      _note2 = note_fixture(scope, %{body: "World #shared"})

      {:ok, _} = Notes.delete_note(scope, note1)

      # Tag should still exist
      assert Repo.get_by(Tag, label: "shared", user_id: scope.user.id)
    end
  end
end
