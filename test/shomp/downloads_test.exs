defmodule Shomp.DownloadsTest do
  use Shomp.DataCase

  alias Shomp.Downloads
  alias Shomp.Downloads.Download
  alias Shomp.AccountsFixtures
  alias Shomp.StoresFixtures
  alias Shomp.ProductsFixtures

  describe "downloads" do

    test "create_download_link/1 with valid data creates a download" do
      user = AccountsFixtures.user_fixture()
      store = StoresFixtures.store_fixture(%{user: user})
      product = ProductsFixtures.product_fixture(%{store: store})

      attrs = %{product_id: product.id, user_id: user.id}
      assert {:ok, %Download{} = download} = Downloads.create_download_link(attrs)
      assert download.product_id == product.id
      assert download.user_id == user.id
      assert download.download_count == 0
      assert download.token != nil
      assert download.last_downloaded_at == nil
    end

    test "get_download_by_token/1 returns the download with given token" do
      user = AccountsFixtures.user_fixture()
      store = StoresFixtures.store_fixture(%{user: user})
      product = ProductsFixtures.product_fixture(%{store: store})
      download = Downloads.create_download_link!(%{product_id: product.id, user_id: user.id})

      retrieved_download = Downloads.get_download_by_token(download.token)
      assert retrieved_download.id == download.id
      assert retrieved_download.token == download.token
      assert retrieved_download.product_id == download.product_id
      assert retrieved_download.user_id == download.user_id
    end

    test "list_user_downloads/1 returns downloads for given user" do
      user = AccountsFixtures.user_fixture()
      store = StoresFixtures.store_fixture(%{user: user})
      product = ProductsFixtures.product_fixture(%{store: store})
      download = Downloads.create_download_link!(%{product_id: product.id, user_id: user.id})

      downloads = Downloads.list_user_downloads(user.id)
      assert length(downloads) == 1
      retrieved_download = List.first(downloads)
      assert retrieved_download.id == download.id
      assert retrieved_download.token == download.token
      assert retrieved_download.product_id == download.product_id
      assert retrieved_download.user_id == download.user_id
    end

    test "verify_access/2 returns ok for valid access" do
      user = AccountsFixtures.user_fixture()
      store = StoresFixtures.store_fixture(%{user: user})
      product = ProductsFixtures.product_fixture(%{store: store})
      download = Downloads.create_download_link!(%{product_id: product.id, user_id: user.id})

      assert {:ok, retrieved_download} = Downloads.verify_access(download.token, user.id)
      assert retrieved_download.id == download.id
      assert retrieved_download.token == download.token
      assert retrieved_download.product_id == download.product_id
      assert retrieved_download.user_id == download.user_id
    end

    test "verify_access/2 returns error for wrong user" do
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      store = StoresFixtures.store_fixture(%{user: user1})
      product = ProductsFixtures.product_fixture(%{store: store})
      download = Downloads.create_download_link!(%{product_id: product.id, user_id: user1.id})

      assert {:error, :unauthorized} = Downloads.verify_access(download.token, user2.id)
    end

    test "increment_download_count/1 increments the count" do
      user = AccountsFixtures.user_fixture()
      store = StoresFixtures.store_fixture(%{user: user})
      product = ProductsFixtures.product_fixture(%{store: store})
      download = Downloads.create_download_link!(%{product_id: product.id, user_id: user.id})

      assert {:ok, updated_download} = Downloads.increment_download_count(download)
      assert updated_download.download_count == 1
      assert updated_download.last_downloaded_at != nil
    end

    test "create_download_for_payment/3 creates download for payment" do
      user = AccountsFixtures.user_fixture()
      store = StoresFixtures.store_fixture(%{user: user})
      product = ProductsFixtures.product_fixture(%{store: store})

      assert {:ok, %Download{} = download} = Downloads.create_download_for_payment(product.id, user.id)
      assert download.product_id == product.id
      assert download.user_id == user.id
      assert download.download_count == 0
    end
  end
end
