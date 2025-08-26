// Image Carousel functionality for product pages
document.addEventListener('DOMContentLoaded', function() {
  const mainImage = document.getElementById('main-product-image');
  
  if (mainImage) {
    // Add smooth transition class
    mainImage.classList.add('transition-opacity', 'duration-500');
    
    // Handle image switching with smooth transitions
    window.addEventListener('phx:update', function() {
      // Re-apply transition classes after LiveView updates
      const updatedImage = document.getElementById('main-product-image');
      if (updatedImage) {
        updatedImage.classList.add('transition-opacity', 'duration-500');
      }
    });
  }
  
  // Auto-advance carousel on hover (optional)
  let autoAdvanceInterval;
  const carouselContainer = document.querySelector('.relative.h-80');
  
  if (carouselContainer) {
    carouselContainer.addEventListener('mouseenter', function() {
      // Start auto-advancing every 3 seconds
      autoAdvanceInterval = setInterval(function() {
        const nextButton = document.querySelector('[phx-click="next_image"]');
        if (nextButton) {
          nextButton.click();
        }
      }, 3000);
    });
    
    carouselContainer.addEventListener('mouseleave', function() {
      // Stop auto-advancing
      if (autoAdvanceInterval) {
        clearInterval(autoAdvanceInterval);
      }
    });
  }
});

// Product Image Zoom Functionality (Amazon-style)
document.addEventListener('DOMContentLoaded', function() {
  initializeProductZoom();
  
  // Re-initialize after LiveView updates
  document.addEventListener('phx:update', function() {
    initializeProductZoom();
  });
});

function initializeProductZoom() {
  const zoomContainer = document.querySelector('.product-zoom-container');
  const mainImage = document.getElementById('main-product-image');
  const zoomPreview = document.querySelector('.zoom-preview');
  const zoomImage = document.getElementById('zoom-preview-image');
  
  if (!zoomContainer || !mainImage || !zoomPreview || !zoomImage) return;
  
  let isZooming = false;
  
  // Update zoom image source when main image changes
  function updateZoomImage() {
    const currentSrc = mainImage.src;
    zoomImage.src = currentSrc;
  }
  
  // Handle mouse move for zoom effect
  function handleMouseMove(e) {
    if (!isZooming) return;
    
    const rect = mainImage.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    // Calculate zoom position
    const xPercent = x / rect.width;
    const yPercent = y / rect.height;
    
    // Apply zoom transform to preview image
    const scale = 1.8; // Zoom level (reduced from 2.5x)
    const translateX = -xPercent * (zoomImage.width * scale - zoomPreview.offsetWidth);
    const translateY = -yPercent * (zoomImage.height * scale - zoomPreview.offsetHeight);
    
    zoomImage.style.transform = `scale(${scale}) translate(${translateX}px, ${translateY}px)`;
  }
  
  // Show zoom preview on mouse enter
  zoomContainer.addEventListener('mouseenter', function() {
    isZooming = true;
    zoomPreview.style.opacity = '1';
    zoomPreview.style.pointerEvents = 'auto';
    updateZoomImage();
  });
  
  // Hide zoom preview on mouse leave
  zoomContainer.addEventListener('mouseleave', function() {
    isZooming = false;
    zoomPreview.style.opacity = '0';
    zoomPreview.style.pointerEvents = 'none';
  });
  
  // Update zoom on mouse move
  zoomContainer.addEventListener('mousemove', handleMouseMove);
  
  // Update zoom image when main image changes (for carousel)
  const observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
      if (mutation.type === 'attributes' && mutation.attributeName === 'src') {
        updateZoomImage();
      }
    });
  });
  
  observer.observe(mainImage, { attributes: true });
}
