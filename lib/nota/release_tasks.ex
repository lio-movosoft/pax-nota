defmodule Nota.ReleaseTasks do
  @app :nota
  @repos Application.compile_env!(@app, :ecto_repos)

  def migrate do
    load_app()

    for repo <- @repos do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp load_app do
    Application.load(@app)
    Enum.each(@repos, &Application.ensure_all_started/1)
  end
end
