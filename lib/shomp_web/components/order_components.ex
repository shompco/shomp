defmodule ShompWeb.OrderComponents do
  @moduledoc """
  Order-related UI components.
  """

  use Phoenix.Component
  import ShompWeb.CoreComponents

  @doc """
  Renders a status badge for order shipping status.
  """
  attr :status, :string, required: true
  attr :class, :string, default: ""

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      status_class(@status),
      @class
    ]}>
      <%= status_text(@status) %>
    </span>
    """
  end

  @doc """
  Renders a progress indicator for order status.
  """
  attr :status, :string, required: true
  attr :class, :string, default: ""

  def status_progress(assigns) do
    ~H"""
    <div class={["space-y-3", @class]}>
      <div class="flex items-center space-x-3">
        <div class={[
          "w-3 h-3 rounded-full",
          if(@status in ["ordered", "label_printed", "shipped", "delivered"], do: "bg-primary", else: "bg-base-300")
        ]}></div>
        <span class="text-sm text-base-content">Order Placed</span>
      </div>
      <div class="flex items-center space-x-3">
        <div class={[
          "w-3 h-3 rounded-full",
          if(@status in ["label_printed", "shipped", "delivered"], do: "bg-primary", else: "bg-base-300")
        ]}></div>
        <span class="text-sm text-base-content">Label Printed</span>
      </div>
      <div class="flex items-center space-x-3">
        <div class={[
          "w-3 h-3 rounded-full",
          if(@status in ["shipped", "delivered"], do: "bg-primary", else: "bg-base-300")
        ]}></div>
        <span class="text-sm text-base-content">Shipped</span>
      </div>
      <div class="flex items-center space-x-3">
        <div class={[
          "w-3 h-3 rounded-full",
          if(@status == "delivered", do: "bg-primary", else: "bg-base-300")
        ]}></div>
        <span class="text-sm text-base-content">Delivered</span>
      </div>
    </div>
    """
  end

  @doc """
  Renders order item information.
  """
  attr :item, :map, required: true
  attr :show_quantity, :boolean, default: true
  attr :show_price, :boolean, default: true
  attr :class, :string, default: ""

  def order_item(assigns) do
    ~H"""
    <div class={["flex items-center space-x-4", @class]}>
      <%= if @item.product.image_thumb do %>
        <img src={@item.product.image_thumb} alt={@item.product.title} class="w-16 h-16 rounded object-cover" />
      <% else %>
        <div class="w-16 h-16 bg-base-200 rounded flex items-center justify-center">
          <svg class="w-8 h-8 text-base-content/40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        </div>
      <% end %>
      <div class="flex-1">
        <h3 class="font-medium text-base-content"><%= @item.product.title %></h3>
        <%= if @show_quantity do %>
          <p class="text-sm text-base-content/60">Quantity: <%= @item.quantity %></p>
        <% end %>
        <%= if @show_price do %>
          <p class="text-sm text-base-content/60">Price: $<%= Decimal.to_string(@item.price, :normal) %></p>
        <% end %>
        <%= if @item.product.type == "digital" do %>
          <p class="text-xs text-primary">Digital Product</p>
        <% end %>
      </div>
      <div class="text-right">
        <p class="font-semibold text-base-content">
          $<%= Decimal.to_string(Decimal.mult(@item.price, @item.quantity), :normal) %>
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Renders tracking information with carrier links.
  """
  attr :tracking_number, :string, required: true
  attr :carrier, :string, default: nil
  attr :class, :string, default: ""

  def tracking_info(assigns) do
    ~H"""
    <div class={["space-y-4", @class]}>
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm text-base-content/60">Tracking Number</p>
          <p class="font-mono text-base-content"><%= @tracking_number %></p>
        </div>
        <%= if @carrier do %>
          <div class="text-right">
            <p class="text-sm text-base-content/60">Carrier</p>
            <p class="text-base-content"><%= @carrier %></p>
          </div>
        <% end %>
      </div>

      <!-- Tracking Links -->
      <div class="flex flex-wrap gap-2">
        <%= if @carrier == "USPS" do %>
          <.link
            href={"https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=#{@tracking_number}"}
            target="_blank"
            class="btn btn-sm btn-outline"
          >
            Track on USPS
          </.link>
        <% end %>
        <%= if @carrier == "FedEx" do %>
          <.link
            href={"https://www.fedex.com/fedextrack/?trknbr=#{@tracking_number}"}
            target="_blank"
            class="btn btn-sm btn-outline"
          >
            Track on FedEx
          </.link>
        <% end %>
        <%= if @carrier == "UPS" do %>
          <.link
            href={"https://www.ups.com/track?track=yes&trackNums=#{@tracking_number}"}
            target="_blank"
            class="btn btn-sm btn-outline"
          >
            Track on UPS
          </.link>
        <% end %>
        <%= if @carrier == "DHL" do %>
          <.link
            href={"https://www.dhl.com/us-en/home/tracking.html?trackingNumber=#{@tracking_number}"}
            target="_blank"
            class="btn btn-sm btn-outline"
          >
            Track on DHL
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp status_class(status) do
    case status do
      "ordered" -> "badge-warning"
      "label_printed" -> "badge-info"
      "shipped" -> "badge-primary"
      "delivered" -> "badge-success"
      _ -> "badge-neutral"
    end
  end

  defp status_text(status) do
    case status do
      "ordered" -> "Ordered"
      "label_printed" -> "Label Printed"
      "shipped" -> "Shipped"
      "delivered" -> "Delivered"
      _ -> String.capitalize(status)
    end
  end
end
