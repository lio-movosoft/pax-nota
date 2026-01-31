defmodule Nota.Contacts.Contact do
  @moduledoc """
  Schema for user contacts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Nota.Accounts.User

  schema "contacts" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :phone, :string
    field :linkedin_url, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contact, attrs, scope) do
    contact
    |> cast(attrs, [:first_name, :last_name, :email, :phone, :linkedin_url])
    |> validate_required([:first_name])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/, message: "must be a valid email")
    |> validate_format(:linkedin_url, ~r/^https?:\/\/(www\.)?linkedin\.com\//,
      message: "must be a valid LinkedIn URL"
    )
    |> put_change(:user_id, scope.user.id)
  end
end
