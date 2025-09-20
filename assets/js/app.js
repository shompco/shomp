// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/shomp"
import topbar from "../vendor/topbar"

// Import upload preview functionality
import "./upload_preview.js"

// Import image carousel functionality
import "./image_carousel.js"

// Digital file upload hook
const DigitalFileUpload = {
  mounted() {
    console.log('DigitalFileUpload mounted')
    this.updateDisabledState()
  },
  
  updated() {
    console.log('DigitalFileUpload updated')
    this.updateDisabledState()
  },
  
  updateDisabledState() {
    const productType = this.el.getAttribute('data-product-type')
    console.log('Product type:', productType)
    const fileInput = this.el.querySelector('input[type="file"]')
    console.log('File input found:', fileInput)
    if (fileInput) {
      const shouldDisable = productType !== 'digital'
      console.log('Should disable:', shouldDisable)
      fileInput.disabled = shouldDisable
      console.log('File input disabled state:', fileInput.disabled)
    }
  }
}

// Custom hooks for real-time features
const VoteUpdates = {
  mounted() {
    this.handleEvent("update_vote_total", ({request_id, total, username, action, weight}) => {
      const voteTotalElement = document.getElementById(`vote-total-${request_id}`)
      if (voteTotalElement) {
        // Add a subtle animation effect
        voteTotalElement.style.transform = "scale(1.1)"
        voteTotalElement.style.transition = "transform 0.2s ease-in-out"
        
        // Update the vote count
        voteTotalElement.textContent = total
        
        // Reset the animation
        setTimeout(() => {
          voteTotalElement.style.transform = "scale(1)"
        }, 200)
        
        // Show a detailed notification
        this.showVoteNotification(request_id, total, username, action, weight)
      }
    })
  },
  
  showVoteNotification(request_id, total, username, action, weight) {
    // Create a floating notification with more details
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 bg-blue-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 transform translate-x-full transition-transform duration-300 max-w-sm'
    
    // Create detailed message
    let message = ''
    if (action === 'voted') {
      const voteType = weight > 0 ? 'upvoted' : 'downvoted'
      message = `@${username} ${voteType} this request`
    } else if (action === 'removed vote') {
      message = `@${username} removed their vote`
    } else if (action === 'updated vote') {
      const voteType = weight > 0 ? 'upvoted' : 'downvoted'
      message = `@${username} changed to ${voteType}`
    }
    
    notification.innerHTML = `
      <div class="font-medium">${message}</div>
      <div class="text-sm opacity-90">New total: ${total} votes</div>
    `
    
    document.body.appendChild(notification)
    
    // Slide in
    setTimeout(() => {
      notification.style.transform = 'translateX(0)'
    }, 100)
    
    // Slide out and remove
    setTimeout(() => {
      notification.style.transform = 'translateX(full)'
      setTimeout(() => {
        document.body.removeChild(notification)
      }, 300)
    }, 3000)
  }
}

// File upload debugging hook
const FileUploadHook = {
  mounted() {
    console.log("FileUploadHook mounted")
    this.el.addEventListener("change", (e) => {
      console.log("File selected:", e.target.files)
      console.log("File count:", e.target.files.length)
      if (e.target.files.length > 0) {
        console.log("First file:", e.target.files[0])
        console.log("File name:", e.target.files[0].name)
        console.log("File size:", e.target.files[0].size)
        console.log("File type:", e.target.files[0].type)
      }
    })
  }
}


// Cart donation checkbox hook
const CartDonationHook = {
  mounted() {
    // Handle Buy Now button clicks to capture checkbox state
    this.el.addEventListener('click', (e) => {
      if (e.target.matches('[data-donate-checkbox]')) {
        const checkboxId = e.target.getAttribute('data-donate-checkbox')
        const checkbox = document.getElementById(checkboxId)
        if (checkbox) {
          // Update the phx-value-donate attribute based on checkbox state
          e.target.setAttribute('phx-value-donate', checkbox.checked)
          console.log('Updated donate value to:', checkbox.checked)
        }
      }
    })
  }
}

// US Citizenship validation hook
const UsCitizenshipValidation = {
  mounted() {
    const checkbox = this.el.querySelector('input[type="checkbox"][name*="us_citizen_confirmation"]')
    const submitBtn = document.getElementById('create-store-btn')
    
    if (checkbox && submitBtn) {
      // Initial state - disable button if checkbox is unchecked
      this.updateButtonState(checkbox.checked, submitBtn)
      
      // Add event listener for checkbox changes
      checkbox.addEventListener('change', (e) => {
        this.updateButtonState(e.target.checked, submitBtn)
      })
    }
  },
  
  updateButtonState(isChecked, submitBtn) {
    if (isChecked) {
      submitBtn.disabled = false
      submitBtn.classList.remove('btn-disabled')
      submitBtn.classList.add('btn-primary')
    } else {
      submitBtn.disabled = true
      submitBtn.classList.add('btn-disabled')
      submitBtn.classList.remove('btn-primary')
    }
  }
}

// Show/Hide on Type Change hook
const ShowHideOnTypeChange = {
  mounted() {
    // This hook handles showing/hiding sections based on product type
    this.initializeSections()
  },
  
  updated() {
    // Re-initialize after LiveView updates
    this.initializeSections()
  },
  
  initializeSections() {
    const typeSelect = document.querySelector('select[name*="type"]')
    if (typeSelect) {
      // Remove existing listener to avoid duplicates
      typeSelect.removeEventListener('change', this.handleTypeChange)
      typeSelect.addEventListener('change', this.handleTypeChange.bind(this))
      
      // Initialize on mount
      this.toggleSections(typeSelect.value)
    }
  },
  
  handleTypeChange(e) {
    const selectedType = e.target.value
    this.toggleSections(selectedType)
  },
  
  toggleSections(type) {
    // Show/hide quantity section
    const quantitySection = document.getElementById('quantity-section')
    if (quantitySection) {
      if (type === 'physical') {
        quantitySection.classList.remove('hidden')
      } else {
        quantitySection.classList.add('hidden')
      }
    }
    
    // Show/hide digital file upload section
    const digitalFileSection = document.getElementById('digital-file-section')
    if (digitalFileSection) {
      if (type === 'digital') {
        digitalFileSection.classList.remove('hidden')
      } else {
        digitalFileSection.classList.add('hidden')
      }
    }
  }
}

// Purchase Toaster Hook
const PurchaseToaster = {
  mounted() {
    console.log('PurchaseToaster hook mounted');
    this.loadToasters();
    this.setupPubSub();
  },
  
  destroyed() {
    if (this.socket) {
      this.socket.disconnect();
    }
  },
  
  async loadToasters() {
    // No need to load initial toasters since we're using real-time events
    console.log('Toaster system ready for real-time events');
  },
  
  setupPubSub() {
    console.log('Setting up PubSub connection');
    // Use Phoenix PubSub for real-time updates
    this.socket = new Socket("/socket", {})
    this.socket.connect()
    
    this.channel = this.socket.channel("purchase_activities", {})
    this.channel.join()
      .receive("ok", resp => { console.log("Joined purchase_activities channel", resp) })
      .receive("error", resp => { console.log("Unable to join purchase_activities channel", resp) })
    
    this.channel.on("purchase_completed", (payload) => {
      console.log("Received purchase_completed event:", payload);
      this.addToaster(payload);
    });
  },
  
  addToaster(activity) {
    console.log('Adding toaster for activity:', activity);
    const toasterId = `toaster-${activity.id}-${Date.now()}`;
    const toaster = document.createElement('div');
    toaster.id = toasterId;
    toaster.className = 'toast toast-bottom toast-start animate-slide-up mb-2 fixed bottom-4 left-4 z-50 transition-opacity duration-500 cursor-pointer hover:shadow-xl';
    
    toaster.innerHTML = `
      <div class="alert alert-info shadow-lg">
        <div class="flex items-center space-x-3">
          <div class="avatar placeholder">
            <div class="bg-primary text-primary-content rounded-full w-8">
              <span class="text-xs font-bold">${activity.buyer_initials}</span>
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-base-content">
              Just purchased <span class="font-semibold">${activity.product_title}</span>
            </p>
            <p class="text-xs text-base-content/70">
              ${activity.buyer_location} • Just now
            </p>
          </div>
          <button class="btn btn-ghost btn-xs" onclick="event.stopPropagation(); this.closest('.toast').remove()">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    `;
    
    // Add click handler to navigate to product detail page
    toaster.addEventListener('click', () => {
      console.log('Toaster clicked, activity data:', activity);
      if (activity.product_url) {
        console.log('Navigating to product URL:', activity.product_url);
        window.location.href = activity.product_url;
      } else {
        console.log('No product_url available in activity data');
      }
    });
    
    document.body.appendChild(toaster);
    
    // Auto-remove after 18 seconds with fade-out effect
    setTimeout(() => {
      const element = document.getElementById(toasterId);
      if (element) {
        // Add fade-out class
        element.classList.add('opacity-0');
        // Remove from DOM after fade animation completes
        setTimeout(() => {
          if (element.parentNode) {
            element.remove();
          }
        }, 500); // Match the transition duration
      }
    }, 18000);
  },
  
  formatAmount(amount) {
    return Math.round(parseFloat(amount));
  }
}


const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...colocatedHooks,
    VoteUpdates,
    FileUploadHook,
    CartDonationHook,
    UsCitizenshipValidation,
    DigitalFileUpload,
    ShowHideOnTypeChange,
    PurchaseToaster
  },
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

// Product Image Rotation on Hover
document.addEventListener('DOMContentLoaded', function() {
  initializeProductImageRotators();
  
  // Re-initialize after LiveView updates
  document.addEventListener('phx:update', function() {
    initializeProductImageRotators();
  });
});

function initializeProductImageRotators() {
  const rotators = document.querySelectorAll('.product-image-rotator');
  
  rotators.forEach(rotator => {
    const images = JSON.parse(rotator.dataset.images || '[]');
    if (images.length <= 1) return; // No rotation needed
    
    let currentIndex = 0;
    let rotationInterval;
    let isHovering = false;
    
    // Get all images in this rotator
    const imageElements = rotator.querySelectorAll('img');
    
    // Function to show image at specific index
    function showImage(index) {
      imageElements.forEach((img, i) => {
        img.style.opacity = i === index ? '1' : '0';
        img.setAttribute('data-image-index', i === index ? '0' : '1');
      });
    }
    
    // Function to rotate to next image
    function rotateToNext() {
      if (!isHovering) return;
      currentIndex = (currentIndex + 1) % images.length;
      showImage(currentIndex);
    }
    
    // Start rotation on hover
    rotator.addEventListener('mouseenter', function() {
      isHovering = true;
      rotationInterval = setInterval(rotateToNext, 1500); // 1.5 seconds
    });
    
    // Stop rotation and reset on mouse leave
    rotator.addEventListener('mouseleave', function() {
      isHovering = false;
      if (rotationInterval) {
        clearInterval(rotationInterval);
        rotationInterval = null;
      }
      // Reset to first image
      currentIndex = 0;
      showImage(0);
    });
  });
}

