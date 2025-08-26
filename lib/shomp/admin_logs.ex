defmodule Shomp.AdminLogs do
  @moduledoc """
  The AdminLogs context for tracking administrative actions.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.AdminLogs.AdminLog

  @doc """
  Creates an admin log entry.
  """
  def create_admin_log(attrs \\ %{}) do
    %AdminLog{}
    |> AdminLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all admin logs, ordered by most recent first.
  """
  def list_admin_logs(limit \\ 50) do
    AdminLog
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets admin logs with user information, ordered by most recent first.
  """
  def list_admin_logs_with_users(limit \\ 50) do
    AdminLog
    |> join(:left, [l], u in Shomp.Accounts.User, on: l.admin_user_id == u.id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> select([l, u], %{
      id: l.id,
      admin_user_id: l.admin_user_id,
      entity_type: l.entity_type,
      entity_id: l.entity_id,
      action: l.action,
      details: l.details,
      metadata: l.metadata,
      inserted_at: l.inserted_at,
      admin_user: %{
        id: u.id,
        username: u.username,
        email: u.email,
        name: u.name
      }
    })
    |> Repo.all()
  end

  @doc """
  Gets admin logs for a specific entity (product, store, user, etc.).
  """
  def get_admin_logs_for_entity(entity_type, entity_id, limit \\ 20) do
    AdminLog
    |> where([l], l.entity_type == ^entity_type and l.entity_id == ^entity_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets admin logs for a specific admin user.
  """
  def get_admin_logs_by_admin(admin_user_id, limit \\ 50) do
    AdminLog
    |> where([l], l.admin_user_id == ^admin_user_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Logs a product edit action.
  """
  def log_product_edit(admin_user_id, product_id, changes, product_before, product_after) do
    changes_summary = format_changes_summary(changes, product_before, product_after)
    
    create_admin_log(%{
      admin_user_id: admin_user_id,
      entity_type: "product",
      entity_id: product_id,
      action: "edit",
      details: changes_summary,
      metadata: %{
        changes: changes,
        before: product_before,
        after: product_after
      }
    })
  end

  @doc """
  Logs a product deletion action.
  """
  def log_product_deletion(admin_user_id, product_id, product_data) do
    create_admin_log(%{
      admin_user_id: admin_user_id,
      entity_type: "product",
      entity_id: product_id,
      action: "delete",
      details: "Product deleted",
      metadata: %{
        deleted_product: product_data
      }
    })
  end

  @doc """
  Logs a store edit action.
  """
  def log_store_edit(admin_user_id, store_id, changes, store_before, store_after) do
    changes_summary = format_changes_summary(changes, store_before, store_after)
    
    create_admin_log(%{
      admin_user_id: admin_user_id,
      entity_type: "store",
      entity_id: store_id,
      action: "edit",
      details: changes_summary,
      metadata: %{
        changes: changes,
        before: store_before,
        after: store_after
      }
    })
  end

  @doc """
  Logs a user edit action.
  """
  def log_user_edit(admin_user_id, user_id, changes, user_before, user_after) do
    changes_summary = format_changes_summary(changes, user_before, user_after)
    
    create_admin_log(%{
      admin_user_id: admin_user_id,
      entity_type: "user",
      entity_id: user_id,
      action: "edit",
      details: changes_summary,
      metadata: %{
        changes: changes,
        before: user_before,
        after: user_after
      }
    })
  end

  @doc """
  Logs a general admin action.
  """
  def log_admin_action(admin_user_id, entity_type, entity_id, action, details, metadata \\ %{}) do
    create_admin_log(%{
      admin_user_id: admin_user_id,
      entity_type: entity_type,
      entity_id: entity_id,
      action: action,
      details: details,
      metadata: metadata
    })
  end

  defp format_changes_summary(changes, before, after_state) do
    changed_fields = Map.keys(changes)
    
    case changed_fields do
      [] -> 
        "No changes detected"
      
      [single_field] -> 
        "Updated #{format_field_name(single_field)}: #{format_field_change(single_field, before, after_state)}"
      
      _ -> 
        field_names = Enum.map(changed_fields, &format_field_name/1)
        "Updated #{Enum.join(field_names, ", ")}"
    end
  end

  defp format_field_name(field) do
    case field do
      "title" -> "Product Title"
      "description" -> "Description"
      "price" -> "Price"
      "type" -> "Product Type"
      "category_id" -> "Platform Category"
      "custom_category_id" -> "Store Category"
      "slug" -> "Product Slug"
      "file_path" -> "Digital File Path"
      "name" -> "Name"
      "email" -> "Email"
      "username" -> "Username"
      "role" -> "Role"
      "status" -> "Status"
      _ -> String.replace(field, "_", " ") |> String.capitalize()
    end
  end

  defp format_field_change(field, before, after_state) do
    before_value = Map.get(before, String.to_atom(field))
    after_value = Map.get(after_state, String.to_atom(field))
    
    case {before_value, after_value} do
      {nil, value} -> 
        if is_binary(value) && value != "", do: "set to \"#{value}\"", else: "set to #{inspect(value)}"
      
      {value, nil} -> 
        if is_binary(value) && value != "", do: "removed (was \"#{value}\")", else: "removed (was #{inspect(value)})"
      
      {old, new} -> 
        cond do
          is_binary(old) && is_binary(new) && old != "" && new != "" ->
            "changed from \"#{old}\" to \"#{new}\""
          is_binary(old) && old != "" ->
            "changed from \"#{old}\" to #{inspect(new)}"
          is_binary(new) && new != "" ->
            "changed from #{inspect(old)} to \"#{new}\""
          true ->
            "changed from #{inspect(old)} to #{inspect(new)}"
        end
    end
  end
end
