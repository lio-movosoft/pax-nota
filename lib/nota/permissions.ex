defmodule Nota.Permissions do
  @moduledoc """
  A Module to handle Super Simple Permissions
  """

  alias Nota.Accounts.User

  def can?(%User{is_god: true}, _perm), do: true

  def can?(%User{permissions: perms}, perm) when is_atom(perm) do
    Atom.to_string(perm) in perms
  end
end
