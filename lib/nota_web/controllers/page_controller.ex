defmodule NotaWeb.PageController do
  use NotaWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      redirect(conn, to: ~p"/notes")
    else
      render(conn, :home)
    end
  end

  def privacy_policy(conn, _params) do
    render(conn, :privacy_policy)
  end
end
