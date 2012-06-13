class Manager.Pages extends Spine.Stack
  controllers:
    token:     Controller.Token
    dashboard: Controller.Dashboard
    open:      Controller.Open
    config:    Controller.Config
    close:     Controller.Close
    sync:      Controller.Sync
    logout:    Controller.Logout
    loading:   Controller.Loading
    error:     Controller.Error
  routes:
    "/":            "token"
    "/dashboard":   "dashboard"
    "/open":        "open"
    "/close/:bid":  "close"
    "/config/:bid": "config"
    "/sync/:bid":   "sync"
    "/logout":      "logout"

#Emark.app = new App