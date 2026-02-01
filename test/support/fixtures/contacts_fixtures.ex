defmodule Nota.ContactsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Nota.Contacts` context.
  """

  @doc """
  Generate a contact.
  """
  def contact_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        first_name: "John",
        last_name: "Doe",
        email: "john.doe#{System.unique_integer()}@example.com",
        phone: "+1234567890"
      })

    {:ok, contact} = Nota.Contacts.create_contact(scope, attrs)
    contact
  end
end
