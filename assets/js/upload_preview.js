// Upload Preview JavaScript
// Handles image previews and file upload interactions

document.addEventListener('DOMContentLoaded', function() {
  console.log('Upload preview script loaded');
  
  // Image preview functionality
  const imageInput = document.querySelector('input[type="file"][phx-upload-ref]') || document.querySelector('input[name="product_images[]"]');
  const imagePreview = document.getElementById('image-preview');
  
  console.log('Image input found:', !!imageInput);
  console.log('Image preview found:', !!imagePreview);
  
  if (imageInput && imagePreview) {
    const uploadBtn = document.getElementById('upload_images_btn');
    const uploadStatus = document.getElementById('upload-status');
    const uploadSpinner = document.getElementById('upload-spinner');
    const uploadMessage = document.getElementById('upload-message');
    
    imageInput.addEventListener('change', function(e) {
      const files = Array.from(e.target.files);
      console.log('Image input changed, files:', files);
      
      // Clear existing previews
      imagePreview.innerHTML = '';
      
      // Enable/disable upload button based on file selection
      if (uploadBtn) {
        uploadBtn.disabled = files.length === 0;
      }
      
      // Hide upload status
      if (uploadStatus) {
        uploadStatus.classList.add('hidden');
      }
      
      // Create previews for each selected image
      files.forEach((file, index) => {
        console.log('Processing file:', file.name, 'type:', file.type, 'size:', file.size);
        
        if (file.type.startsWith('image/')) {
          const reader = new FileReader();
          
          reader.onload = function(e) {
            console.log('File loaded successfully, creating preview for:', file.name);
            const previewDiv = document.createElement('div');
            previewDiv.className = 'relative group';
            
            previewDiv.innerHTML = `
              <img src="${e.target.result}" 
                   alt="Preview ${index + 1}" 
                   class="w-full h-24 object-cover rounded-lg shadow-sm group-hover:shadow-md transition-shadow duration-200"
                   onload="console.log('Image loaded successfully')"
                   onerror="console.error('Image failed to load')" />
              <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-20 transition-all duration-200 rounded-lg flex items-center justify-center">
                <span class="text-white opacity-0 group-hover:bg-opacity-100 text-sm font-medium">
                  Image ${index + 1}
                </span>
              </div>
            `;
            
            imagePreview.appendChild(previewDiv);
            console.log('Preview added to DOM');
          };
          
          reader.onerror = function(error) {
            console.error('Error reading file:', error);
          };
          
          reader.readAsDataURL(file);
        } else {
          console.log('File is not an image:', file.type);
        }
      });
    });
    
    // Handle upload button click
    if (uploadBtn) {
      uploadBtn.addEventListener('click', function() {
        const files = Array.from(imageInput.files);
        
        if (files.length === 0) {
          return;
        }
        
        console.log('Upload button clicked, uploading', files.length, 'files');
        
        // Show upload status
        if (uploadStatus && uploadSpinner && uploadMessage) {
          uploadStatus.classList.remove('hidden');
          uploadSpinner.classList.remove('hidden');
          uploadMessage.textContent = `Uploading ${files.length} image(s)...`;
          uploadMessage.className = 'text-sm font-medium text-blue-600';
        }
        
        // Disable upload button during upload
        uploadBtn.disabled = true;
        uploadBtn.textContent = 'Uploading...';
      });
    }
  }
  
  // Listen for upload completion from LiveView
  document.addEventListener('phx:upload-complete', function(e) {
    console.log('Upload completed:', e.detail);
    
    const uploadBtn = document.getElementById('upload_images_btn');
    const uploadStatus = document.getElementById('upload-status');
    const uploadSpinner = document.getElementById('upload-spinner');
    const uploadMessage = document.getElementById('upload-message');
    
    if (uploadBtn) {
      uploadBtn.disabled = false;
      uploadBtn.textContent = 'Upload Images';
    }
    
    if (uploadStatus && uploadSpinner && uploadMessage) {
      uploadSpinner.classList.add('hidden');
      
      if (e.detail.success) {
        uploadMessage.textContent = e.detail.message || 'Images uploaded successfully!';
        uploadMessage.className = 'text-sm font-medium text-green-600';
      } else {
        uploadMessage.textContent = e.detail.message || 'Upload failed. Please try again.';
        uploadMessage.className = 'text-sm font-medium text-red-600';
      }
    }
  });
  
  // File upload feedback
  const fileInput = document.querySelector('input[name="product_file"]');
  if (fileInput) {
    fileInput.addEventListener('change', function(e) {
      const file = e.target.files[0];
      if (file) {
        // Show file info
        const fileInfo = document.createElement('div');
        fileInfo.className = 'mt-2 p-2 bg-blue-50 text-blue-700 rounded text-sm';
        fileInfo.textContent = `Selected: ${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`;
        
        // Remove existing file info
        const existingInfo = fileInput.parentNode.querySelector('.bg-blue-50');
        if (existingInfo) {
          existingInfo.remove();
        }
        
        fileInput.parentNode.appendChild(fileInfo);
      }
    });
  }
  
  // Form validation for file uploads
  const form = document.getElementById('product_form');
  if (form) {
    form.addEventListener('submit', function(e) {
      const productType = document.querySelector('select[name="product[type]"]').value;
      
      if (productType === 'digital') {
        const fileInput = document.querySelector('input[name="product_file"]');
        if (!fileInput.files || fileInput.files.length === 0) {
          e.preventDefault();
          alert('Please select a file for digital products.');
          return false;
        }
      }
      
      // Validate file sizes
      const maxSize = 10 * 1024 * 1024; // 10MB
      let hasLargeFile = false;
      
      // Check image files
      const imageFiles = document.querySelector('input[name="product_images[]"]').files;
      Array.from(imageFiles).forEach(file => {
        if (file.size > maxSize) {
          hasLargeFile = true;
        }
      });
      
      // Check digital file
      const digitalFile = document.querySelector('input[name="product_file"]')?.files[0];
      if (digitalFile && digitalFile.size > maxSize) {
        hasLargeFile = true;
      }
      
      if (hasLargeFile) {
        e.preventDefault();
        alert('One or more files exceed the 10MB size limit.');
        return false;
      }
    });
  }
  
  // Product image switching functionality
  const mainProductImage = document.getElementById('main-product-image');
  if (mainProductImage) {
    // Listen for image switch events from LiveView
    window.addEventListener('phx:switch-main-image', (e) => {
      const { image_path } = e.detail;
      if (image_path && mainProductImage) {
        // Smooth transition effect
        mainProductImage.style.opacity = '0';
        mainProductImage.style.transition = 'opacity 0.3s ease-in-out';
        
        setTimeout(() => {
          mainProductImage.src = image_path;
          mainProductImage.style.opacity = '1';
        }, 150);
      }
    });
    
    // Add click handlers for thumbnail navigation
    const thumbnailButtons = document.querySelectorAll('[phx-click="switch_image"]');
    thumbnailButtons.forEach(button => {
      button.addEventListener('click', function() {
        // Remove active state from all buttons
        thumbnailButtons.forEach(btn => {
          btn.classList.remove('border-blue-500');
          btn.classList.add('border-transparent');
        });
        
        // Add active state to clicked button
        this.classList.remove('border-transparent');
        this.classList.add('border-blue-500');
      });
    });
  }
});
