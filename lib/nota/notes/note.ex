defmodule Nota.Notes.Note do
  @moduledoc """
  Schema for user notes with title, body, and full-text search support.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :title, :string
    field :body, :string
    field :user_id, :id

    field :cover_image_key, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs, scope) do
    note
    |> cast(attrs, [:title, :body])
    |> validate_required([:title])
    |> put_change(:user_id, scope.user.id)
  end
end
