defmodule Nota.Repo.Migrations.AddCapabilityToUsersTable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_god, :boolean, default: false, null: false, comment: "Very Simple Role Managmement"
      add :permissions, {:array, :string}, default: [], comment: "List of permissions"
    end
  end
end
