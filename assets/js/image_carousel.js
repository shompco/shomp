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
