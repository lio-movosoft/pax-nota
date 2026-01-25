defmodule NotaWeb.NoteLiveTest do
  use NotaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Nota.NotesFixtures

  setup :register_and_log_in_user

  defp create_note(%{scope: scope}) do
    note = note_fixture(scope)

    %{note: note}
  end

  describe "Index" do
    setup [:create_note]

    test "lists all notes", %{conn: conn, note: note} do
      {:ok, _index_live, html} = live(conn, ~p"/notes")

      assert html =~ "My Notes"
      assert html =~ note.title
    end

    test "creates new note and redirects to editor", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/notes")

      # Click "New Note" button - creates note and redirects to editor
      assert {:ok, _editor_live, html} =
               index_live
               |> element("button", "New Note")
               |> render_click()
               |> follow_redirect(conn)

      # Should be in editor with default title
      assert html =~ "Hello Note"
    end

    test "navigates to editor from listing", %{conn: conn, note: note} do
      {:ok, index_live, _html} = live(conn, ~p"/notes")

      assert {:ok, _editor_live, html} =
               index_live
               |> element("#notes-#{note.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/notes/#{note}")

      assert html =~ note.title
    end

    test "deletes note in listing", %{conn: conn, note: note} do
      {:ok, index_live, _html} = live(conn, ~p"/notes")

      assert index_live |> element("#notes-#{note.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#notes-#{note.id}")
    end
  end

  describe "Editor" do
    setup [:create_note]

    test "displays note in editor", %{conn: conn, note: note} do
      {:ok, _editor_live, html} = live(conn, ~p"/notes/#{note}")

      assert html =~ note.title
    end

    test "updates title", %{conn: conn, note: note} do
      {:ok, editor_live, _html} = live(conn, ~p"/notes/#{note}")

      # Update the title
      editor_live
      |> form("form", %{title: "Updated Title"})
      |> render_change()

      # Should show Save button (dirty state)
      assert has_element?(editor_live, "button", "Save")
    end

    test "saves note", %{conn: conn, note: note} do
      {:ok, editor_live, _html} = live(conn, ~p"/notes/#{note}")

      # Update title to make it dirty
      editor_live
      |> form("form", %{title: "Updated Title"})
      |> render_change()

      # Click save
      html =
        editor_live
        |> element("button", "Save")
        |> render_click()

      assert html =~ "Saved"
    end

    test "opens images modal", %{conn: conn, note: note} do
      {:ok, editor_live, _html} = live(conn, ~p"/notes/#{note}")

      # Navigate to images
      assert {:ok, _editor_live, html} =
               editor_live
               |> element("a[href=\"/notes/#{note.id}/images\"]")
               |> render_click()
               |> follow_redirect(conn, ~p"/notes/#{note}/images")

      assert html =~ "Images"
    end
  end
end
