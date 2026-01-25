defmodule Nota.Notes.Note do
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
