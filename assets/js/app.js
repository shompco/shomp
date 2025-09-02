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

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...colocatedHooks,
    VoteUpdates,
    FileUploadHook
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

