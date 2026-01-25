# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Nota.Repo.insert!(%Nota.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
if Mix.env() != :test do
  Nota.Repo.insert!(%Nota.Accounts.User{email: "lionel@movo-soft.com", is_god: true},
    on_conflict: :nothing
  )
end
