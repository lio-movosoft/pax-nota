defmodule NotaWeb.PageController do
  use NotaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
