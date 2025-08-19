defmodule Shomp.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Shomp.Accounts` context.
  """

  import Ecto.Query

  alias Shomp.Accounts
  alias Shomp.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def unique_user_username, do: "user#{System.unique_integer()}"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      name: "Test User",
      username: unique_user_username()
    })
  end

  def valid_user_password_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      name: "Test User",
      username: unique_user_username(),
      password: valid_user_password()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def unconfirmed_user_with_password_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_password_attributes()
      |> Accounts.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    # For password-based users, we need to confirm them differently
    user = unconfirmed_user_with_password_fixture(attrs)
    
    # Confirm the user by updating the confirmed_at field
    {:ok, confirmed_user} = 
      user
      |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now(:second)})
      |> Shomp.Repo.update()
    
    confirmed_user
  end

  def magic_link_user_fixture(attrs \\ %{}) do
    # Create a user without password for magic link testing
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)

    {:ok, {user, _expired_tokens}} =
      Accounts.login_user_by_magic_link(token)

    user
  end

  def mixed_auth_user_fixture(attrs \\ %{}) do
    # Create a user that can use both magic links and passwords
    user = unconfirmed_user_fixture(attrs)
    
    # Confirm the user first
    {:ok, confirmed_user} = 
      user
      |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now(:second)})
      |> Shomp.Repo.update()
    
    # Add a password
    {:ok, user_with_password} = 
      Accounts.add_user_password(confirmed_user, %{password: valid_user_password()})
    
    user_with_password
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def magic_link_user_scope_fixture do
    user = magic_link_user_fixture()
    user_scope_fixture(user)
  end

  def mixed_auth_user_scope_fixture do
    user = mixed_auth_user_fixture()
    user_scope_fixture(user)
  end



  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Shomp.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    Shomp.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Shomp.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
