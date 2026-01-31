defmodule Nota.Notes.NoteImage do
  @moduledoc """
  Schema for images attached to notes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Nota.Notes.Note

  schema "note_images" do
    field :image_key, :string

    belongs_to :note, Note

    timestamps(type: :utc_datetime)
  end

  def changeset(note_image, attrs) do
    note_image
    |> cast(attrs, [:image_key, :note_id])
    |> validate_required([:image_key, :note_id])
  end
end
