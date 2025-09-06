# MVP Core 5: Support System & Admin Dashboard

## Overview
This document outlines the support ticket system, admin dashboard enhancements, and email notification preferences for Shomp, building upon the existing order management system to provide comprehensive customer service and administrative capabilities.

## Current System Analysis
Based on the existing codebase analysis:

### Existing Infrastructure
- **User Management**: Basic user accounts with authentication
- **Order System**: Enhanced order management from MVP Core 4
- **Admin System**: Basic admin dashboard with user and store management
- **Email System**: Swoosh-based email notifications
- **LiveView Architecture**: Real-time UI components

### Current Gaps
- No support ticket/messaging system
- Limited admin order tracking capabilities
- No centralized support ticket management
- No user email notification preferences
- No real-time admin notifications

## 1. Support Ticket System

### A. Support Ticket Schema
```elixir
# Migration: create_support_tickets
defmodule Shomp.Repo.Migrations.CreateSupportTickets do
  use Ecto.Migration

  def change do
    create table(:support_tickets) do
      add :ticket_number, :string, null: false
      add :subject, :string, null: false
      add :description, :text, null: false
      add :status, :string, default: "open" # open, in_progress, waiting_customer, resolved, closed
      add :priority, :string, default: "medium" # low, medium, high, urgent
      add :category, :string, null: false # order_issue, payment_issue, technical, account, other
      add :subcategory, :string # order_cancellation, refund_request, login_issue, etc.
      
      # User and order references
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :order_id, references(:orders, on_delete: :nilify_all)
      add :store_id, references(:stores, on_delete: :nilify_all)
      
      # Assignment and resolution
      add :assigned_to_user_id, references(:users, on_delete: :nilify_all)
      add :resolved_at, :utc_datetime
      add :resolved_by_user_id, references(:users, on_delete: :nilify_all)
      add :resolution_notes, :text
      
      # Internal tracking
      add :internal_notes, :text
      add :last_activity_at, :utc_datetime, default: fragment("NOW()")
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:support_tickets, [:ticket_number])
    create index(:support_tickets, [:user_id])
    create index(:support_tickets, [:status])
    create index(:support_tickets, [:priority])
    create index(:support_tickets, [:assigned_to_user_id])
    create index(:support_tickets, [:last_activity_at])
  end
end
```

### B. Support Message Schema
```elixir
# Migration: create_support_messages
defmodule Shomp.Repo.Migrations.CreateSupportMessages do
  use Ecto.Migration

  def change do
    create table(:support_messages) do
      add :support_ticket_id, references(:support_tickets, on_delete: :delete_all), null: false
      add :message, :text, null: false
      add :is_internal, :boolean, default: false # Internal admin notes
      add :is_from_admin, :boolean, default: false
      add :author_user_id, references(:users, on_delete: :delete_all), null: false
      
      # File attachments
      add :attachments, :map, default: %{} # JSON field for file references
      
      timestamps(type: :utc_datetime)
    end

    create index(:support_messages, [:support_ticket_id])
    create index(:support_messages, [:author_user_id])
    create index(:support_messages, [:inserted_at])
  end
end
```

### C. Support Ticket Context
```elixir
# lib/shomp/support_tickets.ex
defmodule Shomp.SupportTickets do
  @moduledoc """
  The SupportTickets context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.SupportTickets.{SupportTicket, SupportMessage}

  def list_user_tickets(user_id, filters \\ %{}) do
    SupportTicket
    |> where([t], t.user_id == ^user_id)
    |> apply_filters(filters)
    |> preload([:user, :order, :store, :assigned_to_user, :resolved_by_user])
    |> order_by([t], [desc: t.last_activity_at])
    |> Repo.all()
  end

  def list_admin_tickets(filters \\ %{}) do
    SupportTicket
    |> apply_filters(filters)
    |> preload([:user, :order, :store, :assigned_to_user, :resolved_by_user])
    |> order_by([t], [desc: t.last_activity_at])
    |> Repo.all()
  end

  def get_ticket!(id) do
    SupportTicket
    |> preload([:user, :order, :store, :assigned_to_user, :resolved_by_user, :messages])
    |> Repo.get!(id)
  end

  def create_ticket(attrs \\ %{}) do
    ticket_number = generate_ticket_number()
    
    %SupportTicket{}
    |> SupportTicket.changeset(Map.put(attrs, :ticket_number, ticket_number))
    |> Repo.insert()
  end

  def update_ticket(ticket, attrs) do
    ticket
    |> SupportTicket.changeset(attrs)
    |> Repo.update()
  end

  def assign_ticket(ticket, admin_user_id) do
    ticket
    |> SupportTicket.assignment_changeset(%{assigned_to_user_id: admin_user_id})
    |> Repo.update()
  end

  def resolve_ticket(ticket, admin_user_id, resolution_notes) do
    ticket
    |> SupportTicket.resolution_changeset(%{
      status: "resolved",
      resolved_at: DateTime.utc_now(),
      resolved_by_user_id: admin_user_id,
      resolution_notes: resolution_notes
    })
    |> Repo.update()
  end

  def add_message(ticket, message_attrs) do
    %SupportMessage{}
    |> SupportMessage.changeset(Map.put(message_attrs, :support_ticket_id, ticket.id))
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        # Update ticket last activity
        update_ticket(ticket, %{last_activity_at: DateTime.utc_now()})
        {:ok, message}
      error -> error
    end
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, status}, query when status != "" ->
        where(query, [t], t.status == ^status)
      {:priority, priority}, query when priority != "" ->
        where(query, [t], t.priority == ^priority)
      {:category, category}, query when category != "" ->
        where(query, [t], t.category == ^category)
      {:assigned_to, user_id}, query when user_id != "" ->
        where(query, [t], t.assigned_to_user_id == ^user_id)
      _, query -> query
    end)
  end

  defp generate_ticket_number do
    # Generate format: ST-YYYYMMDD-XXXX
    date = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
    random = :rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")
    "ST-#{date}-#{random}"
  end
end
```

### D. Support Ticket Schema
```elixir
# lib/shomp/support_tickets/support_ticket.ex
defmodule Shomp.SupportTickets.SupportTicket do
  use Ecto.Schema
  import Ecto.Changeset

  schema "support_tickets" do
    field :ticket_number, :string
    field :subject, :string
    field :description, :string
    field :status, :string, default: "open"
    field :priority, :string, default: "medium"
    field :category, :string
    field :subcategory, :string
    field :resolution_notes, :string
    field :internal_notes, :string
    field :last_activity_at, :utc_datetime
    field :resolved_at, :utc_datetime

    belongs_to :user, Shomp.Accounts.User
    belongs_to :order, Shomp.Orders.Order
    belongs_to :store, Shomp.Stores.Store
    belongs_to :assigned_to_user, Shomp.Accounts.User
    belongs_to :resolved_by_user, Shomp.Accounts.User

    has_many :messages, Shomp.SupportTickets.SupportMessage

    timestamps(type: :utc_datetime)
  end

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:ticket_number, :subject, :description, :status, :priority, :category, :subcategory, :user_id, :order_id, :store_id, :internal_notes])
    |> validate_required([:ticket_number, :subject, :description, :category, :user_id])
    |> validate_inclusion(:status, ["open", "in_progress", "waiting_customer", "resolved", "closed"])
    |> validate_inclusion(:priority, ["low", "medium", "high", "urgent"])
    |> validate_inclusion(:category, ["order_issue", "payment_issue", "technical", "account", "other"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:store_id)
  end

  def assignment_changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:assigned_to_user_id, :status])
    |> foreign_key_constraint(:assigned_to_user_id)
  end

  def resolution_changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:status, :resolved_at, :resolved_by_user_id, :resolution_notes])
    |> foreign_key_constraint(:resolved_by_user_id)
  end
end
```

## 2. Support Ticket LiveView Interface

### A. Customer Support Interface
```elixir
# lib/shomp_web/live/support_live/index.ex
defmodule ShompWeb.SupportLive.Index do
  use ShompWeb, :live_view

  alias Shomp.SupportTickets

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    tickets = SupportTickets.list_user_tickets(user.id)
    
    socket = 
      socket
      |> assign(:tickets, tickets)
      |> assign(:page_title, "Support Tickets")

    {:ok, socket}
  end

  def handle_event("create_ticket", %{"ticket" => ticket_params}, socket) do
    user = socket.assigns.current_scope.user
    
    ticket_params = 
      ticket_params
      |> Map.put("user_id", user.id)
      |> Map.put("last_activity_at", DateTime.utc_now())

    case SupportTickets.create_ticket(ticket_params) do
      {:ok, ticket} ->
        # Send notification to admin
        Shomp.Notifications.send_new_ticket_notification(ticket)
        
        {:noreply, 
         socket
         |> put_flash(:info, "Support ticket created successfully")
         |> assign(:tickets, [ticket | socket.assigns.tickets])}
      
      {:error, changeset} ->
        {:noreply, assign(socket, :ticket_changeset, changeset)}
    end
  end
end
```

### B. Support Ticket Detail View
```elixir
# lib/shomp_web/live/support_live/show.ex
defmodule ShompWeb.SupportLive.Show do
  use ShompWeb, :live_view

  alias Shomp.SupportTickets

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(%{"id" => id}, _session, socket) do
    ticket = SupportTickets.get_ticket!(id)
    user = socket.assigns.current_scope.user
    
    # Verify user owns this ticket or is admin
    if ticket.user_id != user.id and !is_admin?(user) do
      raise ShompWeb.Router.Helpers, :not_found
    end
    
    socket = 
      socket
      |> assign(:ticket, ticket)
      |> assign(:page_title, "Ticket #{ticket.ticket_number}")

    {:ok, socket}
  end

  def handle_event("add_message", %{"message" => message_params}, socket) do
    ticket = socket.assigns.ticket
    user = socket.assigns.current_scope.user
    
    message_params = 
      message_params
      |> Map.put("author_user_id", user.id)
      |> Map.put("is_from_admin", is_admin?(user))

    case SupportTickets.add_message(ticket, message_params) do
      {:ok, message} ->
        # Send notification to other party
        if is_admin?(user) do
          Shomp.Notifications.send_ticket_reply_notification(ticket, message)
        else
          Shomp.Notifications.send_admin_ticket_reply_notification(ticket, message)
        end
        
        {:noreply, 
         socket
         |> put_flash(:info, "Message sent successfully")
         |> assign(:ticket, SupportTickets.get_ticket!(ticket.id))}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  defp is_admin?(user) do
    user.role == "admin"
  end
end
```

## 3. Admin Dashboard Enhancements

### A. Admin Support Dashboard
```elixir
# lib/shomp_web/live/admin_live/support_dashboard.ex
defmodule ShompWeb.AdminLive.SupportDashboard do
  use ShompWeb, :live_view

  alias Shomp.SupportTickets
  alias Shomp.Orders

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(_params, _session, socket) do
    # Get dashboard statistics
    stats = get_dashboard_stats()
    
    # Get recent tickets
    recent_tickets = SupportTickets.list_admin_tickets(%{status: "open"}) |> Enum.take(10)
    
    # Get urgent tickets
    urgent_tickets = SupportTickets.list_admin_tickets(%{priority: "urgent"}) |> Enum.take(5)
    
    socket = 
      socket
      |> assign(:stats, stats)
      |> assign(:recent_tickets, recent_tickets)
      |> assign(:urgent_tickets, urgent_tickets)
      |> assign(:page_title, "Support Dashboard")

    {:ok, socket}
  end

  def handle_event("assign_ticket", %{"ticket_id" => ticket_id}, socket) do
    ticket = SupportTickets.get_ticket!(ticket_id)
    admin_user = socket.assigns.current_scope.user
    
    case SupportTickets.assign_ticket(ticket, admin_user.id) do
      {:ok, updated_ticket} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Ticket assigned to you")
         |> assign(:recent_tickets, update_ticket_in_list(socket.assigns.recent_tickets, updated_ticket))}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to assign ticket")}
    end
  end

  def handle_event("resolve_ticket", %{"ticket_id" => ticket_id, "resolution_notes" => notes}, socket) do
    ticket = SupportTickets.get_ticket!(ticket_id)
    admin_user = socket.assigns.current_scope.user
    
    case SupportTickets.resolve_ticket(ticket, admin_user.id, notes) do
      {:ok, updated_ticket} ->
        # Send resolution notification to customer
        Shomp.Notifications.send_ticket_resolution_notification(updated_ticket)
        
        {:noreply, 
         socket
         |> put_flash(:info, "Ticket resolved successfully")
         |> assign(:recent_tickets, update_ticket_in_list(socket.assigns.recent_tickets, updated_ticket))}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to resolve ticket")}
    end
  end

  defp get_dashboard_stats do
    %{
      total_tickets: SupportTickets.count_tickets(),
      open_tickets: SupportTickets.count_tickets(%{status: "open"}),
      urgent_tickets: SupportTickets.count_tickets(%{priority: "urgent"}),
      resolved_today: SupportTickets.count_tickets_resolved_today(),
      avg_resolution_time: SupportTickets.avg_resolution_time_hours()
    }
  end
end
```

### B. Enhanced Admin Order Dashboard
```elixir
# lib/shomp_web/live/admin_live/order_dashboard.ex
defmodule ShompWeb.AdminLive.OrderDashboard do
  use ShompWeb, :live_view

  alias Shomp.Orders
  alias Shomp.Stores

  on_mount {ShompWeb.UserAuth, :require_admin}

  def mount(_params, _session, socket) do
    # Get order statistics
    order_stats = get_order_statistics()
    
    # Get recent orders
    recent_orders = Orders.list_orders_with_details() |> Enum.take(20)
    
    # Get pending cancellations and returns
    pending_cancellations = Orders.list_pending_cancellations()
    pending_returns = Orders.list_pending_returns()
    
    socket = 
      socket
      |> assign(:order_stats, order_stats)
      |> assign(:recent_orders, recent_orders)
      |> assign(:pending_cancellations, pending_cancellations)
      |> assign(:pending_returns, pending_returns)
      |> assign(:page_title, "Order Dashboard")

    {:ok, socket}
  end

  def handle_event("filter_orders", %{"filters" => filters}, socket) do
    orders = Orders.list_orders_with_details(filters)
    
    {:noreply, assign(socket, :recent_orders, orders)}
  end

  def handle_event("export_orders", %{"format" => format}, socket) do
    orders = Orders.list_orders_with_details()
    
    case format do
      "csv" -> 
        csv_data = Orders.export_to_csv(orders)
        {:noreply, 
         socket
         |> put_flash(:info, "CSV export ready for download")
         |> assign(:csv_export, csv_data)}
      
      "excel" ->
        excel_data = Orders.export_to_excel(orders)
        {:noreply, 
         socket
         |> put_flash(:info, "Excel export ready for download")
         |> assign(:excel_export, excel_data)}
    end
  end

  defp get_order_statistics do
    %{
      total_orders: Orders.count_orders(),
      pending_orders: Orders.count_orders(%{status: "pending"}),
      completed_orders: Orders.count_orders(%{status: "completed"}),
      cancelled_orders: Orders.count_orders(%{status: "cancelled"}),
      total_revenue: Orders.calculate_total_revenue(),
      avg_order_value: Orders.calculate_avg_order_value(),
      orders_today: Orders.count_orders_today(),
      orders_this_week: Orders.count_orders_this_week()
    }
  end
end
```

## 4. Email Notification Preferences

### A. Email Preferences Schema
```elixir
# Migration: create_email_preferences
defmodule Shomp.Repo.Migrations.CreateEmailPreferences do
  use Ecto.Migration

  def change do
    create table(:email_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      
      # Order notifications
      add :order_confirmation, :boolean, default: true
      add :order_status_updates, :boolean, default: true
      add :shipping_notifications, :boolean, default: true
      add :delivery_confirmation, :boolean, default: true
      
      # Support notifications
      add :support_ticket_updates, :boolean, default: true
      add :support_ticket_resolved, :boolean, default: true
      
      # Marketing notifications
      add :product_updates, :boolean, default: false
      add :promotional_emails, :boolean, default: false
      add :newsletter, :boolean, default: false
      
      # System notifications
      add :security_alerts, :boolean, default: true
      add :account_updates, :boolean, default: true
      add :system_maintenance, :boolean, default: true
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_preferences, [:user_id])
  end
end
```

### B. Email Preferences Context
```elixir
# lib/shomp/email_preferences.ex
defmodule Shomp.EmailPreferences do
  @moduledoc """
  The EmailPreferences context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.EmailPreferences.EmailPreference

  def get_user_preferences(user_id) do
    case Repo.get_by(EmailPreference, user_id: user_id) do
      nil -> create_default_preferences(user_id)
      preferences -> preferences
    end
  end

  def update_preferences(user_id, attrs) do
    preferences = get_user_preferences(user_id)
    
    preferences
    |> EmailPreference.changeset(attrs)
    |> Repo.update()
  end

  def can_send_email?(user_id, email_type) do
    preferences = get_user_preferences(user_id)
    Map.get(preferences, email_type, true)
  end

  defp create_default_preferences(user_id) do
    %EmailPreference{}
    |> EmailPreference.changeset(%{user_id: user_id})
    |> Repo.insert!()
  end
end
```

### C. Email Preferences LiveView
```elixir
# lib/shomp_web/live/user_live/email_preferences.ex
defmodule ShompWeb.UserLive.EmailPreferences do
  use ShompWeb, :live_view

  alias Shomp.EmailPreferences

  on_mount {ShompWeb.UserAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    preferences = EmailPreferences.get_user_preferences(user.id)
    
    socket = 
      socket
      |> assign(:preferences, preferences)
      |> assign(:page_title, "Email Preferences")

    {:ok, socket}
  end

  def handle_event("update_preferences", %{"preferences" => pref_params}, socket) do
    user = socket.assigns.current_scope.user
    
    case EmailPreferences.update_preferences(user.id, pref_params) do
      {:ok, updated_preferences} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Email preferences updated successfully")
         |> assign(:preferences, updated_preferences)}
      
      {:error, changeset} ->
        {:noreply, assign(socket, :preferences_changeset, changeset)}
    end
  end

  def handle_event("reset_to_defaults", _params, socket) do
    user = socket.assigns.current_scope.user
    
    default_prefs = %{
      order_confirmation: true,
      order_status_updates: true,
      shipping_notifications: true,
      delivery_confirmation: true,
      support_ticket_updates: true,
      support_ticket_resolved: true,
      product_updates: false,
      promotional_emails: false,
      newsletter: false,
      security_alerts: true,
      account_updates: true,
      system_maintenance: true
    }
    
    case EmailPreferences.update_preferences(user.id, default_prefs) do
      {:ok, updated_preferences} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Email preferences reset to defaults")
         |> assign(:preferences, updated_preferences)}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reset preferences")}
    end
  end
end
```

## 5. Enhanced Notification System

### A. Smart Notification Sender
```elixir
# lib/shomp/notifications/smart_notifier.ex
defmodule Shomp.Notifications.SmartNotifier do
  @moduledoc """
  Smart notification system that respects user email preferences.
  """

  alias Shomp.EmailPreferences
  alias Shomp.Notifications

  def send_order_confirmation(order) do
    if EmailPreferences.can_send_email?(order.user_id, :order_confirmation) do
      Notifications.send_order_confirmation(order)
    else
      {:ok, :preference_blocked}
    end
  end

  def send_fulfillment_notification(order) do
    if EmailPreferences.can_send_email?(order.user_id, :order_status_updates) do
      Notifications.send_fulfillment_notification(order)
    else
      {:ok, :preference_blocked}
    end
  end

  def send_tracking_notification(order) do
    if EmailPreferences.can_send_email?(order.user_id, :shipping_notifications) do
      Notifications.send_tracking_notification(order)
    else
      {:ok, :preference_blocked}
    end
  end

  def send_ticket_reply_notification(ticket, message) do
    if EmailPreferences.can_send_email?(ticket.user_id, :support_ticket_updates) do
      Notifications.send_ticket_reply_notification(ticket, message)
    else
      {:ok, :preference_blocked}
    end
  end

  def send_ticket_resolution_notification(ticket) do
    if EmailPreferences.can_send_email?(ticket.user_id, :support_ticket_resolved) do
      Notifications.send_ticket_resolution_notification(ticket)
    else
      {:ok, :preference_blocked}
    end
  end
end
```

### B. Support Ticket Notifications
```elixir
# lib/shomp/notifications/support_notifier.ex
defmodule Shomp.Notifications.SupportNotifier do
  import Swoosh.Email
  alias Shomp.Mailer

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Shomp Support", "support@shomp.co"})
      |> subject(subject)
      |> html_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def send_new_ticket_notification(ticket) do
    # Notify all admin users
    admin_emails = Shomp.Accounts.list_admin_emails()
    
    Enum.each(admin_emails, fn admin_email ->
      deliver(admin_email, "New Support Ticket: #{ticket.ticket_number}", """
      <h2>New Support Ticket</h2>
      <p><strong>Ticket:</strong> #{ticket.ticket_number}</p>
      <p><strong>Subject:</strong> #{ticket.subject}</p>
      <p><strong>Priority:</strong> #{ticket.priority}</p>
      <p><strong>Category:</strong> #{ticket.category}</p>
      <p><strong>Customer:</strong> #{ticket.user.email}</p>
      
      <h3>Description:</h3>
      <p>#{ticket.description}</p>
      
      <p><a href="#{admin_ticket_url(ticket)}">View Ticket</a></p>
      """)
    end)
  end

  def send_ticket_reply_notification(ticket, message) do
    deliver(ticket.user.email, "Reply to Ticket #{ticket.ticket_number}", """
    <h2>New Reply to Your Support Ticket</h2>
    <p>You have received a new reply to your support ticket <strong>#{ticket.ticket_number}</strong>.</p>
    
    <h3>Reply:</h3>
    <p>#{message.message}</p>
    
    <p><a href="#{ticket_url(ticket)}">View Full Conversation</a></p>
    """)
  end

  def send_admin_ticket_reply_notification(ticket, message) do
    # Notify assigned admin or all admins if unassigned
    notify_emails = if ticket.assigned_to_user_id do
      [ticket.assigned_to_user.email]
    else
      Shomp.Accounts.list_admin_emails()
    end
    
    Enum.each(notify_emails, fn admin_email ->
      deliver(admin_email, "Customer Reply to Ticket #{ticket.ticket_number}", """
      <h2>Customer Reply</h2>
      <p>Customer has replied to ticket <strong>#{ticket.ticket_number}</strong>.</p>
      
      <h3>Customer Reply:</h3>
      <p>#{message.message}</p>
      
      <p><a href="#{admin_ticket_url(ticket)}">View Ticket</a></p>
      """)
    end)
  end

  def send_ticket_resolution_notification(ticket) do
    deliver(ticket.user.email, "Ticket Resolved: #{ticket.ticket_number}", """
    <h2>Support Ticket Resolved</h2>
    <p>Your support ticket <strong>#{ticket.ticket_number}</strong> has been resolved.</p>
    
    <h3>Resolution Notes:</h3>
    <p>#{ticket.resolution_notes}</p>
    
    <p><a href="#{ticket_url(ticket)}">View Ticket Details</a></p>
    """)
  end

  defp ticket_url(ticket) do
    "#{ShompWeb.Endpoint.url()}/support/#{ticket.id}"
  end

  defp admin_ticket_url(ticket) do
    "#{ShompWeb.Endpoint.url()}/admin/support/#{ticket.id}"
  end
end
```

## 6. User Dropdown Integration

### A. Enhanced User Dropdown Component
```elixir
# lib/shomp_web/components/user_dropdown.ex
defmodule ShompWeb.Components.UserDropdown do
  use ShompWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar">
        <div class="w-10 rounded-full">
          <img alt="User avatar" src={@current_user.avatar_url || "/images/default-avatar.png"} />
        </div>
      </div>
      <ul tabindex="0" class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow bg-base-100 rounded-box w-52">
        <li><a href={~p"/dashboard"}>Dashboard</a></li>
        <li><a href={~p"/orders"}>My Orders</a></li>
        <li><a href={~p"/support"}>Support Tickets</a></li>
        <li><a href={~p"/profile"}>Profile Settings</a></li>
        <li><a href={~p"/email-preferences"}>Email Preferences</a></li>
        <li><a href={~p"/stores"}>My Stores</a></li>
        <li><a href={~p"/feature-requests"}>Feature Requests</a></li>
        <li><a href={~p"/donation"}>Donate</a></li>
        <li><a href={~p"/about"}>About</a></li>
        <li><a href={~p"/logout"} data-method="delete">Logout</a></li>
      </ul>
    </div>
    """
  end
end
```

## 7. Routes and Navigation

### A. Enhanced Router
```elixir
# lib/shomp_web/router.ex - Additional routes
scope "/", ShompWeb do
  # Support system routes
  live "/support", SupportLive.Index, :index
  live "/support/:id", SupportLive.Show, :show
  live "/support/new", SupportLive.New, :new
  
  # Email preferences
  live "/email-preferences", UserLive.EmailPreferences, :index
  
  # Admin support routes
  live "/admin/support", AdminLive.SupportDashboard, :index
  live "/admin/support/:id", AdminLive.SupportTicket, :show
  live "/admin/orders", AdminLive.OrderDashboard, :index
end
```

## 8. Implementation Priority

### Phase 1: Core Support System (Week 1-2)
1. Support ticket schema and context
2. Basic support ticket interface
3. Admin support dashboard
4. Email notification preferences

## 9. Testing Strategy

### A. Unit Tests
- Support ticket creation and updates
- Email preference validation
- Notification sending logic
- Admin assignment workflows

### B. Integration Tests
- End-to-end support ticket flow
- Email delivery with preferences
- Admin dashboard functionality
- User interface interactions


