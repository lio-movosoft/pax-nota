defmodule Nota.NotesTest do
  use Nota.DataCase

  alias Nota.Notes

  describe "notes" do
    alias Nota.Notes.Note

    import Nota.AccountsFixtures, only: [user_scope_fixture: 0]
    import Nota.NotesFixtures

    @invalid_attrs %{body: nil, title: nil}

    test "list_notes/1 returns all scoped notes" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      note = note_fixture(scope)
      other_note = note_fixture(other_scope)
      assert Notes.list_notes(scope) == [note]
      assert Notes.list_notes(other_scope) == [other_note]
    end

    test "get_note!/2 returns the note with given id" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      other_scope = user_scope_fixture()
      assert Notes.get_note!(scope, note.id) == note
      assert_raise Ecto.NoResultsError, fn -> Notes.get_note!(other_scope, note.id) end
    end

    test "create_note/2 with valid data creates a note" do
      valid_attrs = %{body: "some body", title: "some title"}
      scope = user_scope_fixture()

      assert {:ok, %Note{} = note} = Notes.create_note(scope, valid_attrs)
      assert note.body == "some body"
      assert note.title == "some title"
      assert note.user_id == scope.user.id
    end

    test "create_note/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Notes.create_note(scope, @invalid_attrs)
    end

    test "update_note/3 with valid data updates the note" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      update_attrs = %{body: "some updated body", title: "some updated title"}

      assert {:ok, %Note{} = note} = Notes.update_note(scope, note, update_attrs)
      assert note.body == "some updated body"
      assert note.title == "some updated title"
    end

    test "update_note/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      note = note_fixture(scope)

      assert_raise MatchError, fn ->
        Notes.update_note(other_scope, note, %{})
      end
    end

    test "update_note/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Notes.update_note(scope, note, @invalid_attrs)
      assert note == Notes.get_note!(scope, note.id)
    end

    test "delete_note/2 deletes the note" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      assert {:ok, %Note{}} = Notes.delete_note(scope, note)
      assert_raise Ecto.NoResultsError, fn -> Notes.get_note!(scope, note.id) end
    end

    test "delete_note/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      note = note_fixture(scope)
      assert_raise MatchError, fn -> Notes.delete_note(other_scope, note) end
    end

    test "change_note/2 returns a note changeset" do
      scope = user_scope_fixture()
      note = note_fixture(scope)
      assert %Ecto.Changeset{} = Notes.change_note(scope, note)
    end

    test "list_notes/2 with query searches by title and body" do
      scope = user_scope_fixture()
      note_fixture(scope, %{title: "Meeting Notes", body: "Discussed the project timeline"})
      note_fixture(scope, %{title: "Shopping List", body: "Buy groceries for meeting"})
      note_fixture(scope, %{title: "Ideas", body: "Fresh ideas for the app"})

      results = Notes.list_notes(scope, query: "meeting")
      assert length(results) == 2
      # Both notes with "meeting" are found
      titles = Enum.map(results, & &1.title)
      assert "Meeting Notes" in titles
      assert "Shopping List" in titles
    end

    test "list_notes/2 with limit restricts number of results" do
      scope = user_scope_fixture()
      for i <- 1..5, do: note_fixture(scope, %{title: "Note #{i}"})

      results = Notes.list_notes(scope, limit: 3)
      assert length(results) == 3
    end

    test "list_notes/2 orders by ts_rank relevance" do
      scope = user_scope_fixture()
      # Create notes with varying relevance to "project meeting"
      note_fixture(scope, %{title: "Random", body: "project"})
      note_fixture(scope, %{title: "Work", body: "project meeting notes"})
      note_fixture(scope, %{title: "Personal", body: "meeting"})

      results = Notes.list_notes(scope, query: "project meeting")
      # Note with both "project" and "meeting" should rank highest
      assert hd(results).title == "Work"
    end

    test "list_notes/2 without query orders by updated_at desc" do
      scope = user_scope_fixture()
      older = note_fixture(scope, %{title: "Older Note"})
      newer = note_fixture(scope, %{title: "Newer Note"})

      # Manually update timestamps to ensure ordering
      import Ecto.Query
      Nota.Repo.update_all(
        from(n in Note, where: n.id == ^older.id),
        set: [updated_at: ~U[2024-01-01 00:00:00Z]]
      )
      Nota.Repo.update_all(
        from(n in Note, where: n.id == ^newer.id),
        set: [updated_at: ~U[2024-12-01 00:00:00Z]]
      )

      results = Notes.list_notes(scope)
      assert hd(results).id == newer.id
      assert List.last(results).id == older.id
    end

    test "list_notes/2 uses stemming for full-text search on body" do
      scope = user_scope_fixture()
      note_fixture(scope, %{title: "Cooking", body: "Fresh baked goods"})

      # "bake" should match "baked" due to stemming
      results = Notes.list_notes(scope, query: "bake")
      assert length(results) == 1
      assert hd(results).title == "Cooking"
    end

    test "list_notes/2 with partial word matches title using prefix search" do
      scope = user_scope_fixture()
      note_fixture(scope, %{title: "Meeting Notes", body: "Rich and creamy"})
      note_fixture(scope, %{title: "Ideas", body: "Fresh and fruity"})

      # "Meetin" (missing the 'g') should still match "Meeting" in the title
      # because the title uses 'simple' dictionary (no stemming) with prefix matching
      results = Notes.list_notes(scope, query: "Meetin")
      assert length(results) == 1
      assert hd(results).title == "Meeting Notes"
    end
  end
end
