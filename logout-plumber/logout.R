library(plumber)

# Function to handle cookie expiration
logout_handler <- function(res) {
  cookie_names <- c("AWSELBAuthSessionCookie-0", "AWSELBAuthSessionCookie-1")
  
  # Generate expired cookies
  expired_cookies <- lapply(cookie_names, function(cookie_name) {
    paste0(
      cookie_name, "=; Path=/;", "Expires=Thu, 01 Jan 1970 00:00:00 GMT;"
    )
  })
  
  # Add cookies and headers to the response
  for (cookie in expired_cookies) {
    res$setHeader("Set-Cookie", cookie)
  }
  res$setHeader("Content-Type", "application/json")
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  
  # Set the response status and body
  res$status <- 200
  list(message = "Logged out successfully! Cookies deleted.")
}

# Create a Plumber API
pr <- plumber$new()

# Define the /logout endpoint
pr$handle("GET", "/logout", logout_handler)

# Start the server
pr$run(host = "0.0.0.0", port = 6030)
