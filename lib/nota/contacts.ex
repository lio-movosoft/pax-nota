defmodule Nota.Contacts do
  @moduledoc """
  The Contacts context.
  """

  import Ecto.Query, warn: false

  alias Nota.Accounts.Scope
  alias Nota.Contacts.Contact
  alias Nota.Repo

  @doc """
  Subscribes to scoped notifications about any contact changes.

  The broadcasted messages match the pattern:

    * {:created, %Contact{}}
    * {:updated, %Contact{}}
    * {:deleted, %Contact{}}

  """
  def subscribe_contacts(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Nota.PubSub, "user:#{key}:contacts")
  end

  defp broadcast_contact(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Nota.PubSub, "user:#{key}:contacts", message)
  end

  @doc """
  Returns the list of contacts.

  Accepts an optional `opts` keyword list:
    * `:query` - A search string to filter contacts by first or last name
    * `:limit` - Maximum number of results to return
    * `:order_by` - Sort order (default: :inserted_at_desc)

  ## Examples

      iex> list_contacts(scope)
      [%Contact{}, ...]

  """
  def list_contacts(%Scope{} = scope, opts \\ []) do
    query = Keyword.get(opts, :query)
    limit = Keyword.get(opts, :limit)
    order_by = Keyword.get(opts, :order_by, :updated_at_desc)

    Contact
    |> where(user_id: ^scope.user.id)
    |> maybe_search(query)
    |> maybe_order_by(order_by)
    |> maybe_limit(limit)
    |> Repo.all()
  end

  defp maybe_search(queryable, nil), do: queryable
  defp maybe_search(queryable, ""), do: queryable

  defp maybe_search(queryable, search_term) do
    search_pattern = "%#{search_term}%"

    queryable
    |> where(
      [c],
      ilike(c.first_name, ^search_pattern) or ilike(c.last_name, ^search_pattern)
    )
  end

  defp maybe_order_by(queryable, :inserted_at_desc), do: order_by(queryable, desc: :inserted_at)
  defp maybe_order_by(queryable, :inserted_at_asc), do: order_by(queryable, asc: :inserted_at)
  defp maybe_order_by(queryable, :updated_at_desc), do: order_by(queryable, desc: :updated_at)
  defp maybe_order_by(queryable, :updated_at_asc), do: order_by(queryable, asc: :updated_at)
  defp maybe_order_by(queryable, :first_name_asc), do: order_by(queryable, asc: :first_name)
  defp maybe_order_by(queryable, :first_name_desc), do: order_by(queryable, desc: :first_name)
  defp maybe_order_by(queryable, :last_name_asc), do: order_by(queryable, asc: :last_name)
  defp maybe_order_by(queryable, :last_name_desc), do: order_by(queryable, desc: :last_name)

  defp maybe_limit(queryable, nil), do: queryable
  defp maybe_limit(queryable, limit) when is_integer(limit), do: limit(queryable, ^limit)

  @doc """
  Gets a single contact.

  Raises `Ecto.NoResultsError` if the Contact does not exist.

  ## Examples

      iex> get_contact!(scope, 123)
      %Contact{}

      iex> get_contact!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_contact!(%Scope{} = scope, id) do
    Repo.get_by!(Contact, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a contact.

  ## Examples

      iex> create_contact(scope, %{field: value})
      {:ok, %Contact{}}

      iex> create_contact(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_contact(%Scope{} = scope, attrs) do
    with {:ok, contact = %Contact{}} <-
           %Contact{}
           |> Contact.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_contact(scope, {:created, contact})
      {:ok, contact}
    end
  end

  @doc """
  Updates a contact.

  ## Examples

      iex> update_contact(scope, contact, %{field: new_value})
      {:ok, %Contact{}}

      iex> update_contact(scope, contact, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_contact(%Scope{} = scope, %Contact{} = contact, attrs) do
    true = contact.user_id == scope.user.id

    with {:ok, contact = %Contact{}} <-
           contact
           |> Contact.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_contact(scope, {:updated, contact})
      {:ok, contact}
    end
  end

  @doc """
  Deletes a contact.

  ## Examples

      iex> delete_contact(scope, contact)
      {:ok, %Contact{}}

      iex> delete_contact(scope, contact)
      {:error, %Ecto.Changeset{}}

  """
  def delete_contact(%Scope{} = scope, %Contact{} = contact) do
    true = contact.user_id == scope.user.id

    with {:ok, contact = %Contact{}} <- Repo.delete(contact) do
      broadcast_contact(scope, {:deleted, contact})
      {:ok, contact}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking contact changes.

  ## Examples

      iex> change_contact(scope, contact)
      %Ecto.Changeset{data: %Contact{}}

  """
  def change_contact(%Scope{} = scope, %Contact{} = contact, attrs \\ %{}) do
    true = contact.user_id == scope.user.id

    Contact.changeset(contact, attrs, scope)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for a new contact.
  """
  def change_new_contact(%Scope{} = scope, attrs \\ %{}) do
    Contact.changeset(%Contact{user_id: scope.user.id}, attrs, scope)
  end
end
