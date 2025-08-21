import Config

# Upload Configuration
config :shomp, :upload,
  # Storage backend: :local, :s3, or :r2
  storage_backend: :local,
  
  # Local storage settings
  local: [
    # Base directory for uploads (will be created if it doesn't exist)
    upload_dir: "priv/static/uploads",
    
    # Maximum file size in bytes (default: 10MB)
    max_file_size: 10_000_000,
    
    # Allowed file types for images
    allowed_image_types: [".jpg", ".jpeg", ".png", ".gif", ".webp"],
    
    # Allowed file types for digital products
    allowed_file_types: [".pdf", ".zip", ".rar", ".doc", ".docx", ".xls", ".xlsx", ".txt", ".md"]
  ],
  
  # S3 storage settings (future implementation)
  s3: [
    bucket: System.get_env("S3_BUCKET"),
    region: System.get_env("S3_REGION"),
    access_key_id: System.get_env("S3_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("S3_SECRET_ACCESS_KEY")
  ],
  
  # Cloudflare R2 settings (future implementation)
  r2: [
    bucket: System.get_env("R2_BUCKET"),
    endpoint: System.get_env("R2_ENDPOINT"),
    access_key_id: System.get_env("R2_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY")
  ],
  
  # Image processing settings
  image_processing: [
    # Image quality (1-100)
    quality: 85,
    
    # Thumbnail dimensions
    thumb_size: "150x150",
    
    # Medium size dimensions
    medium_size: "400x400",
    
    # Large size dimensions
    large_size: "800x800",
    
    # Extra large dimensions
    extra_large_size: "1200x1200",
    
    # Ultra dimensions for maximum detail
    ultra_size: "1600x1600"
  ]
