defmodule Nota.Notes do
  @moduledoc """
  The Notes context.
  """

  import Ecto.Query, warn: false

  alias Nota.Accounts.Scope
  alias Nota.Contacts
  alias Nota.Notes.Note
  alias Nota.Notes.NoteTag
  alias Nota.Notes.Tag
  alias Nota.Repo
  alias Nota.Uploads

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
    |> where([n], is_nil(n.contact_id))
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
    |> Enum.map_join(" & ", &"#{&1}:*")
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
      sync_tags(scope, note)
      Contacts.touch_contact(scope, note.contact_id)
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
      sync_tags(scope, note)
      Uploads.sync_images_for_note(note.id, note.body)
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

    # Get tag IDs before deletion for orphan cleanup
    tag_ids =
      from(nt in NoteTag, where: nt.note_id == ^note.id, select: nt.tag_id)
      |> Repo.all()

    # Delete all images for this note (S3 + DB) before deleting the note
    Uploads.delete_all_images_for_note(note.id)

    with {:ok, note = %Note{}} <-
           Repo.delete(note) do
      # Clean up orphaned tags after cascade delete removes notes_tags
      if tag_ids != [], do: delete_orphaned_tags(scope.user.id, tag_ids)
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

  # ===== Tags =====

  @doc """
  Parses #tags from note body text.
  Tags must start with # followed by non-whitespace characters.
  Excludes markdown headers (## with space after).

  Returns a list of unique, lowercased tag labels.

  ## Examples

      iex> parse_tags("Hello #world and #Elixir")
      ["world", "elixir"]

      iex> parse_tags("## Header not a tag")
      []

  """
  def parse_tags(nil), do: []
  def parse_tags(""), do: []

  def parse_tags(body) when is_binary(body) do
    # Match #tag but not ## header (headers have space after #)
    # Tag: # followed by word characters (letters, numbers, underscores, hyphens)
    ~r/(?<![#\w])#([\w-]+)/
    |> Regex.scan(body)
    |> Enum.map(fn [_, tag] -> String.downcase(tag) end)
    |> Enum.uniq()
  end

  @doc """
  Returns tags for a note, preloaded.
  """
  def list_tags_for_note(%Note{} = note) do
    note
    |> Repo.preload(:tags)
    |> Map.get(:tags, [])
  end

  @doc """
  Syncs tags for a note based on the note body.
  - Parses #tags from body
  - Creates new tags if they don't exist for this user
  - Adds note-tag associations for new tags
  - Removes note-tag associations for tags no longer in body
  - Deletes orphaned tags (tags with no remaining note associations)

  Designed to minimize DB queries:
  1. One query to get existing tags for user
  2. One bulk insert for new tags
  3. One query to get current note-tag associations
  4. One bulk insert for new associations
  5. One bulk delete for removed associations
  6. One delete for orphaned tags
  """
  def sync_tags(%Scope{} = scope, %Note{} = note) do
    user_id = scope.user.id
    parsed_labels = parse_tags(note.body)

    # Get all user's existing tags that match parsed labels
    existing_tags =
      from(t in Tag, where: t.user_id == ^user_id and t.label in ^parsed_labels)
      |> Repo.all()

    existing_labels = Enum.map(existing_tags, & &1.label)

    # Create missing tags
    new_labels = parsed_labels -- existing_labels

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    new_tags =
      if new_labels != [] do
        entries =
          Enum.map(new_labels, &%{label: &1, user_id: user_id, inserted_at: now})

        {_, inserted} =
          Repo.insert_all(Tag, entries,
            on_conflict: :nothing,
            returning: true
          )

        inserted
      else
        []
      end

    all_tags = existing_tags ++ new_tags
    tag_ids_by_label = Map.new(all_tags, &{&1.label, &1.id})
    desired_tag_ids = MapSet.new(parsed_labels, &Map.get(tag_ids_by_label, &1))

    # Get current note-tag associations
    current_associations =
      from(nt in NoteTag, where: nt.note_id == ^note.id, select: nt.tag_id)
      |> Repo.all()
      |> MapSet.new()

    # Add new associations
    to_add = MapSet.difference(desired_tag_ids, current_associations) |> MapSet.to_list()

    if to_add != [] do
      entries = Enum.map(to_add, &%{note_id: note.id, tag_id: &1})
      Repo.insert_all(NoteTag, entries, on_conflict: :nothing)
    end

    # Remove old associations
    to_remove = MapSet.difference(current_associations, desired_tag_ids) |> MapSet.to_list()

    if to_remove != [] do
      from(nt in NoteTag, where: nt.note_id == ^note.id and nt.tag_id in ^to_remove)
      |> Repo.delete_all()

      # Delete orphaned tags (tags that no longer have any notes)
      delete_orphaned_tags(user_id, to_remove)
    end

    :ok
  end

  defp delete_orphaned_tags(user_id, tag_ids) do
    # Find tags that have no remaining note associations
    orphaned =
      from(t in Tag,
        where: t.user_id == ^user_id and t.id in ^tag_ids,
        left_join: nt in NoteTag,
        on: nt.tag_id == t.id,
        group_by: t.id,
        having: count(nt.tag_id) == 0,
        select: t.id
      )
      |> Repo.all()

    if orphaned != [] do
      from(t in Tag, where: t.id in ^orphaned)
      |> Repo.delete_all()
    end
  end
end
