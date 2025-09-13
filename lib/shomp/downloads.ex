defmodule Shomp.Downloads do
  @moduledoc """
  The Downloads context for managing product downloads after purchase.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Downloads.Download

  @doc """
  Creates a new download link for a product purchase.
  """
  def create_download_link(attrs \\ %{}) do
    %Download{}
    |> Download.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a new download link for a product purchase, raises on error.
  """
  def create_download_link!(attrs \\ %{}) do
    %Download{}
    |> Download.create_changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Gets a download by its secure token.
  """
  def get_download_by_token(token) do
    Download
    |> where([d], d.token == ^token)
    |> preload([:product, :user, product: :store])
    |> Repo.one()
  end

  @doc """
  Gets a download by ID.
  """
  def get_download!(id) do
    Download
    |> where([d], d.id == ^id)
    |> preload([:product, :user, product: :store])
    |> Repo.one!()
  end

  @doc """
  Gets all downloads for a specific user.
  """
  def list_user_downloads(user_id) do
    Download
    |> where([d], d.user_id == ^user_id)
    |> preload([:product, product: :store])
    |> order_by([d], [desc: d.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets all downloads for a specific product.
  """
  def list_product_downloads(product_immutable_id) do
    Download
    |> where([d], d.product_immutable_id == ^product_immutable_id)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Gets a download for a specific product and user.
  """
  def get_download_by_product_and_user(product_immutable_id, user_id) do
    Download
    |> where([d], d.product_immutable_id == ^product_immutable_id and d.user_id == ^user_id)
    |> preload([:product, :user, product: :store])
    |> Repo.one()
  end

  @doc """
  Verifies if a user has access to download a product.
  """
  def verify_access(token, user_id) do
    case get_download_by_token(token) do
      nil ->
        {:error, :not_found}

      download ->
        cond do
          download.user_id != user_id ->
            {:error, :unauthorized}

          not Download.valid?(download) ->
            {:error, :expired}

          not Download.within_limit?(download, get_max_downloads()) ->
            {:error, :limit_exceeded}

          true ->
            {:ok, download}
        end
    end
  end

  @doc """
  Increments the download count for a download.
  """
  def increment_download_count(download) do
    case download
    |> Download.increment_download_changeset()
    |> Repo.update() do
      {:ok, updated_download} ->
        # Broadcast the download update event
        IO.puts("=== BROADCASTING DOWNLOAD UPDATE ===")
        IO.puts("User ID: #{download.user_id}")
        IO.puts("Download count: #{updated_download.download_count}")
        IO.puts("Channel: downloads:#{download.user_id}")

        Phoenix.PubSub.broadcast(Shomp.PubSub, "downloads:#{download.user_id}", %{
          event: "download_updated",
          payload: %{download: updated_download}
        })
        {:ok, updated_download}
      error -> error
    end
  end

  @doc """
  Records a download attempt and returns the file URL.
  """
  def process_download(token, user_id) do
    with {:ok, download} <- verify_access(token, user_id),
         {:ok, updated_download} <- increment_download_count(download) do
      # Get the file URL from either digital_file_url or file_path
      file_url = get_file_url(updated_download.product)
      {:ok, file_url, updated_download}
    end
  end

  defp get_file_url(product) do
    cond do
      product.digital_file_url && product.digital_file_url != "" ->
        # Ensure the URL has https:// prefix for R2 URLs
        if String.starts_with?(product.digital_file_url, "https://") do
          product.digital_file_url
        else
          "https://#{product.digital_file_url}"
        end
      product.file_path && product.file_path != "" ->
        product.file_path
      true ->
        nil
    end
  end

  @doc """
  Creates a download link for a successful payment.
  Sets 24-hour expiration and 5 download limit by default.
  """
  def create_download_for_payment(product_immutable_id, user_id, opts \\ []) do
    expires_at = Keyword.get(opts, :expires_at, DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second))

    create_download_link(%{
      product_immutable_id: product_immutable_id,
      user_id: user_id,
      expires_at: expires_at
    })
  end

  @doc """
  Creates a download link for a specific order item (each purchase gets its own download record).
  """
  def create_download_for_order_item(order_item, user_id, opts \\ []) do
    expires_at = Keyword.get(opts, :expires_at, DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second))

    create_download_link(%{
      product_immutable_id: order_item.product.immutable_id,
      user_id: user_id,
      expires_at: expires_at,
      order_item_id: order_item.id  # This makes each purchase unique
    })
  end

  @doc """
  Gets download statistics for a user.
  """
  def get_user_download_stats(user_id) do
    Download
    |> where([d], d.user_id == ^user_id)
    |> select([d], %{
      total_downloads: sum(d.download_count),
      unique_products: count(d.product_immutable_id, :distinct),
      total_purchases: count(d.id)
    })
    |> Repo.one()
  end

  @doc """
  Gets download statistics for a product.
  """
  def get_product_download_stats(product_immutable_id) do
    Download
    |> where([d], d.product_immutable_id == ^product_immutable_id)
    |> select([d], %{
      total_downloads: sum(d.download_count),
      unique_buyers: count(d.user_id, :distinct),
      total_sales: count(d.id)
    })
    |> Repo.one()
  end

  @doc """
  Deletes expired downloads.
  """
  def cleanup_expired_downloads do
    now = DateTime.utc_now()

    Download
    |> where([d], not is_nil(d.expires_at) and d.expires_at < ^now)
    |> Repo.delete_all()
  end

  # Private functions

  defp get_max_downloads do
    # Set to 5 downloads maximum for security
    5
  end
end
