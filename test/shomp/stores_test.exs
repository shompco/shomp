defmodule Shomp.StoresTest do
  use Shomp.DataCase

  alias Shomp.Stores
  alias Shomp.Stores.Store

  import Shomp.AccountsFixtures

  @valid_attrs %{name: "My Store", slug: "my-store", description: "A great store", user_id: 1}
  @update_attrs %{name: "Updated Store", slug: "updated-store", description: "An updated store"}
  @invalid_attrs %{name: nil, slug: nil, user_id: nil}

  describe "stores" do
    test "list_stores/0 returns all stores" do
      store = store_fixture()
      assert Stores.list_stores() == [store]
    end

    test "get_store!/1 returns the store with given id" do
      store = store_fixture()
      assert Stores.get_store!(store.id) == store
    end

    test "get_store_by_slug/1 returns the store with given slug" do
      store = store_fixture()
      assert Stores.get_store_by_slug(store.slug) == store
    end

    test "get_store_by_slug/1 returns nil for non-existent slug" do
      assert Stores.get_store_by_slug("non-existent") == nil
    end

    test "get_stores_by_user/1 returns stores for given user" do
      user = user_fixture()
      store = store_fixture(%{user_id: user.id})
      assert Stores.get_stores_by_user(user.id) == [store]
    end

    test "create_store/1 with valid data creates a store" do
      user = user_fixture()
      valid_attrs = Map.put(@valid_attrs, :user_id, user.id)

      assert {:ok, %Store{} = store} = Stores.create_store(valid_attrs)
      assert store.name == "My Store"
      assert store.slug == "my-store"
      assert store.description == "A great store"
      assert store.user_id == user.id
    end

    test "create_store/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Stores.create_store(@invalid_attrs)
    end

    test "create_store/1 auto-generates slug from name if not provided" do
      user = user_fixture()
      attrs = %{name: "Auto Slug Store", description: "Test store", user_id: user.id}

      assert {:ok, %Store{} = store} = Stores.create_store(attrs)
      assert store.slug == "auto-slug-store"
    end

    test "create_store/1 uses provided slug if given" do
      user = user_fixture()
      attrs = %{name: "Custom Slug Store", slug: "custom-slug", description: "Test store", user_id: user.id}

      assert {:ok, %Store{} = store} = Stores.create_store(attrs)
      assert store.slug == "custom-slug"
    end

    test "update_store/2 with valid data updates the store" do
      store = store_fixture()
      assert {:ok, %Store{} = updated_store} = Stores.update_store(store, @update_attrs)
      assert updated_store.name == "Updated Store"
      assert updated_store.slug == "updated-store"
      assert updated_store.description == "An updated store"
    end

    test "update_store/2 with invalid data returns error changeset" do
      store = store_fixture()
      assert {:error, %Ecto.Changeset{}} = Stores.update_store(store, @invalid_attrs)
      assert store == Stores.get_store!(store.id)
    end

    test "delete_store/1 deletes the store" do
      store = store_fixture()
      assert {:ok, %Store{}} = Stores.delete_store(store)
      assert_raise Ecto.NoResultsError, fn -> Stores.get_store!(store.id) end
    end

    test "change_store/2 returns a store changeset" do
      store = store_fixture()
      assert %Ecto.Changeset{} = Stores.change_store(store)
    end

    test "change_store_creation/2 returns a store creation changeset" do
      store = %Store{}
      assert %Ecto.Changeset{} = Stores.change_store_creation(store)
    end
  end
end
