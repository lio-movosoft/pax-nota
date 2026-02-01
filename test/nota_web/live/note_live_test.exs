defmodule NotaWeb.NoteLiveTest do
  use NotaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Nota.NotesFixtures
  import Nota.ContactsFixtures

  setup :register_and_log_in_user

  defp create_note(%{scope: scope}) do
    note = note_fixture(scope)

    %{note: note}
  end

  defp create_note_with_contact(%{scope: scope, user: user}) do
    # Grant contacts permission
    user
    |> Ecto.Changeset.change(permissions: ["contacts"])
    |> Nota.Repo.update!()

    contact = contact_fixture(scope)
    note = note_fixture(scope, %{contact_id: contact.id})

    %{note: note, contact: contact}
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

    test "navigates to editor by clicking note row", %{conn: conn, note: note} do
      {:ok, index_live, _html} = live(conn, ~p"/notes")

      assert {:ok, _editor_live, html} =
               index_live
               |> element("#notes-#{note.id} td:first-child")
               |> render_click()
               |> follow_redirect(conn, ~p"/notes/#{note}")

      assert html =~ note.title
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
      |> form("#title-form", %{title: "Updated Title"})
      |> render_change()

      # Should show Save button (dirty state)
      assert has_element?(editor_live, "button", "Save")
    end

    test "saves note", %{conn: conn, note: note} do
      {:ok, editor_live, _html} = live(conn, ~p"/notes/#{note}")

      # Update title to make it dirty
      editor_live
      |> form("#title-form", %{title: "Updated Title"})
      |> render_change()

      # Click save
      html =
        editor_live
        |> element("button", "Save")
        |> render_click()

      assert html =~ "Saved"
    end

    test "deletes note from editor", %{conn: conn, note: note} do
      {:ok, editor_live, _html} = live(conn, ~p"/notes/#{note}")

      # Click delete in dropdown menu
      assert {:ok, _index_live, html} =
               editor_live
               |> element("a", "Delete Note")
               |> render_click()
               |> follow_redirect(conn, ~p"/notes")

      assert html =~ "Note deleted"
      refute html =~ note.title
    end

    test "back button links to /notes when note has no contact", %{conn: conn, note: note} do
      {:ok, _editor_live, html} = live(conn, ~p"/notes/#{note}")

      assert html =~ ~s(href="/notes")
      refute html =~ ~s(href="/contacts/)
    end
  end

  describe "Editor with contact" do
    setup [:create_note_with_contact]

    test "back button links to contact page when note has contact", %{conn: conn, note: note, contact: contact} do
      {:ok, _editor_live, html} = live(conn, ~p"/notes/#{note}")

      assert html =~ ~s(href="/contacts/#{contact.id}")
    end

    test "deletes note and redirects to contact page", %{conn: conn, note: note, contact: contact} do
      {:ok, editor_live, _html} = live(conn, ~p"/notes/#{note}")

      # Click delete in dropdown menu
      assert {:ok, _contact_live, html} =
               editor_live
               |> element("a", "Delete Note")
               |> render_click()
               |> follow_redirect(conn, ~p"/contacts/#{contact}")

      assert html =~ "Note deleted"
      assert html =~ contact.first_name
    end
  end
end
