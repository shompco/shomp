defmodule Shomp.Stores.StoreKYCContext do
  @moduledoc """
  The StoreKYC context for managing store KYC submissions and verification.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Stores.StoreKYC

  @doc """
  Gets or creates a KYC record for a store.
  """
  def get_or_create_kyc(store_id) do
    case get_kyc(store_id) do
      nil ->
        create_kyc(%{store_id: store_id})
      kyc ->
        {:ok, kyc}
    end
  end

  @doc """
  Gets KYC by store ID.
  """
  def get_kyc(store_id) do
    StoreKYC
    |> where([k], k.store_id == ^store_id)
    |> Repo.one()
  end

  @doc """
  Creates a new KYC record.
  """
  def create_kyc(attrs \\ %{}) do
    %StoreKYC{}
    |> StoreKYC.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Submits KYC documents for a store.
  """
  def submit_kyc(store_id, attrs) do
    case get_or_create_kyc(store_id) do
      {:ok, kyc} ->
        kyc
        |> StoreKYC.submit_changeset(attrs)
        |> Repo.update()
      
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Verifies KYC for a store.
  """
  def verify_kyc(store_id) do
    case get_kyc(store_id) do
      nil ->
        {:error, :kyc_not_found}
      
      kyc ->
        kyc
        |> StoreKYC.verify_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Rejects KYC for a store.
  """
  def reject_kyc(store_id, reason) do
    case get_kyc(store_id) do
      nil ->
        {:error, :kyc_not_found}
      
      kyc ->
        kyc
        |> StoreKYC.reject_changeset(reason)
        |> Repo.update()
    end
  end

  @doc """
  Gets KYC with store information.
  """
  def get_kyc_with_store(store_id) do
    StoreKYC
    |> where([k], k.store_id == ^store_id)
    |> preload([:store])
    |> Repo.one()
  end

  @doc """
  Lists all KYC records with store information.
  """
  def list_kyc_records do
    StoreKYC
    |> preload([:store])
    |> Repo.all()
  end

  @doc """
  Lists KYC records by status.
  """
  def list_kyc_by_status(status) do
    StoreKYC
    |> where([k], k.status == ^status)
    |> preload([:store])
    |> Repo.all()
  end

  @doc """
  Gets KYC statistics.
  """
  def get_kyc_stats do
    pending = StoreKYC
    |> where([k], k.status == "pending")
    |> Repo.aggregate(:count, :id)

    submitted = StoreKYC
    |> where([k], k.status == "submitted")
    |> Repo.aggregate(:count, :id)

    verified = StoreKYC
    |> where([k], k.status == "verified")
    |> Repo.aggregate(:count, :id)

    rejected = StoreKYC
    |> where([k], k.status == "rejected")
    |> Repo.aggregate(:count, :id)

    %{
      pending: pending,
      submitted: submitted,
      verified: verified,
      rejected: rejected
    }
  end

  @doc """
  Updates admin notes for KYC.
  """
  def update_admin_notes(store_id, notes) do
    case get_kyc(store_id) do
      nil ->
        {:error, :kyc_not_found}
      
      kyc ->
        kyc
        |> StoreKYC.changeset(%{admin_notes: notes})
        |> Repo.update()
    end
  end

  @doc """
  Checks if a store has verified KYC.
  """
  def kyc_verified?(store_id) do
    case get_kyc(store_id) do
      nil -> false
      kyc -> StoreKYC.verified?(kyc)
    end
  end

  @doc """
  Checks if a store has submitted KYC documents.
  """
  def kyc_submitted?(store_id) do
    case get_kyc(store_id) do
      nil -> false
      kyc -> StoreKYC.pending?(kyc)
    end
  end
end
