defmodule Nota.Notes.Tag do
  @moduledoc """
  Schema for user-scoped tags that can be applied to notes.
  Tags are parsed from note body using #tag syntax.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Nota.Accounts.User
  alias Nota.Notes.NoteTag

  schema "tags" do
    field :label, :string

    belongs_to :user, User
    has_many :notes_tags, NoteTag

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:label, :user_id])
    |> validate_required([:label, :user_id])
    |> unique_constraint([:user_id, :label])
  end
end
