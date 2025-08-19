defmodule Shomp.Stores.StoreBalance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "store_balances" do
    field :total_earnings, :decimal, default: Decimal.new(0)
    field :pending_balance, :decimal, default: Decimal.new(0)
    field :paid_out_balance, :decimal, default: Decimal.new(0)
    field :last_payout_date, :utc_datetime
    field :kyc_verified, :boolean, default: false
    field :kyc_verified_at, :utc_datetime
    field :kyc_documents_submitted, :boolean, default: false
    field :kyc_submitted_at, :utc_datetime
    
    belongs_to :store, Shomp.Stores.Store
    
    timestamps()
  end

  @doc false
  def changeset(store_balance, attrs) do
    store_balance
    |> cast(attrs, [:total_earnings, :pending_balance, :paid_out_balance, :last_payout_date, :kyc_verified, :kyc_verified_at, :kyc_documents_submitted, :kyc_submitted_at, :store_id])
    |> validate_required([:store_id])
    |> validate_number(:total_earnings, greater_than_or_equal_to: 0)
    |> validate_number(:pending_balance, greater_than_or_equal_to: 0)
    |> validate_number(:paid_out_balance, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:store_id)
  end

  @doc """
  Creates a changeset for a new store balance.
  """
  def create_changeset(store_balance, attrs) do
    store_balance
    |> changeset(attrs)
    |> put_change(:total_earnings, Decimal.new(0))
    |> put_change(:pending_balance, Decimal.new(0))
    |> put_change(:paid_out_balance, Decimal.new(0))
  end

  @doc """
  Updates the balance when a sale is made.
  """
  def add_sale_changeset(store_balance, sale_amount) do
    store_balance
    |> change(%{
      total_earnings: Decimal.add(store_balance.total_earnings, sale_amount),
      pending_balance: Decimal.add(store_balance.pending_balance, sale_amount)
    })
  end

  @doc """
  Updates the balance when a payout is made.
  """
  def payout_changeset(store_balance, payout_amount) do
    store_balance
    |> change(%{
      pending_balance: Decimal.sub(store_balance.pending_balance, payout_amount),
      paid_out_balance: Decimal.add(store_balance.paid_out_balance, payout_amount),
      last_payout_date: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Marks KYC documents as submitted.
  """
  def kyc_submitted_changeset(store_balance) do
    store_balance
    |> change(%{
      kyc_documents_submitted: true,
      kyc_submitted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Marks KYC as verified.
  """
  def kyc_verified_changeset(store_balance) do
    store_balance
    |> change(%{
      kyc_verified: true,
      kyc_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Checks if the store is eligible for payouts.
  """
  def eligible_for_payout?(store_balance) do
    store_balance.kyc_verified and 
    Decimal.gt?(store_balance.pending_balance, Decimal.new(0))
  end

  @doc """
  Gets the available payout amount.
  """
  def available_payout_amount(store_balance) do
    if eligible_for_payout?(store_balance) do
      store_balance.pending_balance
    else
      Decimal.new(0)
    end
  end
end
