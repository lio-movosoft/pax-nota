defmodule NotaWeb.PageControllerTest do
  use NotaWeb.ConnCase

  describe "GET / (landing page)" do
    test "renders the landing page for unauthenticated users", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "Your Notes, Faster. Smarter."
      assert response =~ "Markdown-Ready."
      assert response =~ "PaxNota by Movosoft"
    end

    test "redirects authenticated users to /notes", %{conn: conn} do
      user = Nota.AccountsFixtures.user_fixture()
      conn = conn |> log_in_user(user) |> get(~p"/")

      assert redirected_to(conn) == ~p"/notes"
    end

    test "contains link to register page", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ ~s(href="/users/register")
      assert response =~ "Register Now"
    end

    test "contains link to login page", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ ~s(href="/users/log-in")
      assert response =~ "Log In"
    end

    test "contains link to privacy policy", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ ~s(href="/privacy-policy")
      assert response =~ "Privacy Policy"
    end

    test "register link leads to valid page", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      assert html_response(conn, 200)
    end

    test "login link leads to valid page", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      assert html_response(conn, 200)
    end
  end

  describe "GET /privacy-policy" do
    test "renders the privacy policy page", %{conn: conn} do
      conn = get(conn, ~p"/privacy-policy")
      response = html_response(conn, 200)

      assert response =~ "Privacy Policy"
      assert response =~ "Movosoft"
      assert response =~ "PaxNota"
      assert response =~ "Data Protection"
    end

    test "contains link back to home", %{conn: conn} do
      conn = get(conn, ~p"/privacy-policy")
      response = html_response(conn, 200)

      assert response =~ ~s(href="/")
      assert response =~ "Back to Home"
    end

    test "contains contact email", %{conn: conn} do
      conn = get(conn, ~p"/privacy-policy")
      response = html_response(conn, 200)

      assert response =~ "contact-us@movo-soft.com"
    end
  end
end
