defmodule Nota.Notes do
  @moduledoc """
  The Notes context.
  """

  import Ecto.Query, warn: false
  alias Nota.Repo

  alias Nota.Notes.Note
  alias Nota.Notes.NoteImage
  alias Nota.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any note changes.

  The broadcasted messages match the pattern:

    * {:created, %Note{}}
    * {:updated, %Note{}}
    * {:deleted, %Note{}}

  """
  def subscribe_notes(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Nota.PubSub, "user:#{key}:notes")
  end

  defp broadcast_note(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Nota.PubSub, "user:#{key}:notes", message)
  end

  @doc """
  Returns the list of notes.

  Accepts an optional `opts` keyword list:
    * `:query` - A search string to filter notes (uses full-text search with tsvector)
    * `:limit` - Maximum number of results to return (no limit by default)

  ## Examples

      iex> list_notes(scope)
      [%Note{}, ...]

  """
  def list_notes(%Scope{} = scope, opts \\ []) do
    query = Keyword.get(opts, :query)
    limit = Keyword.get(opts, :limit)
    order_by = Keyword.get(opts, :order_by, :updated_at_desc)

    Note
    |> where(user_id: ^scope.user.id)
    |> join(:left, [n], i in NoteImage, on: i.note_id == n.id and i.is_cover == true)
    |> select_merge([n, i], %{cover_image_key: i.image_key})
    |> maybe_search(query, order_by)
    |> maybe_limit(limit)
    |> Repo.all()
  end

  defp maybe_search(queryable, nil, order_by), do: maybe_sort(queryable, order_by)
  defp maybe_search(queryable, "", order_by), do: maybe_sort(queryable, order_by)

  defp maybe_search(queryable, search_term, _order_by) do
    tsquery = to_prefix_tsquery(search_term)

    # Use 'simple' for title (weight A) since the tsvector uses 'simple' for title,
    # and 'english' for body (weight B) since the tsvector uses 'english' for body.
    # This ensures proper matching: 'simple' doesn't stem, so "chocolat" matches "chocolate".
    # When searching, order by relevance rather than the specified order_by
    queryable
    |> where(
      [n],
      fragment(
        "? @@ (to_tsquery('simple', ?) || to_tsquery('english', ?))",
        n.search_title_body,
        ^tsquery,
        ^tsquery
      )
    )
    |> order_by([n],
      desc:
        fragment(
          "ts_rank(?, to_tsquery('simple', ?) || to_tsquery('english', ?))",
          n.search_title_body,
          ^tsquery,
          ^tsquery
        )
    )
  end

  defp maybe_sort(queryable, :updated_at_desc), do: order_by(queryable, desc: :updated_at)
  defp maybe_sort(queryable, :updated_at_asc), do: order_by(queryable, asc: :updated_at)

  # Converts a search term to a prefix tsquery string
  # "butter chicken" -> "butter:* & chicken:*"
  defp to_prefix_tsquery(search_term) do
    search_term
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&"#{&1}:*")
    |> Enum.join(" & ")
  end

  defp maybe_limit(queryable, nil), do: queryable
  defp maybe_limit(queryable, limit) when is_integer(limit), do: limit(queryable, ^limit)

  @doc """
  Returns the total count of notes across all users.
  """
  def count_notes do
    Repo.aggregate(Note, :count)
  end

  @doc """
  Gets a single note.

  Raises `Ecto.NoResultsError` if the Note does not exist.

  ## Examples

      iex> get_note!(scope, 123)
      %Note{}

      iex> get_note!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_note!(%Scope{} = scope, id) do
    Repo.get_by!(Note, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a note.

  ## Examples

      iex> create_note(scope, %{field: value})
      {:ok, %Note{}}

      iex> create_note(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_note(%Scope{} = scope, attrs) do
    with {:ok, note = %Note{}} <-
           %Note{}
           |> Note.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_note(scope, {:created, note})
      {:ok, note}
    end
  end

  @doc """
  Updates a note.

  ## Examples

      iex> update_note(scope, note, %{field: new_value})
      {:ok, %Note{}}

      iex> update_note(scope, note, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_note(%Scope{} = scope, %Note{} = note, attrs) do
    true = note.user_id == scope.user.id

    with {:ok, note = %Note{}} <-
           note
           |> Note.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_note(scope, {:updated, note})
      {:ok, note}
    end
  end

  @doc """
  Deletes a note.

  ## Examples

      iex> delete_note(scope, note)
      {:ok, %Note{}}

      iex> delete_note(scope, note)
      {:error, %Ecto.Changeset{}}

  """
  def delete_note(%Scope{} = scope, %Note{} = note) do
    true = note.user_id == scope.user.id

    with {:ok, note = %Note{}} <-
           Repo.delete(note) do
      broadcast_note(scope, {:deleted, note})
      {:ok, note}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking note changes.

  ## Examples

      iex> change_note(scope, note)
      %Ecto.Changeset{data: %Note{}}

  """
  def change_note(%Scope{} = scope, %Note{} = note, attrs \\ %{}) do
    true = note.user_id == scope.user.id

    Note.changeset(note, attrs, scope)
  end
end
