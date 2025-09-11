defmodule Shomp.StripeConnect do
  @moduledoc """
  The StripeConnect context for managing Stripe Connect accounts and onboarding.
  """

  alias Shomp.Stores.StoreKYCContext

  @doc """
  Creates a Stripe Connect Express account for a store.
  """
  def create_connect_account(store_id) do
    case StoreKYCContext.get_or_create_kyc(store_id) do
      {:ok, kyc} ->
        if kyc.stripe_account_id do
          {:ok, kyc}
        else
          create_stripe_account(kyc, store_id)
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Creates an onboarding link for a Stripe Connect account.
  """
  def create_onboarding_link(stripe_account_id, refresh_url, return_url) do
    Stripe.AccountLink.create(%{
      account: stripe_account_id,
      refresh_url: refresh_url,
      return_url: return_url,
      type: "account_onboarding"
    })
  end

  @doc """
  Retrieves a Stripe Connect account and updates the local KYC record.
  """
  def sync_account_status(stripe_account_id) do
    case Stripe.Account.retrieve(stripe_account_id) do
      {:ok, account} ->
        # Log what data is actually available from Stripe
        IO.puts("=== STRIPE ACCOUNT DATA AVAILABLE ===")
        IO.puts("Account ID: #{account.id}")
        IO.puts("Country: #{account.country}")
        IO.puts("Country Type: #{inspect(account.country)}")
        IO.puts("Type: #{account.type}")
        IO.puts("Charges Enabled: #{account.charges_enabled}")
        IO.puts("Payouts Enabled: #{account.payouts_enabled}")
        IO.puts("Details Submitted: #{account.details_submitted}")
        IO.puts("Email: #{account.email}")
        IO.puts("Business Type: #{account.business_type}")
        IO.puts("Business Profile: #{inspect(account.business_profile)}")
        IO.puts("Individual: #{inspect(account.individual)}")
        IO.puts("Company: #{inspect(account.company)}")
        IO.puts("Requirements: #{inspect(account.requirements)}")
        IO.puts("Full Account Object: #{inspect(account)}")

        # Extract individual information if available
        individual_info = if account.individual do
          %{
            first_name: account.individual.first_name,
            last_name: account.individual.last_name,
            email: account.individual.email,
            phone: account.individual.phone,
            dob: account.individual.dob,
            address: account.individual.address
          }
        else
          nil
        end

        # Extract company information if available
        company_info = if account.company do
          %{
            name: account.company.name || "Unknown",
            address: account.company[:address] || nil,
            country: account.company[:country] || nil
          }
        else
          nil
        end

        IO.puts("Individual Info: #{inspect(individual_info)}")
        IO.puts("Company Info: #{inspect(company_info)}")
        IO.puts("=====================================")

        update_kyc_from_stripe_account(account)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates KYC record based on Stripe account status.
  """
  def update_kyc_from_stripe_account(account) do
    # Find the KYC record by stripe_account_id
    case StoreKYCContext.get_kyc_by_stripe_account_id(account.id) do
      nil ->
        {:error, :kyc_not_found}

      kyc ->
        # Extract individual information if available
        individual_info = if account.individual do
          IO.puts("=== STRIPE INDIVIDUAL INFO ===")
          IO.puts("Individual object: #{inspect(account.individual)}")
          IO.puts("First name: #{account.individual.first_name}")
          IO.puts("Last name: #{account.individual.last_name}")
          IO.puts("Email: #{account.individual.email}")
          IO.puts("Phone: #{account.individual.phone}")
          IO.puts("DOB: #{inspect(account.individual.dob)}")
          IO.puts("Address: #{inspect(account.individual.address)}")
          IO.puts("=============================")

          %{
            first_name: account.individual.first_name,
            last_name: account.individual.last_name,
            email: account.individual.email,
            phone: account.individual.phone,
            dob: account.individual.dob,
            address: account.individual.address
          }
        else
          IO.puts("=== NO INDIVIDUAL INFO AVAILABLE ===")
          IO.puts("Account individual field: #{inspect(account.individual)}")
          IO.puts("=====================================")
          nil
        end

        # Extract company information if available
        company_info = if account.company do
          IO.puts("=== STRIPE COMPANY INFO ===")
          IO.puts("Company object: #{inspect(account.company)}")
          IO.puts("Company name: #{account.company.name}")
          IO.puts("Company address: #{inspect(account.company[:address])}")
          IO.puts("Company country: #{account.company[:country]}")
          IO.puts("===========================")

          %{
            name: account.company.name,
            address: account.company[:address],
            country: account.company[:country]
          }
        else
          IO.puts("=== NO COMPANY INFO AVAILABLE ===")
          IO.puts("Account company field: #{inspect(account.company)}")
          IO.puts("==================================")
          nil
        end

        # Try to get country from various sources
        detected_country = cond do
          account.country && account.country != "" -> account.country
          individual_info && individual_info.address && individual_info.address.country -> individual_info.address.country
          company_info && company_info.country && company_info.country != "" -> company_info.country
          true -> nil
        end

        IO.puts("=== COUNTRY DETECTION ===")
        IO.puts("Account Country: #{account.country}")
        IO.puts("Individual Address Country: #{if individual_info && individual_info.address, do: individual_info.address.country, else: "N/A"}")
        IO.puts("Company Country: #{if company_info, do: company_info.country, else: "N/A"}")
        IO.puts("Final Detected Country: #{detected_country}")
        IO.puts("=========================")

        attrs = %{
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
          requirements: account.requirements,
          onboarding_completed: account.details_submitted,
          stripe_individual_info: individual_info,
          stripe_country: detected_country
        }

        StoreKYCContext.update_kyc_stripe_status(kyc.id, attrs)
    end
  end

  @doc """
  Checks if an account is fully verified and can process payments.
  """
  def account_verified?(account) do
    account.charges_enabled && account.payouts_enabled && account.details_submitted
  end

  @doc """
  Gets the country for a Stripe Connect account.
  """
  def get_account_country(stripe_account_id) do
    case Stripe.Account.retrieve(stripe_account_id) do
      {:ok, account} ->
        # Try to get country from various sources
        detected_country = cond do
          account.country && account.country != "" -> account.country
          account.individual && account.individual.address && account.individual.address.country -> account.individual.address.country
          account.company && account.company.country -> account.company.country
          true -> nil
        end

        IO.puts("=== COUNTRY QUERY FOR #{stripe_account_id} ===")
        IO.puts("Account Country: #{account.country}")
        IO.puts("Individual Address Country: #{if account.individual && account.individual.address, do: account.individual.address.country, else: "N/A"}")
        IO.puts("Company Country: #{if account.company, do: account.company.country, else: "N/A"}")
        IO.puts("Final Detected Country: #{detected_country}")
        IO.puts("=============================================")

        {:ok, detected_country}
      {:error, reason} ->
        IO.puts("Error fetching country for #{stripe_account_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets the onboarding URL for a store.
  """
  def get_onboarding_url(store_id, return_url) do
    IO.puts("=== GET_ONBOARDING_URL CALLED ===")
    IO.puts("Store ID: #{store_id}")
    IO.puts("Return URL: #{return_url}")

    case create_connect_account(store_id) do
      {:ok, kyc} ->
        IO.puts("KYC record found/created: #{kyc.id}")
        IO.puts("Stripe Account ID: #{kyc.stripe_account_id}")
        refresh_url = "#{return_url}?refresh=true"

        case create_onboarding_link(kyc.stripe_account_id, refresh_url, return_url) do
          {:ok, account_link} ->
            IO.puts("Account link created successfully: #{account_link.url}")
            {:ok, account_link.url}

          {:error, reason} ->
            IO.puts("Error creating account link: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("Error creating connect account: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Handles Stripe webhook events for account updates.
  """
  def handle_account_updated(account_id) do
    sync_account_status(account_id)
  end

  @doc """
  Gets the Stripe dashboard URL for a connected account.
  """
  def get_dashboard_url(stripe_account_id) do
    # Use the correct Stripe Connect dashboard URL format
    # This is the standard URL format for Stripe Connect accounts
    dashboard_url = "https://dashboard.stripe.com/connect/accounts/#{stripe_account_id}"
    {:ok, dashboard_url}
  end

  @doc """
  Gets the test Stripe Connect dashboard URL for a connected account.
  """
  def get_test_dashboard_url(stripe_account_id) do
    # Test mode Stripe Connect dashboard URL
    test_dashboard_url = "https://dashboard.stripe.com/test/connect/accounts/#{stripe_account_id}"
    {:ok, test_dashboard_url}
  end

  @doc """
  Gets the balance for a Stripe Connect account.
  """
  def get_account_balance(stripe_account_id) do
    # For connected accounts, we need to make a direct API call
    # since the stripity library might not support stripe_account parameter
    try do
      # Make a direct HTTP request to Stripe API using Req
      url = "https://api.stripe.com/v1/balance"
      stripe_key = Application.get_env(:shomp, :stripe_secret_key)

      IO.puts("=== BALANCE DEBUG ===")
      IO.puts("Using Stripe Key: #{String.slice(stripe_key, 0, 10)}...")
      IO.puts("Account ID: #{stripe_account_id}")
      IO.puts("====================")

      headers = [
        {"Authorization", "Bearer #{stripe_key}"},
        {"Stripe-Account", stripe_account_id}
      ]

      case Req.get(url, headers: headers) do
        {:ok, %{status: 200, body: balance_data}} ->
          IO.puts("=== STRIPE BALANCE STRUCTURE ===")
          IO.puts("Balance: #{inspect(balance_data)}")
          IO.puts("Available: #{inspect(balance_data["available"])}")
          IO.puts("Pending: #{inspect(balance_data["pending"])}")
          IO.puts("=================================")

          # Parse the balance data
          available_amount = balance_data["available"]
          |> Enum.map(fn balance_item -> balance_item["amount"] end)
          |> Enum.sum()

          pending_amount = balance_data["pending"]
          |> Enum.map(fn balance_item -> balance_item["amount"] end)
          |> Enum.sum()

          # Convert from cents to dollars
          available_balance = Decimal.new(available_amount) |> Decimal.div(100)
          pending_balance = Decimal.new(pending_amount) |> Decimal.div(100)

          IO.puts("Parsed amounts - Available: #{available_amount} cents, Pending: #{pending_amount} cents")
          IO.puts("Converted - Available: $#{Decimal.to_string(available_balance)}, Pending: $#{Decimal.to_string(pending_balance)}")

          {:ok, %{
            available: available_balance,
            pending: pending_balance,
            total: Decimal.add(available_balance, pending_balance)
          }}

        {:ok, %{status: status_code, body: body}} ->
          IO.puts("Stripe API error: #{status_code} - #{inspect(body)}")
          {:error, :stripe_api_error}

        {:error, reason} ->
          IO.puts("HTTP request failed: #{inspect(reason)}")
          {:error, :http_error}
      end
    rescue
      error ->
        IO.puts("Exception in get_account_balance: #{inspect(error)}")
        {:error, :exception}
    end
  end

  @doc """
  Gets the test balance for a Stripe Connect account.
  """
  def get_test_account_balance(stripe_account_id) do
    # For test mode, we use the same API endpoint but with test key
    # The test key should automatically route to test data
    try do
      # Make a direct HTTP request to Stripe API using Req
      url = "https://api.stripe.com/v1/balance"
      stripe_key = Application.get_env(:shomp, :stripe_secret_key)

      IO.puts("=== TEST BALANCE DEBUG ===")
      IO.puts("Using Stripe Key: #{String.slice(stripe_key, 0, 10)}...")
      IO.puts("Account ID: #{stripe_account_id}")
      IO.puts("=========================")

      headers = [
        {"Authorization", "Bearer #{stripe_key}"},
        {"Stripe-Account", stripe_account_id}
      ]

      case Req.get(url, headers: headers) do
        {:ok, %{status: 200, body: balance_data}} ->
          IO.puts("=== TEST STRIPE BALANCE STRUCTURE ===")
          IO.puts("Balance: #{inspect(balance_data)}")
          IO.puts("Available: #{inspect(balance_data["available"])}")
          IO.puts("Pending: #{inspect(balance_data["pending"])}")
          IO.puts("=====================================")

          # Parse the balance data
          available_amount = balance_data["available"]
          |> Enum.map(fn balance_item -> balance_item["amount"] end)
          |> Enum.sum()

          pending_amount = balance_data["pending"]
          |> Enum.map(fn balance_item -> balance_item["amount"] end)
          |> Enum.sum()

          # Convert from cents to dollars
          available_balance = Decimal.new(available_amount) |> Decimal.div(100)
          pending_balance = Decimal.new(pending_amount) |> Decimal.div(100)

          {:ok, %{
            available: available_balance,
            pending: pending_balance,
            total: Decimal.add(available_balance, pending_balance)
          }}

        {:ok, %{status: status_code, body: body}} ->
          IO.puts("Test Stripe API error: #{status_code} - #{inspect(body)}")
          {:error, :stripe_api_error}

        {:error, reason} ->
          IO.puts("Test HTTP request failed: #{inspect(reason)}")
          {:error, :http_error}
      end
    rescue
      error ->
        IO.puts("Exception in get_test_account_balance: #{inspect(error)}")
        {:error, :exception}
    end
  end

  # Private functions

  defp create_stripe_account(kyc, store_id) do
    IO.puts("=== CREATING STRIPE ACCOUNT ===")
    IO.puts("KYC ID: #{kyc.id}")
    IO.puts("KYC Email: #{kyc.email}")
    IO.puts("KYC Business Type: #{kyc.business_type}")

    # Get the user's email from the store
    user_email = get_user_email_from_store(store_id)
    IO.puts("User Email from Store: #{user_email}")

    # Create a minimal Stripe account - Stripe will collect the details during onboarding
    # Let Stripe detect the country automatically based on user's location
    account_params = %{
      type: "express",
      capabilities: %{
        card_payments: %{requested: true},
        transfers: %{requested: true}
      }
    }

    # Use user email if KYC email is not available
    email_to_use = kyc.email || user_email
    account_params = if email_to_use do
      Map.put(account_params, :email, email_to_use)
    else
      account_params
    end

    account_params = if kyc.business_type do
      Map.put(account_params, :business_type, map_business_type(kyc.business_type))
    else
      account_params
    end

    IO.puts("Account params: #{inspect(account_params)}")

    case Stripe.Account.create(account_params) do
      {:ok, account} ->
        IO.puts("Stripe account created: #{account.id}")
        # Update the KYC record with the Stripe account ID
        attrs = %{
          stripe_account_id: account.id,
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
          requirements: account.requirements,
          onboarding_completed: account.details_submitted
        }

        case StoreKYCContext.update_kyc_stripe_status(kyc.id, attrs) do
          {:ok, updated_kyc} ->
            IO.puts("KYC record updated successfully")
            {:ok, updated_kyc}

          {:error, changeset} ->
            IO.puts("Error updating KYC record: #{inspect(changeset)}")
            {:error, changeset}
        end

      {:error, reason} ->
        IO.puts("Error creating Stripe account: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_user_email_from_store(store_id) do
    alias Shomp.Stores

    case Stores.get_store_with_user!(store_id) do
      nil -> nil
      store ->
        if store.user do
          store.user.email
        else
          nil
        end
    end
  rescue
    Ecto.NoResultsError -> nil
  end

  defp map_business_type(business_type) do
    case business_type do
      "individual" -> "individual"
      "llc" -> "company"
      "corporation" -> "company"
      "partnership" -> "company"
      "sole_proprietorship" -> "individual"
      _ -> "individual"
    end
  end
end
