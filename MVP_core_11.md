# Shomp MVP Core 11 - Secure Digital File Uploads & Protected Downloads

## 1. File Upload System (Shomp.Uploads)
### Context & Schema
- `Shomp.Uploads.DigitalFile` schema (immutable_id, product_id, filename, file_path, file_size, mime_type, checksum, created_at)
- `Shomp.Uploads` context (upload_file, create_download_link, validate_download, track_download)

### Features
- Secure file upload with progress tracking
- MIME type validation and file size limits
- SHA-256 checksums for file integrity
- Only authorized users can upload to their products

## 2. Download Link System (Shomp.Downloads)
### Context & Schema
- `Shomp.Downloads.DownloadLink` schema (immutable_id, digital_file_id, user_id, order_id, access_token, download_count, max_downloads, expires_at, created_at)
- `Shomp.Downloads` context (create_download_link, validate_access, track_download, cleanup_expired)

### Features
- **24-hour expiration** from link creation
- **Maximum 5 downloads** per link
- Cryptographically secure access tokens
- Download tracking with IP and user agent logging

## 3. Database Schema
### DigitalFiles Table
```elixir
create table(:digital_files) do
  add :immutable_id, :string, null: false
  add :product_id, references(:products, type: :string), null: false
  add :filename, :string, null: false
  add :file_path, :string, null: false
  add :file_size, :bigint, null: false
  add :mime_type, :string, null: false
  add :checksum, :string, null: false
  
  timestamps()
end
```

### DownloadLinks Table
```elixir
create table(:download_links) do
  add :immutable_id, :string, null: false
  add :digital_file_id, references(:digital_files, type: :string), null: false
  add :user_id, references(:users, type: :bigserial), null: false
  add :order_id, references(:universal_orders, type: :string), null: false
  add :access_token, :string, null: false
  add :download_count, :integer, default: 0, null: false
  add :max_downloads, :integer, default: 5, null: false
  add :expires_at, :utc_datetime, null: false
  
  timestamps()
end
```

## 4. Routes
- `POST /api/uploads` - Upload file
- `GET /downloads/:token` - Secure download endpoint
- `GET /dashboard/products/:id/files` - Product file management

## 5. Context Functions
```elixir
defmodule Shomp.Uploads do
  def upload_file(user_id, product_id, file)
  def get_digital_file(file_id)
  def get_product_files(product_id)
end

defmodule Shomp.Downloads do
  def create_download_link(user_id, order_id, digital_file_id)
  def validate_download_token(token)
  def track_download(token, ip_address, user_agent)
end
```


