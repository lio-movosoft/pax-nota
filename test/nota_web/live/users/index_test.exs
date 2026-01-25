defmodule NotaWeb.Users.IndexTest do
  use NotaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Nota.AccountsFixtures

  describe "Users page" do
    test "renders users page for god users", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/users")

      assert html =~ "User Management"
    end

    test "renders users page for users with :users permission", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(%{permissions: [:users]}))
        |> live(~p"/users")

      assert html =~ "User Management"
    end

    test "redirects users without :users permission", %{conn: conn} do
      assert {:error, redirect} =
               conn
               |> log_in_user(user_fixture())
               |> live(~p"/users")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "You are not authorized to access this page."} = flash
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "User listing" do
    test "lists all users", %{conn: conn} do
      user1 = user_fixture(%{email: "user1@example.com"})
      user2 = user_fixture(%{email: "user2@example.com"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/users")

      assert html =~ user1.email
      assert html =~ user2.email
    end
  end

  describe "User editing" do
    test "can edit a user's permissions", %{conn: conn} do
      target_user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/users/#{target_user.id}/edit")

      lv
      |> form("#user-form", %{
        "user" => %{"permissions" => ["users", "recipes"]}
      })
      |> render_submit()

      updated_user = Nota.Accounts.get_user!(target_user.id)
      assert "users" in updated_user.permissions
      assert "recipes" in updated_user.permissions
    end

    test "can toggle is_god status", %{conn: conn} do
      target_user = user_fixture()
      refute target_user.is_god

      {:ok, lv, _html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/users/#{target_user.id}/edit")

      lv
      |> form("#user-form", %{
        "user" => %{"is_god" => "true"}
      })
      |> render_submit()

      updated_user = Nota.Accounts.get_user!(target_user.id)
      assert updated_user.is_god
    end

    test "can change a user's email", %{conn: conn} do
      target_user = user_fixture()
      new_email = "newemail@example.com"

      {:ok, lv, _html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/users/#{target_user.id}/edit")

      lv
      |> form("#user-form", %{
        "user" => %{"email" => new_email}
      })
      |> render_submit()

      updated_user = Nota.Accounts.get_user!(target_user.id)
      assert updated_user.email == new_email
    end
  end

  describe "User deletion" do
    test "can delete a user", %{conn: conn} do
      target_user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/users")

      lv
      |> element("#users-#{target_user.id} a[data-confirm]", "Delete")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn -> Nota.Accounts.get_user!(target_user.id) end
    end
  end

  describe "User invitation" do
    test "can invite a new user by email", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/users/invite")

      lv
      |> form("#invite-form", %{
        "invite" => %{"email" => "newuser@example.com"}
      })
      |> render_submit()

      # Follow redirect to /users and check flash
      assert_redirect(lv, "/users")

      invited_user = Nota.Accounts.get_user_by_email("newuser@example.com")
      assert invited_user
      refute invited_user.confirmed_at
    end

    test "shows error when inviting existing email", %{conn: conn} do
      existing_user = user_fixture(%{email: "existing@example.com"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(god_fixture())
        |> live(~p"/users/invite")

      result =
        lv
        |> form("#invite-form", %{
          "invite" => %{"email" => existing_user.email}
        })
        |> render_submit()

      assert result =~ "Failed to invite"
    end
  end
end
