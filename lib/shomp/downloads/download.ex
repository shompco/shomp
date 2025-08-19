defmodule Shomp.Downloads.Download do
  use Ecto.Schema
  import Ecto.Changeset

  schema "downloads" do
    field :token, :string
    field :download_count, :integer, default: 0
    field :expires_at, :utc_datetime
    field :last_downloaded_at, :utc_datetime
    
    belongs_to :product, Shomp.Products.Product
    belongs_to :user, Shomp.Accounts.User
    
    timestamps()
  end

  @doc false
  def changeset(download, attrs) do
    download
    |> cast(attrs, [:token, :download_count, :expires_at, :last_downloaded_at, :product_id, :user_id])
    |> validate_required([:token, :product_id, :user_id])
    |> validate_number(:download_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a changeset for a new download with a secure token.
  """
  def create_changeset(download, attrs) do
    download
    |> cast(attrs, [:download_count, :expires_at, :last_downloaded_at, :product_id, :user_id])
    |> validate_required([:product_id, :user_id])
    |> validate_number(:download_count, greater_than_or_equal_to: 0)
    |> put_change(:token, generate_secure_token())
    |> put_change(:download_count, 0)
    |> put_change(:last_downloaded_at, nil)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Increments the download count and updates the last downloaded timestamp.
  """
  def increment_download_changeset(download) do
    download
    |> change(%{
      download_count: download.download_count + 1,
      last_downloaded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Checks if the download is still valid (not expired).
  """
  def valid?(download) do
    case download.expires_at do
      nil -> true  # No expiration
      expires_at -> DateTime.compare(DateTime.utc_now(), expires_at) == :lt
    end
  end

  @doc """
  Checks if the download has reached its limit.
  """
  def within_limit?(download, max_downloads \\ nil) do
    case max_downloads do
      nil -> true  # No limit
      max -> download.download_count < max
    end
  end

  defp generate_secure_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end
end
