defmodule Nota.Notes.NoteTag do
  @moduledoc """
  Join table schema linking notes to tags.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Nota.Notes.Note
  alias Nota.Notes.Tag

  @primary_key false
  schema "notes_tags" do
    belongs_to :note, Note
    belongs_to :tag, Tag
  end

  def changeset(note_tag, attrs) do
    note_tag
    |> cast(attrs, [:note_id, :tag_id])
    |> validate_required([:note_id, :tag_id])
    |> unique_constraint([:note_id, :tag_id])
  end
end
