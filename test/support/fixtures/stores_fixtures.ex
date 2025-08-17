defmodule Shomp.StoresFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Shomp.Stores` context.
  """

  import Shomp.AccountsFixtures

  @doc """
  Generate a store.
  """
  def store_fixture(attrs \\ %{}) do
    user = Map.get(attrs, :user) || user_fixture()

    store_attrs = %{
      name: "some store name",
      slug: "some-store-slug",
      description: "some store description",
      user_id: user.id
    }

    # Merge with provided attrs, but exclude :user since it's not a store field
    attrs = Map.drop(attrs, [:user])
    store_attrs = Map.merge(store_attrs, attrs)

    {:ok, store} = Shomp.Stores.create_store(store_attrs)
    store
  end
end
