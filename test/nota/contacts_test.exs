defmodule Nota.ContactsTest do
  use Nota.DataCase

  alias Nota.Contacts

  describe "contacts" do
    alias Nota.Contacts.Contact

    import Nota.AccountsFixtures, only: [user_scope_fixture: 0]
    import Nota.ContactsFixtures
    import Nota.NotesFixtures

    @invalid_attrs %{first_name: nil}

    test "list_contacts/1 returns all scoped contacts" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      contact = contact_fixture(scope)
      other_contact = contact_fixture(other_scope)

      assert Contacts.list_contacts(scope) == [contact]
      assert Contacts.list_contacts(other_scope) == [other_contact]
    end

    test "get_contact!/2 returns the contact with given id" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)
      other_scope = user_scope_fixture()

      assert Contacts.get_contact!(scope, contact.id) == contact
      assert_raise Ecto.NoResultsError, fn -> Contacts.get_contact!(other_scope, contact.id) end
    end

    test "create_contact/2 with valid data creates a contact" do
      scope = user_scope_fixture()
      valid_attrs = %{first_name: "Jane", last_name: "Smith", email: "jane@example.com"}

      assert {:ok, %Contact{} = contact} = Contacts.create_contact(scope, valid_attrs)
      assert contact.first_name == "Jane"
      assert contact.last_name == "Smith"
      assert contact.email == "jane@example.com"
      assert contact.user_id == scope.user.id
    end

    test "create_contact/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Contacts.create_contact(scope, @invalid_attrs)
    end

    test "create_contact/2 validates email format" do
      scope = user_scope_fixture()
      invalid_email_attrs = %{first_name: "Test", email: "not-an-email"}

      assert {:error, changeset} = Contacts.create_contact(scope, invalid_email_attrs)
      assert "must be a valid email" in errors_on(changeset).email
    end

    test "create_contact/2 validates linkedin_url format" do
      scope = user_scope_fixture()
      invalid_url_attrs = %{first_name: "Test", linkedin_url: "https://twitter.com/user"}

      assert {:error, changeset} = Contacts.create_contact(scope, invalid_url_attrs)
      assert "must be a valid LinkedIn URL" in errors_on(changeset).linkedin_url
    end

    test "update_contact/3 with valid data updates the contact" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)
      update_attrs = %{first_name: "Updated", last_name: "Name"}

      assert {:ok, %Contact{} = contact} = Contacts.update_contact(scope, contact, update_attrs)
      assert contact.first_name == "Updated"
      assert contact.last_name == "Name"
    end

    test "update_contact/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      contact = contact_fixture(scope)

      assert_raise MatchError, fn ->
        Contacts.update_contact(other_scope, contact, %{})
      end
    end

    test "update_contact/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)

      assert {:error, %Ecto.Changeset{}} = Contacts.update_contact(scope, contact, @invalid_attrs)
      assert contact == Contacts.get_contact!(scope, contact.id)
    end

    test "delete_contact/2 deletes the contact" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)

      assert {:ok, %Contact{}} = Contacts.delete_contact(scope, contact)
      assert_raise Ecto.NoResultsError, fn -> Contacts.get_contact!(scope, contact.id) end
    end

    test "delete_contact/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      contact = contact_fixture(scope)

      assert_raise MatchError, fn -> Contacts.delete_contact(other_scope, contact) end
    end

    test "change_contact/2 returns a contact changeset" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)

      assert %Ecto.Changeset{} = Contacts.change_contact(scope, contact)
    end

    test "change_new_contact/2 returns a changeset for new contact" do
      scope = user_scope_fixture()

      assert %Ecto.Changeset{} = Contacts.change_new_contact(scope)
    end

    test "list_contacts/2 with query searches by first_name" do
      scope = user_scope_fixture()
      contact_fixture(scope, %{first_name: "Alice", last_name: "Smith"})
      contact_fixture(scope, %{first_name: "Bob", last_name: "Jones"})

      results = Contacts.list_contacts(scope, query: "Alice")
      assert length(results) == 1
      assert hd(results).first_name == "Alice"
    end

    test "list_contacts/2 with query searches by last_name" do
      scope = user_scope_fixture()
      contact_fixture(scope, %{first_name: "Alice", last_name: "Smith"})
      contact_fixture(scope, %{first_name: "Bob", last_name: "Jones"})

      results = Contacts.list_contacts(scope, query: "Jones")
      assert length(results) == 1
      assert hd(results).first_name == "Bob"
    end

    test "list_contacts/2 with limit restricts number of results" do
      scope = user_scope_fixture()
      for i <- 1..5, do: contact_fixture(scope, %{first_name: "Contact#{i}"})

      results = Contacts.list_contacts(scope, limit: 3)
      assert length(results) == 3
    end

    test "list_contacts/2 orders by updated_at desc by default" do
      scope = user_scope_fixture()
      older = contact_fixture(scope, %{first_name: "Older"})
      newer = contact_fixture(scope, %{first_name: "Newer"})

      import Ecto.Query
      Nota.Repo.update_all(
        from(c in Contact, where: c.id == ^older.id),
        set: [updated_at: ~U[2024-01-01 00:00:00Z]]
      )
      Nota.Repo.update_all(
        from(c in Contact, where: c.id == ^newer.id),
        set: [updated_at: ~U[2024-12-01 00:00:00Z]]
      )

      results = Contacts.list_contacts(scope)
      assert hd(results).id == newer.id
      assert List.last(results).id == older.id
    end

    test "list_notes_for_contact/2 returns notes attached to contact" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)

      note1 = note_fixture(scope, %{title: "Note 1", contact_id: contact.id})
      note2 = note_fixture(scope, %{title: "Note 2", contact_id: contact.id})
      _unrelated_note = note_fixture(scope, %{title: "Unrelated"})

      notes = Contacts.list_notes_for_contact(scope, contact)
      note_ids = Enum.map(notes, & &1.id)

      assert length(notes) == 2
      assert note1.id in note_ids
      assert note2.id in note_ids
    end

    test "list_notes_for_contact/2 orders by updated_at desc" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)

      older = note_fixture(scope, %{title: "Older", contact_id: contact.id})
      newer = note_fixture(scope, %{title: "Newer", contact_id: contact.id})

      import Ecto.Query
      alias Nota.Notes.Note

      Nota.Repo.update_all(
        from(n in Note, where: n.id == ^older.id),
        set: [updated_at: ~U[2024-01-01 00:00:00Z]]
      )
      Nota.Repo.update_all(
        from(n in Note, where: n.id == ^newer.id),
        set: [updated_at: ~U[2024-12-01 00:00:00Z]]
      )

      notes = Contacts.list_notes_for_contact(scope, contact)
      assert hd(notes).id == newer.id
      assert List.last(notes).id == older.id
    end

    test "list_notes_for_contact/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      contact = contact_fixture(scope)

      assert_raise MatchError, fn ->
        Contacts.list_notes_for_contact(other_scope, contact)
      end
    end

    test "touch_contact/2 updates contact updated_at" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)

      # Set updated_at to an old date
      import Ecto.Query
      old_time = ~U[2024-01-01 00:00:00Z]
      Nota.Repo.update_all(
        from(c in Contact, where: c.id == ^contact.id),
        set: [updated_at: old_time]
      )

      # Verify it was set
      contact = Contacts.get_contact!(scope, contact.id)
      assert contact.updated_at == old_time

      # Touch the contact
      Contacts.touch_contact(scope, contact.id)

      # Verify updated_at was updated
      contact = Contacts.get_contact!(scope, contact.id)
      assert DateTime.compare(contact.updated_at, old_time) == :gt
    end

    test "touch_contact/2 with nil does nothing" do
      scope = user_scope_fixture()
      assert Contacts.touch_contact(scope, nil) == :ok
    end

    test "creating note with contact_id touches the contact" do
      scope = user_scope_fixture()
      contact = contact_fixture(scope)

      # Set contact updated_at to an old date
      import Ecto.Query
      old_time = ~U[2024-01-01 00:00:00Z]
      Nota.Repo.update_all(
        from(c in Contact, where: c.id == ^contact.id),
        set: [updated_at: old_time]
      )

      # Create a note attached to the contact
      {:ok, _note} = Nota.Notes.create_note(scope, %{
        title: "Test Note",
        contact_id: contact.id
      })

      # Verify contact's updated_at was updated
      contact = Contacts.get_contact!(scope, contact.id)
      assert DateTime.compare(contact.updated_at, old_time) == :gt
    end
  end
end
