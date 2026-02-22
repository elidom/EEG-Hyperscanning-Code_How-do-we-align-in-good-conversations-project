# -------------------------------------------------------------------------
#  AUDIO PREPROCESSING PIPELINE (Step 03)
#  Speaker TSV → Praat TextGrid
#
#  Author: Peter C.H. Lam
#  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
#           How Do We Align in Good Conversation?
#  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
#
#  Converts speaker-annotated TSV files into Praat TextGrid files.
#  Consecutive words are concatenated into speaker turns.
#
#  Notes:
#      - Prior to this step, users should perform manual diarization of TSV files.
#      - Assumes TSV contains columns: speaker, word, startOffset, endOffset
#      - Outputs raw TextGrids prior to manual cleaning
# -------------------------------------------------------------------------

library(dplyr)
library(tidyverse)
library(readr)
library(stringr)

# Note: Create the directory in step 2 first!

# select dyad to be processed
currentDyad = "dyad15"

# --- Helper Function to Write Praat TextGrid ---
# This function takes the processed dataframe and outputs a TextGrid file
# data_concat_df: dataframe with columns speaker, text, start_time, end_time
# output_path: full path where the .TextGrid file should be saved
write_praat_textgrid <- function(data_concat_df, output_path) {
  
  # Ensure data is sorted by start time
  data_concat_df <- data_concat_df %>% arrange(start_time)
  
  # Get unique speakers (
  speakers <- sort(unique(data_concat_df$speaker))
  num_tiers <- length(speakers)
  
  # Determine global xmin and xmax for the TextGrid
  global_xmin <- 0
  global_xmax <- max(data_concat_df$end_time)
  
  # Start building the TextGrid content
  tg_lines <- c()
  
  # Header
  tg_lines <- c(tg_lines,
                'File type = "ooTextFile"',
                'Object class = "TextGrid"',
                "", # Empty line separator
                paste("xmin =", format(global_xmin, nsmall = 10)), 
                paste("xmax =", format(global_xmax, nsmall = 10)),
                "tiers? <exists>",
                paste("size =", num_tiers),
                "item []:"
  )
  
  # Loop through speaker 
  for (tier_index in 1:num_tiers) {
    current_speaker <- speakers[tier_index]
    speaker_data <- data_concat_df %>%
      filter(speaker == current_speaker) %>%
      arrange(start_time) 
    
    # Tier Header
    tg_lines <- c(tg_lines,
                  paste0("    item [", tier_index, "]:"),
                  '        class = "IntervalTier"',
                  paste0('            name = "', current_speaker, '"'), # Use speaker ID as tier name
                  paste("            xmin =", format(global_xmin, nsmall = 10)),
                  paste("            xmax =", format(global_xmax, nsmall = 10))
    )
    
    # Generate Intervals for this Tier
    intervals <- list()
    last_time <- global_xmin
    
    # 1. Add initial silence if the speaker doesn't start at xmin
    if (nrow(speaker_data) == 0 || speaker_data$start_time[1] > global_xmin) {
      intervals[[length(intervals) + 1]] <- list(
        xmin = last_time,
        xmax = if (nrow(speaker_data) > 0) speaker_data$start_time[1] else global_xmax,
        text = ""
      )
      # Update last_time only if there are turns for this speaker
      if (nrow(speaker_data) > 0) {
        last_time <- speaker_data$start_time[1]
      } else {
        last_time <- global_xmax # If no turns, the whole tier is silent
      }
    }
    
    # 2. Loop through speaker's turns
    if (nrow(speaker_data) > 0) {
      for (i in 1:nrow(speaker_data)) {
        turn <- speaker_data[i, ]
        
        # Add silence gap *before* this turn if needed
        if (turn$start_time > last_time) {
          intervals[[length(intervals) + 1]] <- list(
            xmin = last_time,
            xmax = turn$start_time,
            text = ""
          )
        }
        
        # Add the actual speech turn
        # Praat requires double quotes within text to be escaped by doubling them
        safe_text <- gsub('"', '""', turn$text)
        intervals[[length(intervals) + 1]] <- list(
          xmin = turn$start_time,
          xmax = turn$end_time,
          text = safe_text
        )
        last_time <- turn$end_time
      }
    }
    
    
    # 3. Add final silence if the last turn doesn't reach global_xmax
    if (last_time < global_xmax) {
      intervals[[length(intervals) + 1]] <- list(
        xmin = last_time,
        xmax = global_xmax,
        text = ""
      )
    }
    
    # Add Intervals to Tier
    tg_lines <- c(tg_lines, paste0("        intervals: size = ", length(intervals)))
    
    for (k in 1:length(intervals)) {
      interval <- intervals[[k]]
      tg_lines <- c(tg_lines,
                    paste0("        intervals [", k, "]:"),
                    paste0("            xmin = ", format(interval$xmin, nsmall = 10)),
                    paste0("            xmax = ", format(interval$xmax, nsmall = 10)),
                    paste0('            text = "', interval$text, '"')
      )
    }
    
  } 
  
  # Write TextGrid file 
  # Ensureoutput directory exists
  
  output_dir_tg <- dirname(output_path)
  if (!dir.exists(output_dir_tg)) {
    dir.create(output_dir_tg, recursive = TRUE)
    print(paste("Created directory:", output_dir_tg))
  }
  
  # Use tryCatch for safer file writing
  tryCatch({
    writeLines(tg_lines, output_path, useBytes=TRUE) 
  }, error = function(e) {
    warning(paste("Failed to write TextGrid file:", output_path, "\nError:", e$message))
  })
  
}


# Main

# change cd to audio folder relative to the script location
# This assumes your R script is in a 'scripts' folder, and 'Audio' is two levels up
# Adjust the relative path ".." based on your actual folder structure

script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
base_dir <- file.path(script_dir, "..", "..") # Go up two levels
audio_dir <- file.path(base_dir, "Audio")

# Check if the target audio directory exists
if (!dir.exists(audio_dir)) {
  stop(paste("Audio directory not found at:", audio_dir))
}
setwd(audio_dir)
print(paste("Current working directory set to:", getwd()))

# Define input and output paths based on the current working directory
input_folder <- file.path("03_tsv_speakerAdded", currentDyad)
output_folder_textgrid <- file.path("04_textGrids", currentDyad)

# Check if input folder exists
if (!dir.exists(input_folder)) {
  stop(paste("Input TSV directory not found:", file.path(getwd(), input_folder)))
}

# Get all file names from the folder
tsv_files <- list.files(path = input_folder, pattern = "\\.tsv$", full.names = TRUE)

if (length(tsv_files) == 0) {
  warning(paste("No TSV files found in:", file.path(getwd(), input_folder)))
} else {
  print(paste("Found", length(tsv_files), "TSV files to process."))
}

# Function to process a single TSV file
process_tsv <- function(file_path) {
  data <- tryCatch({
    read_tsv(file_path, col_types = cols(
      startOffset = col_double(), 
      endOffset = col_double(),
      word = col_character(),
      speaker = col_character()

    ), show_col_types = FALSE) %>% 
      mutate(speaker = toupper(speaker)) 
  }, error = function(e) {
    warning(paste("Failed to read or parse TSV:", file_path, "\nError:", e$message))
    return(NULL) 
  })
  
  
  if (is.null(data) || nrow(data) == 0) {
    warning(paste("Skipping empty or unreadable file:", file_path))
    return(NULL)
  }
  
  # Make sure essential columns exist
  required_cols <- c("speaker", "word", "startOffset", "endOffset")
  if (!all(required_cols %in% names(data))) {
    warning(paste("Skipping file due to missing columns:", file_path,
                  "- Expected:", paste(required_cols, collapse=", "),
                  "- Found:", paste(names(data), collapse=", ")))
    return(NULL)
  }
  
  # Skip files with empty speaker column
  if (all(is.na(data$speaker)) || all(data$speaker == "")) {
    warning(paste("Skipping file due to empty speaker column:", file_path))
    return(NULL)
  }
  
  # Check if speaker column contains only "A" or "B"
  invalid_speakers <- unique(data$speaker[!data$speaker %in% c("A", "B")])
  if (length(invalid_speakers) > 0) {
    stop(paste("Error in file:", basename(file_path),
               "- Speaker column contains invalid values:", paste(invalid_speakers, collapse = ", ")))
  }
  
  # Convert offsets to numeric seconds
  if(is.numeric(data$startOffset) && max(data$startOffset, na.rm = TRUE) > 1e6) { # Heuristic check for large numbers (like ns)
    data <- data %>%
      mutate(startOffset = startOffset / 1e9,
             endOffset = endOffset / 1e9)
  }
  
  # Flag rows where startOffset is identical to endOffset
  data <- data %>%
    mutate(is_single_point = startOffset == endOffset) %>%
    mutate(endOffset = ifelse(is_single_point, startOffset + 0.5, endOffset)) %>%
    dplyr::select(-is_single_point) 
  
  # Concatenate consecutive words by the same speaker
  # make a new df_cat. for consecutive value rows of speaker value in speaker column,
  # concatenate the text in the text column and add a new column with the speaker value
  data_concat <- data %>%
    # Create a grouping variable that changes whenever the speaker changes
    mutate(group = cumsum(speaker != lag(speaker, default = first(speaker)))) %>%
    # Group by the speaker and the change-group
    group_by(speaker, group) %>%
    # Summarise each group
    summarise(
      text = str_c(word, collapse = " "), 
      start_time = min(startOffset, na.rm = TRUE), # First word's start time
      end_time = max(endOffset, na.rm = TRUE),    # Last word's end time
      .groups = "drop" # Ungroup after summarising
    ) %>%
    # Select and arrange the final columns
    dplyr::select(speaker, text, start_time, end_time) %>%
    arrange(start_time)
  
  data_concat_A = data_concat %>% 
    filter(speaker == "A") %>%
    mutate(
      # Check if the end time of the current row is greater than or equal to the start time of the next row
      concatenate_flag = lag(end_time, default = -1) >= start_time,
      # Create a group ID for concatenation
      group_id = cumsum(!concatenate_flag)
    ) %>%
    group_by(group_id) %>%
    summarise(
      speaker = first(speaker),
      text = paste(text, collapse = " "),
      start_time = first(start_time),
      end_time = last(end_time)
    ) %>%
    ungroup() %>%
    dplyr::select(-group_id)
    
  data_concat_B = data_concat %>% 
    filter(speaker == "B") %>%
    mutate(
      # Check if the end time of the current row is greater than or equal to the start time of the next row
      concatenate_flag = lag(end_time, default = -1) >= start_time,
      # Create a group ID for concatenation
      group_id = cumsum(!concatenate_flag)
    ) %>%
    group_by(group_id) %>%
    summarise(
      speaker = first(speaker),
      text = paste(text, collapse = " "),
      start_time = first(start_time),
      end_time = last(end_time)
    ) %>%
    ungroup() %>%
    dplyr::select(-group_id)
  
  # Combine the concatenated data for both speakers
  data_concat <- bind_rows(data_concat_A, data_concat_B) %>%
    arrange(start_time) 
    
  # Check if the processed data has rows and valid times
  if (nrow(data_concat) > 0 && !any(is.na(data_concat$start_time)) && !any(is.na(data_concat$end_time))) {

    file_name_base <- tools::file_path_sans_ext(basename(file_path)) 
    # Extract topic name from file name (uptill _spkrAdd)
    topic_name <- sub("_spkrAdd.*", "", file_name_base)
    # Add rawTG suffix
    file_name_base <- paste0(topic_name, "_rawTG")
    
    # TextGrid Output
    textgrid_output_dir <- file.path(getwd(), output_folder_textgrid) 

    textgrid_output_path <- file.path(textgrid_output_dir, paste0(file_name_base, ".TextGrid"))

    write_praat_textgrid(data_concat, textgrid_output_path)
    
    return(data_concat) 
    
  } else {
    if (nrow(data_concat) == 0) {
      warning(paste("No data after processing (concatenation):", file_path))
    } else {
      warning(paste("Invalid start/end times after processing:", file_path))
    }
    return(NULL) 
  }
}


#  Process all TSV files ---
# Create the output directories if they don't exist
if (!dir.exists(output_folder_textgrid)) {
  dir.create(output_folder_textgrid, recursive = TRUE)
}

# Process all TSV files
all_results <- tryCatch({
  lapply(tsv_files, process_tsv)
}, error = function(e) {
  message("An error occurred during the processing of files:")
  message(e$message)
  return(list()) 
})
