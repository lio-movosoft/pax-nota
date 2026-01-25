defmodule NotaWeb.Admin.DashboardTest do
  use NotaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Nota.AccountsFixtures

  describe "Admin Dashboard" do
    test "renders dashboard page for god users", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/admin")

      assert html =~ "Admin Dashboard"
    end

    test "redirects normal users to home with error", %{conn: conn} do
      assert {:error, redirect} =
               conn
               |> log_in_user(user_fixture())
               |> live(~p"/admin")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "You are not authorized to access this page."} = flash
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/admin")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "Admin Dashboard Widgets" do
    test "renders users widget with one user", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/admin")

      html = lv |> element("#users-widget") |> render()
      assert html =~ "Total Users</h2>"
      assert html =~ ">1</div>"
    end

    test "renders notes widget with zero notes", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/admin")

      html = lv |> element("#notes-widget") |> render()

      assert html =~ "Total Notes</h2>"
      assert html =~ ">0</div>"
    end
  end
end
