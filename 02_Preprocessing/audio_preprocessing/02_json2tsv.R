# -------------------------------------------------------------------------
#  AUDIO PREPROCESSING PIPELINE (Step 02)
#  JSON → TSV
#
#  Author: Author: Peter C.H. Lam
#  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review) How Do We Align in Good Conversation?
#  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
#
#  Parses JSON output files and extracts word-level timing information into tidy TSV files.
#
#
#  Notes:
#      - Assumes word-level timestamps are present in JSON
#
# -------------------------------------------------------------------------

library(jsonlite)
library(tidyverse)
library(dplyr)

# select dyad to be processed
currentDyad = "dyad15" # Changed to match output

# change cd to audio folder
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
setwd("../../Audio")

# Get all file names from the folder
json_files <- list.files(path = paste0("01_rawJsonFromGoog/", currentDyad), pattern = "*.json", full.names = TRUE)

# Function to process a single JSON file
process_json <- function(file_path) {
  tryCatch({
    data <- fromJSON(file_path)
    
    # Extract all alternatives and flatten them
    all_alternatives <- data$results$alternatives
    
    if (length(all_alternatives) > 0) {
      all_words_data <- lapply(all_alternatives, function(alt) {
        if (!is.null(alt$words) && length(alt$words) > 0) {
          words_df <- bind_rows(alt$words)
          words_df$transcript <- alt$transcript
          words_df$overall_confidence <- alt$confidence
          return(words_df)
        } else {
          return(NULL) # Return NULL if no words data is present
        }
      })
      
      # Combine all word data frames, removing NULL entries
      combined_words_data <- bind_rows(all_words_data[!sapply(all_words_data, is.null)])
      
      if (nrow(combined_words_data) > 0) {
        # Reorder columns
        combined_words_data <- combined_words_data %>%
          select(transcript, overall_confidence, everything()) %>%
          # clean dataframe
          dplyr::select(word, startOffset, endOffset) %>%
          mutate(speaker = "") %>%
          mutate(startOffset = as.numeric(gsub("s", "", startOffset)),
                 endOffset = as.numeric(gsub("s", "", endOffset))) %>%
          mutate(startOffset = ifelse(row_number() == 1, 0, startOffset))
        return(combined_words_data)
      } else {
        return(NULL) # Return NULL if no words data is available after combining
      }
    } else {
      return(NULL) # Return NULL if no alternatives are present
    }
  }, error = function(e) {
    warning(paste("Error processing JSON file:", basename(file_path), "-", e$message))
    return(NULL) # Return NULL if there was an error parsing the JSON
  })
}

# --- Main Processing Loop (Corrected Confirmation and Error Handling) ---

# Define paths relative to the current working directory (now set to Audio)
input_folder <- file.path("01_rawJsonFromGoog", currentDyad)
output_folder_tsv <- file.path("02_json_to_tsv", currentDyad)
output_folder_speaker <- file.path("03_tsv_speakerAdded", currentDyad) # Define second output folder

# Get all JSON file names from the folder
# Ensure input folder exists relative to current WD
if (!dir.exists(input_folder)) {
  stop(paste("Input folder not found:", file.path(getwd(), input_folder)))
}
json_files <- list.files(path = input_folder, pattern = "\\.json$", full.names = TRUE) # Use \\. for literal dot


if (length(json_files) == 0) {
  warning(paste("No JSON files found in:", file.path(getwd(), input_folder)))
} else {
  print(paste("Found", length(json_files), "JSON files to process from", file.path(getwd(), input_folder)))
}


# Create the output directories if they don't exist
# These paths are now relative to the current working directory (Audio)
if (!dir.exists(output_folder_tsv)) {
  dir.create(output_folder_tsv, recursive = TRUE)
  print(paste("Created directory:", file.path(getwd(), output_folder_tsv)))
}
if (!dir.exists(output_folder_speaker)) {
  dir.create(output_folder_speaker, recursive = TRUE)
  print(paste("Created directory:", file.path(getwd(), output_folder_speaker)))
}


# Process each JSON file and save the results to BOTH locations
processed_count <- 0
skipped_count <- 0
for (file_path in json_files) {
  # Extract the file name without the extension
  file_name_base <- tools::file_path_sans_ext(basename(file_path))
  
  # Extract topic name from file name (original logic)
  # This regex captures characters between the first character and '_transcript_'
  topic_match <- regmatches(file_name_base, regexpr("^(.*?)(?=_transcript_)", file_name_base, perl = TRUE))
  
  if (length(topic_match) == 0) {
    # Fallback if '_transcript_' is not found in the filename
    topic_name <- file_name_base
    warning(paste("Could not extract topic name using '_transcript_' pattern for:", file_name_base, ". Using base name."))
  } else {
    # Assign the matched part (everything before '_transcript_')
    topic_name <- topic_match[1]
  }
  
  
  print(paste("Processing file:", basename(file_path)))
  # Process the JSON file using the error-handled function
  result <- process_json(file_path)
  
  # Write to TSV if there are any valid results
  if (!is.null(result) && nrow(result) > 0) {
    # --- Define Output File Paths ---
    # Path 1: Original location
    output_file1 <- file.path(output_folder_tsv, paste0(currentDyad, "_", topic_name, ".tsv"))
    # Path 2: New location with suffix
    output_file2 <- file.path(output_folder_speaker, paste0(currentDyad, "_", topic_name, "_spkrAdd.tsv"))
    
    # --- Write to First Location with Immediate Confirmation ---
    if (file.exists(output_file1)) {
      cat(paste("File '", basename(output_file1), "' already exists. Overwrite? (y/n): ")) # Use cat for immediate output
      overwrite1 <- tolower(readLines(n = 1))
      if (overwrite1 == "y") {
        tryCatch({
          write_tsv(result, output_file1)
          print(paste(" -> Overwrote TSV 1:", basename(output_file1), "to", dirname(output_file1)))
        }, error = function(e){
          warning(paste(" FAILED to write TSV file 1:", basename(output_file1), "\n   Error:", e$message))
        })
      } else {
        print(paste(" -> Skipped writing TSV 1:", basename(output_file1)))
      }
    } else {
      tryCatch({
        write_tsv(result, output_file1)
        print(paste(" -> Saved TSV 1:", basename(output_file1), "to", dirname(output_file1)))
      }, error = function(e){
        warning(paste(" FAILED to write TSV file 1:", basename(output_file1), "\n   Error:", e$message))
      })
    }
    
    # --- Write to Second Location with Immediate Confirmation ---
    if (file.exists(output_file2)) {
      cat(paste("File '", basename(output_file2), "' already exists. Overwrite? (y/n): ")) # Use cat for immediate output
      overwrite2 <- tolower(readLines(n = 1))
      if (overwrite2 == "y") {
        tryCatch({
          write_tsv(result, output_file2)
          print(paste(" -> Overwrote TSV 2:", basename(output_file2), "to", dirname(output_file2)))
        }, error = function(e){
          warning(paste(" FAILED to write TSV file 2:", basename(output_file2), "\n   Error:", e$message))
        })
      } else {
        print(paste(" -> Skipped writing TSV 2:", basename(output_file2)))
      }
    } else {
      tryCatch({
        write_tsv(result, output_file2)
        print(paste(" -> Saved TSV 2:", basename(output_file2), "to", dirname(output_file2)))
      }, error = function(e){
        warning(paste(" FAILED to write TSV file 2:", basename(output_file2), "\n   Error:", e$message))
      })
    }
    
    processed_count <- processed_count + 1
    
  } else if (!is.null(result) && nrow(result) == 0) {
    print(paste(" -> Skipped (No valid word data extracted):", basename(file_path)))
    skipped_count <- skipped_count + 1
  }
}

# --- Summary ---
print("--------------------")
print("Processing complete.")
print(paste("Processed and attempted save for:", processed_count, "files."))
print(paste("Skipped (no data extracted or processing error):", skipped_count, "files."))
print("--------------------")
