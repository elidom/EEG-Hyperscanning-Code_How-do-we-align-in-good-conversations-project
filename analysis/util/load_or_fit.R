#' Load or Fit a Mixed-Effects Model (with automatic refitting on non-convergence)
#'
#' This function checks if a model is already saved as an RDS file. If so, it
#' loads the model. Otherwise, it fits the model specified by the user. If the
#' fitted model does not converge (as determined by buildmer::converged),
#' the function automatically attempts to refit with stricter controls and
#' new starting values. Once a satisfactory model is obtained, it is saved.
#'
#' @param model_name A string, the name of the model (e.g., `"mod_easeUnd"`).
#' @param models_base_dir A string, the base directory where models are saved.
#' @param modelSpec A string containing valid R code that fits the model
#'   (e.g., a call to `lmer(...)` or `clmm(...)`). This must evaluate to
#'   a model object when parsed.
#' @param verbose Logical. If TRUE (default), progress messages are printed.
#' @param max_refit Integer. Maximum number of refit attempts if the model
#'   does not converge. Default = 5.
#' @return The fitted or loaded model object.
#' @importFrom ordinal clmm
#' @importFrom buildmer converged
#' @examples
#' \dontrun{
#'   mod <- load_or_fit(
#'     model_name = "mod_test",
#'     models_base_dir = "models/",
#'     modelSpec = "lme4::lmer(y ~ x + (1|subject), data = df, REML = FALSE)"
#'   )
#' }
load_or_fit <- function(model_name,
                        models_base_dir,
                        modelSpec,
                        verbose = TRUE,
                        max_refit = 5) {
  
  if (!requireNamespace("buildmer", quietly = TRUE)) {
    stop("Package 'buildmer' is required for convergence checks. Please install it.")
  }
  
  model_file_path <- file.path(models_base_dir, paste0(model_name, ".rds"))
  
  if (!dir.exists(models_base_dir)) {
    dir.create(models_base_dir, recursive = TRUE)
    if (verbose) message("Created directory: ", models_base_dir)
  }
  
  # ---- Helper: fit model and capture warnings ----
  fit_model <- function(spec) {
    warnings <- character()
    model <- withCallingHandlers(
      eval(parse(text = spec)),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    if (length(warnings) > 0 && verbose) {
      message("Warnings during fitting:\n", paste(" -", warnings, collapse = "\n"))
    }
    model
  }
  
  # ---- Helper: auto-refit loop ----
  autoRefit <- function(mod, max_attempts = max_refit) {
    conv_result <- buildmer::converged(mod)
    convergedCheck <- isTRUE(conv_result)
    reason <- attr(conv_result, "reason")
    attemptNum <- 1
    
    # If convergence failed but reason is "Singular fit", accept it
    if (!convergedCheck && identical(reason, "Singular fit")) {
      if (verbose) message("Model convergence flagged as 'Singular fit' — accepting model as converged.")
      return(mod)
    }
    
    while (!convergedCheck && attemptNum <= max_attempts) {
      if (verbose) message("Refit attempt ", attemptNum, " (model not converged, reason: ", reason, ")")
      
      fitVals <- tryCatch(getME(mod, "theta"), error = function(e) NULL)
      if (is.null(fitVals)) {
        warning("Could not extract starting values. Breaking out of refit loop.")
        break
      }
      
      mod <- tryCatch(
        update(mod, control = lme4::lmerControl(optCtrl = list(ftol_abs = 1e-12)), start = fitVals),
        error = function(e) {
          warning("Update failed on attempt ", attemptNum, ": ", e$message)
          return(mod) # keep old model if update fails
        }
      )
      
      conv_result <- buildmer::converged(mod)
      convergedCheck <- isTRUE(conv_result)
      reason <- attr(conv_result, "reason")
      
      # Break out if singular fit
      if (!convergedCheck && identical(reason, "Singular fit")) {
        if (verbose) message("Model flagged as singular fit during refit attempt ", attemptNum, " — accepting model.")
        break
      }
      
      attemptNum <- attemptNum + 1
    }
    
    if (!convergedCheck && verbose && !identical(reason, "Singular fit")) {
      warning("Model still did not converge after ", max_attempts, " attempts. Last reason: ", reason)
    }
    
    mod
  }
  
  
  # ---- Load or fit ----
  if (file.exists(model_file_path)) {
    if (verbose) message("Loading existing model '", model_name, "' from: ", model_file_path)
    model_obj <- readRDS(model_file_path)
  } else {
    if (verbose) message("Model file '", model_name, "' not found. Fitting new model...")
    
    model_obj <- fit_model(modelSpec)
    model_obj <- autoRefit(model_obj)  # only runs if non-converged
    
    saveRDS(model_obj, file = model_file_path)
    if (verbose) message("Model '", model_name, "' fitted and saved successfully to: ", model_file_path)
  }
  
  return(model_obj)
}
