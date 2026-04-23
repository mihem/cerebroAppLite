##----------------------------------------------------------------------------##
## Custom Login Server Module
## Handles authentication logic for Cerebro
##----------------------------------------------------------------------------##

#' Hash Password using SHA-256
#' @param password Plain text password
#' @param salt Salt string for additional security
#' @return Hashed password string
hash_password <- function(password, salt = "cerebro_salt_2024") {
  digest::digest(paste0(password, salt), algo = "sha256", serialize = FALSE)
}

#' Verify Password
#' @param input_password Password entered by user
#' @param stored_hash Stored hashed password
#' @param salt Salt string used during hashing
#' @return Logical indicating if password matches
verify_password <- function(input_password, stored_hash, salt = "cerebro_salt_2024") {
  hash_password(input_password, salt) == stored_hash
}

#' Load Credentials from File
#' @param credentials_path Path to credentials RDS file
#' @return Data frame with user credentials
load_credentials <- function(credentials_path) {
  if (!file.exists(credentials_path)) {
    stop("Credentials file not found: ", credentials_path)
  }
  readRDS(credentials_path)
}

#' Check User Credentials
#' @param username Username to check
#' @param password Password to verify
#' @param credentials Data frame with credentials
#' @param salt Salt for password hashing
#' @return List with success status and user info
check_user_credentials <- function(username, password, credentials, salt = "cerebro_salt_2024") {
  # Validate credentials data frame

  if (is.null(credentials) || nrow(credentials) == 0) {
    return(list(success = FALSE, message = "No credentials configured"))
  }

  # Check required columns exist
  if (!"user" %in% names(credentials) || !"password_hash" %in% names(credentials)) {
    return(list(success = FALSE, message = "Invalid credentials format"))
  }

  # Find user
  user_row <- credentials[credentials$user == username, , drop = FALSE]

  if (is.null(user_row) || nrow(user_row) == 0) {
    return(list(success = FALSE, message = "Invalid username or password"))
  }

  # Get stored hash safely

  stored_hash <- user_row$password_hash[1]
  if (is.null(stored_hash) || is.na(stored_hash) || stored_hash == "") {
    return(list(success = FALSE, message = "Invalid username or password"))
  }

  # Verify password
  if (verify_password(password, stored_hash, salt)) {
    # Get admin status safely
    is_admin <- if ("admin" %in% names(user_row)) user_row$admin[1] else FALSE
    is_admin <- if (is.null(is_admin) || is.na(is_admin)) FALSE else is_admin

    return(list(
      success = TRUE,
      user = username,
      admin = is_admin,
      message = "Login successful"
    ))
  } else {
    return(list(success = FALSE, message = "Invalid username or password"))
  }
}

#' Login Server Logic
#' Call this in your server function to handle authentication
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param credentials_path Path to credentials RDS file
#' @param salt Salt for password hashing
#' @return Reactive value indicating login status
login_server <- function(input, output, session, credentials_path, salt = "cerebro_salt_2024") {

  # Track login attempts for rate limiting
  login_attempts <- reactiveVal(0)
  last_attempt_time <- reactiveVal(Sys.time() - 60)

  # Load credentials
  credentials <- tryCatch({
    load_credentials(credentials_path)
  }, error = function(e) {
    message("Error loading credentials: ", e$message)
    data.frame(user = character(), password_hash = character(), admin = logical())
  })

  # Login state

  auth_state <- reactiveValues(
    logged_in = FALSE,
    user = NULL,
    admin = FALSE
  )

  # Error message output
  output$login_error_msg <- renderUI({
    NULL
  })

  # Handle login button click
  observeEvent(input$login_btn, {
    # Rate limiting: max 5 attempts per minute
    current_time <- Sys.time()
    if (difftime(current_time, last_attempt_time(), units = "secs") > 60) {
      login_attempts(0)
    }

    if (login_attempts() >= 5) {
      output$login_error_msg <- renderUI({
        div(
          class = "login-error",
          icon("exclamation-triangle"),
          "Too many attempts. Please wait a minute."
        )
      })
      return()
    }

    login_attempts(login_attempts() + 1)
    last_attempt_time(current_time)

    # Get input values
    username <- trimws(input$login_username)
    password <- input$login_password

    # Validate inputs
    if (username == "" || password == "") {
      output$login_error_msg <- renderUI({
        div(
          class = "login-error",
          icon("exclamation-circle"),
          "Please enter both username and password"
        )
      })
      return()
    }

    # Check credentials
    result <- check_user_credentials(username, password, credentials, salt)

    if (result$success) {
      # Successful login
      auth_state$logged_in <- TRUE
      auth_state$user <- result$user
      auth_state$admin <- result$admin

      # Log login event
      message(sprintf("[%s] User '%s' logged in successfully", Sys.time(), username))

      # Reset error message
      output$login_error_msg <- renderUI(NULL)

    } else {
      # Failed login
      output$login_error_msg <- renderUI({
        div(
          class = "login-error",
          icon("times-circle"),
          result$message
        )
      })

      # Log failed attempt
      message(sprintf("[%s] Failed login attempt for user '%s'", Sys.time(), username))
    }
  })

  # Return reactive authentication state
  return(reactive({
    list(
      logged_in = auth_state$logged_in,
      user = auth_state$user,
      admin = auth_state$admin
    )
  }))
}

#' Create Logout Button UI
#' @param position Position of the button (default: "top-right")
#' @return Shiny UI tags for logout button
logout_button_ui <- function(position = "top-right") {
  positions <- list(
    "top-right" = "position: fixed; top: 10px; right: 80px; z-index: 9999;",
    "top-left" = "position: fixed; top: 10px; left: 10px; z-index: 9999;",
    "header" = "display: inline-block; margin-left: 10px;"
  )

  # style <- positions[[position]] %||% positions[["top-right"]]
  style <- if (!is.null(positions[[position]])) positions[[position]] else positions[["top-right"]]

  div(
    style = style,
    actionButton(
      inputId = "logout_btn",
      label = "Logout",
      icon = icon("sign-out-alt"),
      class = "btn-sm",
      style = "
        background: #5b7c99;
        border: none;
        color: white;
        border-radius: 20px;
        padding: 8px 20px;
        font-weight: 500;
        box-shadow: 0 2px 10px rgba(91, 124, 153, 0.3);
        transition: all 0.3s ease;
      "
    )
  )
}

#' Handle Logout Logic
#' Call this in your server to handle logout
#' @param input Shiny input object
#' @param session Shiny session object
logout_server <- function(input, session) {
  observeEvent(input$logout_btn, {
    # Reload the session to log out
    session$reload()
  })
}
