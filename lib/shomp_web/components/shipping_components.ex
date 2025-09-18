defmodule ShompWeb.ShippingComponents do
  @moduledoc """
  Components for shipping-related UI elements.
  """
  use Phoenix.Component
  import ShompWeb.CoreComponents

  @doc """
  Renders a shipping address form.
  """
  attr :form, :map, required: true
  attr :on_change, :string, default: "validate_shipping_address"
  attr :class, :string, default: ""

  def shipping_address_form(assigns) do
    ~H"""
    <div class={["space-y-4", @class]}>
      <div>
        <label for="shipping_name" class="block text-sm font-medium text-gray-700">
          Full Name
        </label>
        <.input
          field={@form[:name]}
          type="text"
          id="shipping_name"
          phx-change={@on_change}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        />
      </div>

      <div>
        <label for="shipping_street1" class="block text-sm font-medium text-gray-700">
          Street Address
        </label>
        <.input
          field={@form[:street1]}
          type="text"
          id="shipping_street1"
          phx-change={@on_change}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        />
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div>
          <label for="shipping_city" class="block text-sm font-medium text-gray-700">
            City
          </label>
          <.input
            field={@form[:city]}
            type="text"
            id="shipping_city"
            phx-change={@on_change}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          />
        </div>

        <div>
          <label for="shipping_state" class="block text-sm font-medium text-gray-700">
            State
          </label>
          <.input
            field={@form[:state]}
            type="text"
            id="shipping_state"
            phx-change={@on_change}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          />
        </div>
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div>
          <label for="shipping_zip" class="block text-sm font-medium text-gray-700">
            ZIP Code
          </label>
          <.input
            field={@form[:zip]}
            type="text"
            id="shipping_zip"
            phx-change={@on_change}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          />
        </div>

        <div>
          <label for="shipping_country" class="block text-sm font-medium text-gray-700">
            Country
          </label>
          <.input
            field={@form[:country]}
            type="text"
            id="shipping_country"
            phx-change={@on_change}
            value="US"
            readonly
            class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          />
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders shipping options selection.
  """
  attr :shipping_options, :list, required: true
  attr :selected_option, :map, default: nil
  attr :on_change, :string, default: "select_shipping_option"
  attr :loading, :boolean, default: false
  attr :class, :string, default: ""

  def shipping_options(assigns) do
    ~H"""
    <div class={["space-y-3", @class]}>
      <%= if @loading do %>
        <div class="flex items-center justify-center py-4">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-indigo-600"></div>
          <span class="ml-2 text-sm text-gray-600">Calculating shipping rates...</span>
        </div>
      <% else %>
        <%= if Enum.empty?(@shipping_options) do %>
          <div class="text-center py-4">
            <p class="text-sm text-gray-500">No shipping options available</p>
          </div>
        <% else %>
          <%= for option <- @shipping_options do %>
            <label class="flex items-center p-3 border border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50">
              <input
                type="radio"
                name="shipping_option"
                value={option.id}
                checked={@selected_option && @selected_option.id == option.id}
                phx-change={@on_change}
                class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
              />
              <div class="ml-3 flex-1">
                <div class="flex justify-between items-center">
                  <span class="text-sm font-medium text-gray-900">
                    <%= option.name %>
                  </span>
                  <span class="text-sm font-semibold text-gray-900">
                    $<%= :erlang.float_to_binary(option.cost, decimals: 2) %>
                  </span>
                </div>
                <%= if option.estimated_days do %>
                  <p class="text-xs text-gray-500">
                    Estimated delivery: <%= option.estimated_days %> business days
                  </p>
                <% end %>
              </div>
            </label>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders shipping cost summary.
  """
  attr :shipping_cost, :float, default: 0.0
  attr :subtotal, :float, required: true
  attr :class, :string, default: ""

  def shipping_summary(assigns) do
    ~H"""
    <div class={["space-y-2", @class]}>
      <div class="flex justify-between text-sm">
        <span class="text-gray-500">Subtotal</span>
        <span class="text-gray-900">$<%= :erlang.float_to_binary(@subtotal, decimals: 2) %></span>
      </div>

      <div class="flex justify-between text-sm">
        <span class="text-gray-500">Shipping</span>
        <span class="text-gray-900">
          <%= if @shipping_cost > 0 do %>
            $<%= :erlang.float_to_binary(@shipping_cost, decimals: 2) %>
          <% else %>
            TBD
          <% end %>
        </span>
      </div>

      <div class="border-t border-gray-200 pt-2">
        <div class="flex justify-between text-lg font-semibold">
          <span class="text-gray-900">Total</span>
          <span class="text-gray-900">
            <%= if @shipping_cost > 0 do %>
              $<%= :erlang.float_to_binary(@subtotal + @shipping_cost, decimals: 2) %>
            <% else %>
              $<%= :erlang.float_to_binary(@subtotal, decimals: 2) %> + shipping
            <% end %>
          </span>
        </div>
      </div>
    </div>
    """
  end
end
