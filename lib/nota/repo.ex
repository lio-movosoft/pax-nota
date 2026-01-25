defmodule Nota.Repo do
  use Ecto.Repo,
    otp_app: :nota,
    adapter: Ecto.Adapters.Postgres
end
