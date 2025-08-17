defmodule Shomp.PaymentsTest do
  use Shomp.DataCase

  alias Shomp.Payments
  alias Shomp.Payments.Payment

  import Shomp.AccountsFixtures
  import Shomp.StoresFixtures
  import Shomp.ProductsFixtures

  describe "payments" do
    @valid_attrs %{
      amount: "120.5",
      stripe_payment_id: "cs_test_123",
      product_id: nil,
      user_id: nil
    }

    def payment_fixture(_attrs \\ %{}) do
      user = user_fixture()
      store = store_fixture(%{user: user})
      product = product_fixture(%{store: store})

      attrs = Map.merge(@valid_attrs, %{
        product_id: product.id,
        user_id: user.id
      })

      {:ok, payment} = Payments.create_payment(attrs)
      payment
    end

    test "create_payment/1 with valid data creates a payment" do
      user = user_fixture()
      store = store_fixture(%{user: user})
      product = product_fixture(%{store: store})

      attrs = Map.merge(@valid_attrs, %{
        product_id: product.id,
        user_id: user.id
      })

      assert {:ok, %Payment{} = payment} = Payments.create_payment(attrs)
      assert Decimal.eq?(payment.amount, Decimal.new("120.5"))
      assert payment.stripe_payment_id == "cs_test_123"
      assert payment.product_id == product.id
      assert payment.user_id == user.id
      assert payment.status == "pending"
    end

    test "create_payment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Payments.create_payment(%{amount: nil})
    end

    test "get_payment!/1 returns the payment with given id" do
      payment = payment_fixture()
      retrieved_payment = Payments.get_payment!(payment.id)
      assert retrieved_payment.id == payment.id
      assert retrieved_payment.stripe_payment_id == payment.stripe_payment_id
    end

    test "update_payment_status/2 updates the payment status" do
      payment = payment_fixture()
      assert {:ok, %Payment{} = updated_payment} = Payments.update_payment_status(payment, "succeeded")
      assert updated_payment.status == "succeeded"
    end

    test "get_payment_by_stripe_id/1 returns payment by Stripe ID" do
      payment = payment_fixture()
      retrieved_payment = Payments.get_payment_by_stripe_id(payment.stripe_payment_id)
      assert retrieved_payment.id == payment.id
      assert retrieved_payment.stripe_payment_id == payment.stripe_payment_id
    end

    test "list_user_payments/1 returns payments for given user" do
      user = user_fixture()
      store = store_fixture(%{user: user})
      product = product_fixture(%{store: store})
      
      # Create payment directly with the user's ID
      payment_attrs = Map.merge(@valid_attrs, %{
        product_id: product.id,
        user_id: user.id
      })
      
      {:ok, payment} = Payments.create_payment(payment_attrs)
      
      user_payments = Payments.list_user_payments(user.id)
      assert length(user_payments) == 1
      assert hd(user_payments).id == payment.id
    end
  end
end
