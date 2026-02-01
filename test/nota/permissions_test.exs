defmodule Nota.PermissionsTest do
  use Nota.DataCase

  alias Nota.Accounts.User
  alias Nota.Permissions

  describe "can?/2" do
    test "god can do anything" do
      assert Permissions.can?(%User{is_god: true}, :users)
    end

    test "permission must be present" do
      refute Permissions.can?(%User{permissions: []}, :users)
      assert Permissions.can?(%User{permissions: ["users"]}, :users)
    end
  end
end
