defmodule Shomp.EscrowTransfers do
  @moduledoc """
  The EscrowTransfers context for managing escrow fund releases.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.PaymentSplits
  alias Shomp.Stores
  alias Shomp.Stores.StoreKYCContext

  @doc """
  Releases escrow funds to a merchant when they complete KYC.
  """
  def release_escrow_funds(store_id) do
    # Get store and verify it has completed KYC
    store = Stores.get_store!(store_id)
    kyc = StoreKYCContext.get_kyc_by_store_id(store_id)
    
    if !kyc || !kyc.stripe_account_id do
      {:error, "Store has not completed KYC or does not have a Stripe account"}
    else
      # Get all escrow payment splits for this store
      escrow_splits = PaymentSplits.list_escrow_payment_splits()
      |> Enum.filter(fn split -> split.store_id == store_id end)
      
      if Enum.empty?(escrow_splits) do
        {:ok, "No escrow funds to release"}
      else
        # Calculate total amount to transfer
        total_amount = escrow_splits
        |> Enum.map(fn split -> Decimal.to_float(split.store_amount) end)
        |> Enum.sum()
        
        # Convert to cents for Stripe
        total_amount_cents = (total_amount * 100) |> round()
        
        # Create Stripe transfer
        case create_stripe_transfer(kyc.stripe_account_id, total_amount_cents, store_id) do
          {:ok, transfer} ->
            # Update all escrow splits to mark as transferred
            update_escrow_splits_to_transferred(escrow_splits, transfer.id)
            
            # Update store balances
            update_store_balances(store, total_amount)
            
            {:ok, %{
              transfer_id: transfer.id,
              amount: total_amount,
              splits_updated: length(escrow_splits)
            }}
          {:error, reason} ->
            {:error, "Failed to create Stripe transfer: #{inspect(reason)}"}
        end
      end
    end
  end

  @doc """
  Gets escrow summary for a store.
  """
  def get_escrow_summary(store_id) do
    escrow_splits = PaymentSplits.list_escrow_payment_splits()
    |> Enum.filter(fn split -> split.store_id == store_id end)
    
    total_escrow = escrow_splits
    |> Enum.map(fn split -> Decimal.to_float(split.store_amount) end)
    |> Enum.sum()
    
    %{
      store_id: store_id,
      total_escrow: total_escrow,
      split_count: length(escrow_splits),
      splits: escrow_splits
    }
  end

  @doc """
  Lists all stores with pending escrow funds.
  """
  def list_stores_with_escrow do
    escrow_splits = PaymentSplits.list_escrow_payment_splits()
    
    escrow_splits
    |> Enum.group_by(fn split -> split.store_id end)
    |> Enum.map(fn {store_id, splits} ->
      total_escrow = splits
      |> Enum.map(fn split -> Decimal.to_float(split.store_amount) end)
      |> Enum.sum()
      
      %{
        store_id: store_id,
        total_escrow: total_escrow,
        split_count: length(splits),
        latest_split: Enum.max_by(splits, & &1.inserted_at)
      }
    end)
    |> Enum.sort_by(fn store -> store.total_escrow end, :desc)
  end

  # Private functions

  defp create_stripe_transfer(stripe_account_id, amount_cents, store_id) do
    Stripe.Transfer.create(%{
      amount: amount_cents,
      currency: "usd",
      destination: stripe_account_id,
      metadata: %{
        store_id: store_id,
        transfer_type: "escrow_release"
      }
    })
  end

  defp update_escrow_splits_to_transferred(splits, transfer_id) do
    Enum.each(splits, fn split ->
      PaymentSplits.update_payment_split(split, %{
        transfer_status: "succeeded",
        stripe_transfer_id: transfer_id
      })
    end)
  end

  defp update_store_balances(store, amount) do
    # Move from pending to available balance
    new_pending = Decimal.sub(store.pending_balance, Decimal.from_float(amount))
    new_available = Decimal.add(store.available_balance, Decimal.from_float(amount))
    
    Stores.update_store(store, %{
      pending_balance: new_pending,
      available_balance: new_available
    })
  end
end
