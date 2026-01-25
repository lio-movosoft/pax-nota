# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seed_users.exs
#

first_names = [
  "Alice",
  "Bob",
  "Charlie",
  "Diana",
  "Eve",
  "Frank",
  "Grace",
  "Hank",
  "Ivy",
  "Jack",
  "Kara",
  "Leo",
  "Mona",
  "Nick",
  "Olive",
  "Paul",
  "Quinn",
  "Rose",
  "Sam",
  "Tina"
]

last_names = [
  "Johnson",
  "Smith",
  "Williams",
  "Brown",
  "Taylor",
  "Davis",
  "Miller",
  "Wilson",
  "Moore",
  "Anderson",
  "Thomas",
  "Jackson",
  "White",
  "Harris",
  "Martin",
  "Thompson",
  "Garcia",
  "Martinez",
  "Robinson",
  "Clark"
]

combos = for first <- first_names, last <- last_names, do: "#{first}.#{last}@test.com"

Enum.shuffle(combos)
|> Enum.take(128)
|> Enum.each(fn name ->
  Nota.Repo.insert!(%Nota.Accounts.User{email: name},
    on_conflict: :nothing
  )
end)
