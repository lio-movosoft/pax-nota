defmodule Nota.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Nota.Repo

  alias Nota.Accounts.{User, UserToken, UserNotifier}

  @doc """
  Subscribes to scoped notifications about any user changes.

  The broadcasted messages match the pattern:

    * {:created, %User{}}
    * {:updated, %User{}}
    * {:deleted, %User{}}

  """

  # def subscribe_users(%Scope{} = scope) do
  #   key = scope.user.id
  #   Phoenix.PubSub.subscribe(Nota.PubSub, "user:#{key}:users")
  # end

  def subscribe_all_users(), do: Phoenix.PubSub.subscribe(Nota.PubSub, "user:all:users")

  # defp broadcast_user(%Scope{} = scope, message) do
  #   key = scope.user.id
  #   Phoenix.PubSub.broadcast(Nota.PubSub, "user:#{key}:users", message)
  # end

  def broadcast_all_users(message),
    do: Phoenix.PubSub.broadcast(Nota.PubSub, "user:all:users", message)

  ## Database getters

  @doc """
  Returns the total count of users.
  """
  def count_users do
    Repo.aggregate(User, :count)
  end

  @doc """
  Returns a list of all users.

  Accepts an optional `opts` keyword list:
    * `:query` - A search string to filter users by email (case-insensitive)
    * `:order_by` - One of `:inserted_at`, `:email`, or `:confirmed_at` (default: `:inserted_at`)
    * `:limit` - Maximum number of results to return (no limit by default)
    * `:filter` - Filter by permission ("superusers" for is_god, "any permission" for no filter, or a specific permission)
  """
  def list_users(opts \\ []) do
    query = Keyword.get(opts, :query)
    order_by = Keyword.get(opts, :order_by, :inserted_at)
    limit = Keyword.get(opts, :limit)
    filter = Keyword.get(opts, :filter)

    User
    |> maybe_search(query)
    |> maybe_filter(filter)
    |> maybe_order_by(order_by)
    |> maybe_limit(limit)
    |> Repo.all()
  end

  defp maybe_search(queryable, nil), do: queryable
  defp maybe_search(queryable, ""), do: queryable

  defp maybe_search(queryable, search_term) do
    search_pattern = "%#{search_term}%"
    from(u in queryable, where: ilike(u.email, ^search_pattern))
  end

  defp maybe_filter(queryable, nil), do: queryable
  defp maybe_filter(queryable, "any permission"), do: queryable

  defp maybe_filter(queryable, "superusers") do
    from(u in queryable, where: u.is_god == true)
  end

  defp maybe_filter(queryable, permission) when is_binary(permission) do
    from(u in queryable, where: ^permission in u.permissions)
  end

  defp maybe_order_by(queryable, :email_asc), do: order_by(queryable, asc: :email)
  defp maybe_order_by(queryable, :email_desc), do: order_by(queryable, desc: :email)
  defp maybe_order_by(queryable, :updated_at_asc), do: order_by(queryable, asc: :updated_at)
  defp maybe_order_by(queryable, :updated_at_desc), do: order_by(queryable, desc: :updated_at)
  defp maybe_order_by(queryable, :inserted_at_asc), do: order_by(queryable, asc: :inserted_at)
  defp maybe_order_by(queryable, _inserted_at_desc), do: order_by(queryable, desc: :inserted_at)

  defp maybe_limit(queryable, nil), do: queryable

  defp maybe_limit(queryable, limit) when is_integer(limit) do
    from(u in queryable, limit: ^limit)
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Updates user fields (email, is_god, permissions).
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.user_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing user fields.

  See `Nota.Accounts.User.user_changeset/3` for options.
  """
  def change_user(%User{} = user, attrs \\ %{}, opts \\ []) do
    User.user_changeset(user, attrs, opts)
  end

  @doc """
  Invites a new user by email.

  Creates an unconfirmed user and sends them an invitation email with a magic link.
  Returns an error if the email is already taken.
  """
  def invite_user(email, invite_url_fun) when is_function(invite_url_fun, 1) do
    case register_user(%{email: email}) do
      {:ok, user} ->
        deliver_invite_instructions(user, invite_url_fun)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Delivers the invite instructions to the given user.
  """
  def deliver_invite_instructions(%User{} = user, invite_url_fun)
      when is_function(invite_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_invite_instructions(user, invite_url_fun.(encoded_token))
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Nota.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Nota.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
