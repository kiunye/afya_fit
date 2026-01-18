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
import {hooks as colocatedHooks} from "phoenix-colocated/afya_fit"
import topbar from "../vendor/topbar"

// Sidebar hook for LiveView
const SidebarHook = {
  mounted() {
    // Initialize sidebar state on mobile
    if (window.innerWidth < 1024) {
      this.el.classList.add("-translate-x-full")
    }
    
    // Set up toggle function
    this.toggle = () => {
      this.el.classList.toggle("-translate-x-full")
    }
    
    // Make it available globally
    window.toggleSidebar = this.toggle.bind(this)
  },
  
  updated() {
    // Re-initialize on updates
    if (window.innerWidth < 1024) {
      this.el.classList.add("-translate-x-full")
    }
  }
}

// Particles hook for floating particle effects
const ParticlesHook = {
  mounted() {
    const particles = this.el.querySelectorAll('.particle')
    const container = this.el
    
    particles.forEach((particle, index) => {
      // Random starting position
      const startX = Math.random() * 100
      const startY = Math.random() * 100
      
      // Random horizontal drift
      const driftX = (Math.random() - 0.5) * 200
      
      // Random duration between 10-20 seconds
      const duration = 10 + Math.random() * 10
      
      // Random delay
      const delay = Math.random() * 5
      
      // Set initial position
      particle.style.left = `${startX}%`
      particle.style.bottom = `${startY}%`
      
      // Set CSS custom properties for animation
      particle.style.setProperty('--particle-x', `${driftX}px`)
      particle.style.setProperty('--particle-duration', `${duration}s`)
      particle.style.setProperty('--particle-delay', `${delay}s`)
    })
  },
  
  updated() {
    // Re-initialize particles on update
    this.mounted()
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...colocatedHooks,
    Sidebar: SidebarHook,
    Particles: ParticlesHook
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

// Theme toggle functionality
window.addEventListener("phx:set-theme", (e) => {
  const theme = e.target.dataset.phxTheme
  localStorage.setItem("phx:theme", theme)
  document.documentElement.setAttribute("data-theme", theme)
})

// Fallback toggle function for non-LiveView contexts
function toggleSidebar() {
  const sidebar = document.getElementById("sidebar")
  if (sidebar) {
    sidebar.classList.toggle("-translate-x-full")
  }
}

// Make toggleSidebar available globally as fallback
if (!window.toggleSidebar) {
  window.toggleSidebar = toggleSidebar
}

// Close sidebar when clicking outside on mobile
document.addEventListener("click", (e) => {
  const sidebar = document.getElementById("sidebar")
  const toggleButtons = document.querySelectorAll("button[data-sidebar-toggle]")
  const isToggleButton = Array.from(toggleButtons).some(btn => btn.contains(e.target))
  
  if (sidebar && !sidebar.contains(e.target) && !isToggleButton) {
    if (window.innerWidth < 1024) {
      sidebar.classList.add("-translate-x-full")
    }
  }
})

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

