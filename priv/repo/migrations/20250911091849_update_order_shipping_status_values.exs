defmodule Shomp.Repo.Migrations.UpdateOrderShippingStatusValues do
  use Ecto.Migration

  def up do
    # Update existing orders to use new status values
    execute """
    UPDATE orders
    SET shipping_status = CASE
      WHEN shipping_status = 'not_shipped' THEN 'ordered'
      WHEN shipping_status = 'preparing' THEN 'label_printed'
      WHEN shipping_status = 'shipped' THEN 'shipped'
      WHEN shipping_status = 'in_transit' THEN 'shipped'
      WHEN shipping_status = 'out_for_delivery' THEN 'shipped'
      WHEN shipping_status = 'delivered' THEN 'delivered'
      WHEN shipping_status = 'delivery_failed' THEN 'shipped'
      WHEN shipping_status = 'returned' THEN 'shipped'
      ELSE 'ordered'
    END
    WHERE shipping_status IS NOT NULL
    """
  end

  def down do
    # Revert back to old status values
    execute """
    UPDATE orders
    SET shipping_status = CASE
      WHEN shipping_status = 'ordered' THEN 'not_shipped'
      WHEN shipping_status = 'label_printed' THEN 'preparing'
      WHEN shipping_status = 'shipped' THEN 'shipped'
      WHEN shipping_status = 'delivered' THEN 'delivered'
      ELSE 'not_shipped'
    END
    WHERE shipping_status IS NOT NULL
    """
  end
end
