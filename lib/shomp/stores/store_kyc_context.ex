defmodule Shomp.Stores.StoreKYCContext do
  @moduledoc """
  The StoreKYC context for managing store KYC submissions and verification.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Stores.StoreKYC
  alias Shomp.Stores

  @doc """
  Gets or creates a KYC record for a store using string store_id.
  """
  def get_or_create_kyc_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        get_or_create_kyc(store.id)
    end
  end

  @doc """
  Gets KYC by string store_id.
  """
  def get_kyc_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        nil
      store ->
        get_kyc(store.id)
    end
  end

  @doc """
  Gets or creates a KYC record for a store using integer ID.
  """
  def get_or_create_kyc(store_id) do
    case get_kyc(store_id) do
      nil ->
        create_minimal_kyc(%{store_id: store_id})
      kyc ->
        {:ok, kyc}
    end
  end

  @doc """
  Gets KYC by store ID using integer ID.
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
  Creates a minimal KYC record for Stripe Connect.
  """
  def create_minimal_kyc(attrs \\ %{}) do
    %StoreKYC{}
    |> StoreKYC.minimal_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Submits KYC documents for a store using string store_id.
  """
  def submit_kyc_by_store_id(store_id_string, attrs) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        submit_kyc(store.id, attrs)
    end
  end

  @doc """
  Submits KYC documents for a store using integer ID.
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
  Gets KYC by Stripe account ID.
  """
  def get_kyc_by_stripe_account_id(stripe_account_id) do
    StoreKYC
    |> where([k], k.stripe_account_id == ^stripe_account_id)
    |> Repo.one()
  end

  @doc """
  Updates KYC record.
  """
  def update_kyc(kyc_id, attrs) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}
      
      kyc ->
        kyc
        |> StoreKYC.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates KYC record by ID (for admin use).
  """
  def update_kyc_by_id(kyc_id, attrs) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}
      
      kyc ->
        kyc
        |> StoreKYC.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates KYC Stripe Connect status.
  """
  def update_kyc_stripe_status(kyc_id, attrs) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}
      
      kyc ->
        kyc
        |> StoreKYC.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Verifies KYC for a store using string store_id.
  """
  def verify_kyc_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        verify_kyc(store.id)
    end
  end

  @doc """
  Verifies KYC for a store using integer ID.
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
  Verifies KYC by KYC ID (for admin use).
  """
  def verify_kyc_by_id(kyc_id) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}
      
      kyc ->
        kyc
        |> StoreKYC.verify_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Rejects KYC for a store using string store_id.
  """
  def reject_kyc_by_store_id(store_id_string, reason) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        reject_kyc(store.id, reason)
    end
  end

  @doc """
  Rejects KYC for a store using integer ID.
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
  Rejects KYC by KYC ID (for admin use).
  """
  def reject_kyc_by_id(kyc_id, reason) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}
      
      kyc ->
        kyc
        |> StoreKYC.reject_changeset(reason)
        |> Repo.update()
    end
  end

  @doc """
  Gets KYC with store information using string store_id.
  """
  def get_kyc_with_store_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        nil
      store ->
        get_kyc_with_store(store.id)
    end
  end

  @doc """
  Gets KYC with store information using integer ID.
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
  Lists all KYC records with store and user information for admin interface.
  """
  def list_kyc_records_with_users do
    from(k in StoreKYC,
      join: s in Shomp.Stores.Store, on: k.store_id == s.id,
      join: u in Shomp.Accounts.User, on: s.user_id == u.id,
      order_by: [desc: k.inserted_at],
      select: %{
        id: k.id,
        status: k.status,
        legal_name: k.legal_name,
        business_type: k.business_type,
        email: k.email,
        phone: k.phone,
        id_document_path: k.id_document_path,
        business_license_path: k.business_license_path,
        tax_document_path: k.tax_document_path,
        submitted_at: k.submitted_at,
        verified_at: k.verified_at,
        rejected_at: k.rejected_at,
        rejection_reason: k.rejection_reason,
        admin_notes: k.admin_notes,
        stripe_account_id: k.stripe_account_id,
        charges_enabled: k.charges_enabled,
        payouts_enabled: k.payouts_enabled,
        onboarding_completed: k.onboarding_completed,
        stripe_individual_info: k.stripe_individual_info,
        store: %{
          id: s.id,
          store_id: s.store_id,
          name: s.name,
          slug: s.slug,
          description: s.description
        },
        user: %{
          id: u.id,
          email: u.email,
          username: u.username,
          name: u.name
        },
        inserted_at: k.inserted_at,
        updated_at: k.updated_at
      }
    )
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
  Updates admin notes for KYC using string store_id.
  """
  def update_admin_notes_by_store_id(store_id_string, notes) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        update_admin_notes(store.id, notes)
    end
  end

  @doc """
  Updates admin notes for KYC using integer ID.
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
  Updates admin notes for KYC by KYC ID (for admin use).
  """
  def update_admin_notes_by_id(kyc_id, notes) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}
      
      kyc ->
        kyc
        |> StoreKYC.changeset(%{admin_notes: notes})
        |> Repo.update()
    end
  end

  @doc """
  Checks if a store has verified KYC using string store_id.
  """
  def kyc_verified_by_store_id?(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil -> false
      store -> kyc_verified?(store.id)
    end
  end

  @doc """
  Checks if a store has verified KYC using integer ID.
  """
  def kyc_verified?(store_id) do
    case get_kyc(store_id) do
      nil -> false
      kyc -> StoreKYC.verified?(kyc)
    end
  end

  @doc """
  Checks if a store has submitted KYC documents using string store_id.
  """
  def kyc_submitted_by_store_id?(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil -> false
      store -> kyc_submitted?(store.id)
    end
  end

  @doc """
  Checks if a store has submitted KYC documents using integer ID.
  """
  def kyc_submitted?(store_id) do
    case get_kyc(store_id) do
      nil -> false
      kyc -> StoreKYC.pending?(kyc)
    end
  end
end
